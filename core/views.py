from decimal import Decimal

from django import forms
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.db import IntegrityError
from django.db import transaction
from django.db.models import Sum, Count, Q
from django.http import HttpResponseForbidden, HttpResponse
from django.shortcuts import render, redirect, get_object_or_404
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_POST

from .models import (
    Department, Program, Student, SchoolTerm, Subject, CurriculumSubject,
    Instructor, Room, Section, SubjectOffering, ClassSchedule, Enrollment,
    EnrollmentSubject, Fee, AssessmentItem, Payment, Grade, AuditLog,
)
from .forms import StudentForm, EnrollmentForm, PaymentForm
from .permissions import can_access
from django.core.paginator import Paginator

def guard(request, module):
    if not can_access(request.user, module):
        return HttpResponseForbidden("You do not have permission to access this module.")
    return None


def create_student_portal_account(student):
    """Create a student login: username=Student ID, initial password=last name."""
    if student.user_id:
        return False, "This student is already linked to a login account."
    User = get_user_model()
    if User.objects.filter(username=student.student_id).exists():
        return False, f"Username {student.student_id} already exists. Resolve the existing account before linking it."
    with transaction.atomic():
        user = User.objects.create_user(
            username=student.student_id,
            password=student.last_name,
            email=student.email or "",
            first_name=student.first_name,
            last_name=student.last_name,
        )
        group, _ = Group.objects.get_or_create(name="Student")
        user.groups.add(group)
        student.user = user
        student.save(update_fields=["user"])
    return True, f"Student portal account created. Username: {student.student_id}; initial password: the student's last name."


def can_manage(request):
    return request.user.is_superuser or request.user.groups.filter(
        name__in=["Administrator", "Registrar"]
    ).exists()


@login_required
def dashboard(request):
    return render(request, "core/dashboard.html", {
        "students": Student.objects.count(), "enrollments": Enrollment.objects.count(),
        "pending": Enrollment.objects.filter(status="PENDING").count(),
        "collections": Payment.objects.aggregate(v=Sum("amount"))["v"] or Decimal("0"),
    })


@login_required
def student_list(request):
    denied = guard(request, "students")
    if denied:
        return denied
    terms = SchoolTerm.objects.order_by("-school_year", "-id")
    term_id = request.GET.get("term")
    selected_term = terms.filter(pk=term_id).first() if term_id else terms.filter(is_open=True).first()
    status = request.GET.get("status", "")
    students = Student.objects.select_related("program", "program__department").all()
    if request.user.groups.filter(name="Student").exists():
        students = students.filter(user=request.user)
    search = request.GET.get("q", "").strip()
    if search:
        students = students.filter(
            Q(student_id__icontains=search) | Q(first_name__icontains=search)
            | Q(middle_name__icontains=search) | Q(last_name__icontains=search)
            | Q(email__icontains=search)
        )
    if request.GET.get("program"):
        students = students.filter(program_id=request.GET["program"])
    if request.GET.get("year"):
        students = students.filter(year_level=request.GET["year"])
    if selected_term:
        enrolled_ids = Enrollment.objects.filter(term=selected_term, status="ENROLLED").values_list("student_id", flat=True)
        if status == "ENROLLED":
            students = students.filter(pk__in=enrolled_ids)
        elif status == "UNENROLLED":
            students = students.exclude(pk__in=enrolled_ids)
        rows = []
    for student in students.order_by("student_id"):
        enrollment = Enrollment.objects.filter(
            student=student,
            term=selected_term
        ).first() if selected_term else None

        rows.append({
            "student": student,
            "status": (
                "ENROLLED"
                if enrollment and enrollment.status == "ENROLLED"
                else "UNENROLLED"
            ) if selected_term else "",
            "enrollment": enrollment
        })

    paginator = Paginator(rows, 10)
    page_number = request.GET.get("page")
    page_obj = paginator.get_page(page_number)

    return render(request, "core/student_list.html", {
        "rows": page_obj,
        "page_obj": page_obj,
        "terms": terms,
        "selected_term": selected_term,
        "programs": Program.objects.order_by("code"),
        "search": search,
        "selected_status": status,
        "selected_program": request.GET.get("program", ""),
        "selected_year": request.GET.get("year", ""),
        "can_manage": can_manage(request),
    })


@login_required
def student_create(request):
    denied = guard(request, "students")
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can register students.")
    form = StudentForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        student = form.save()
        AuditLog.objects.create(user=request.user, action="Created student", object_type="Student", object_id=student.pk)
        try:
            created, account_message = create_student_portal_account(student)
            if created:
                messages.success(request, account_message)
            else:
                messages.warning(request, account_message)
        except IntegrityError:
            messages.warning(request, "Student was registered, but the portal account could not be created because the Student ID username is already in use.")
        messages.success(request, f"Student registered. ID: {student.student_id}")
        return redirect("student_detail", pk=student.pk)
    return render(request, "core/form.html", {"form": form, "title": "Student Registration", "cancel_url": reverse("student_list")})


@login_required
def student_detail(request, pk):
    denied = guard(request, "students")
    if denied:
        return denied
    student = get_object_or_404(Student.objects.select_related("program__department"), pk=pk)
    if request.user.groups.filter(name="Student").exists() and student.user_id != request.user.id:
        return HttpResponseForbidden("You can only view your own student record.")
    enrollments = student.enrollments.select_related("term").prefetch_related("payments", "assessment_items").order_by("-submitted_at")
    return render(request, "core/student_detail.html", {"student": student, "enrollments": enrollments, "can_manage": can_manage(request)})


@login_required
@require_POST
def student_create_portal_account(request, pk):
    denied = guard(request, "students")
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can create student portal accounts.")
    student = get_object_or_404(Student, pk=pk)
    try:
        created, account_message = create_student_portal_account(student)
        if created:
            AuditLog.objects.create(user=request.user, action="Created student portal account", object_type="Student", object_id=student.pk)
            messages.success(request, account_message)
        else:
            messages.warning(request, account_message)
    except IntegrityError:
        messages.error(request, "The account could not be created because this Student ID is already used as a username.")
    return redirect("student_detail", pk=student.pk)


@login_required
def student_edit(request, pk):
    denied = guard(request, "students")
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can edit student records.")
    student = get_object_or_404(Student, pk=pk)
    form = StudentForm(request.POST or None, instance=student)
    if request.method == "POST" and form.is_valid():
        form.save()
        AuditLog.objects.create(user=request.user, action="Updated student", object_type="Student", object_id=student.pk)
        messages.success(request, "Student record updated.")
        return redirect("student_detail", pk=student.pk)
    return render(request, "core/form.html", {"form": form, "title": "Edit Student", "cancel_url": reverse("student_detail", args=[student.pk])})


@login_required
@require_POST
def student_delete(request, pk):
    denied = guard(request, "students")
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can delete student records.")
    student = get_object_or_404(Student, pk=pk)
    try:
        with transaction.atomic():
            AuditLog.objects.create(user=request.user, action="Deleted student", object_type="Student", object_id=student.pk)
            student.delete()
        messages.success(request, "Student record deleted.")
    except Exception:
        messages.error(request, "This student cannot be deleted because related enrollment or financial records exist. Keep the record and update its status instead.")
    return redirect("student_list")


@login_required
def academic_overview(request):
    denied = guard(request, "academics")
    if denied:
        return denied
    return render(request, "core/academic_overview.html", {
        "programs": Program.objects.select_related("department"), "subjects": Subject.objects.all(),
        "terms": SchoolTerm.objects.all(), "colleges": Department.objects.all(),
        "curricula": CurriculumSubject.objects.select_related("program", "subject"),
        "instructors": Instructor.objects.select_related("user", "department"),
        "rooms": Room.objects.all(), "sections": Section.objects.select_related("program", "term"),
        "offerings": SubjectOffering.objects.select_related("curriculum_subject__subject", "section"),
        "fees": Fee.objects.all(),
    })


# Website-based maintenance pages. These keep users out of Django Admin for routine CRUD.
MANAGED_MODELS = {
    "colleges": (Department, "academics", "Colleges"),
    "programs": (Program, "academics", "Academic Programs"),
    "terms": (SchoolTerm, "academics", "School Terms"),
    "subjects": (Subject, "academics", "Subjects"),
    "curriculum": (CurriculumSubject, "academics", "Curriculum Subjects"),
    "instructors": (Instructor, "academics", "Instructors"),
    "rooms": (Room, "academics", "Rooms"),
    "sections": (Section, "academics", "Sections"),
    "offerings": (SubjectOffering, "academics", "Subject Offerings"),
    "schedules": (ClassSchedule, "schedules", "Class Schedules"),
    "fees": (Fee, "billing", "Fees"),
    "enrollment-records": (Enrollment, "enrollment", "Enrollment Records"),
    "grades-records": (Grade, "grades", "Grade Records"),
    "assessment-items": (AssessmentItem, "billing", "Assessment Items"),
    "enrollment-subjects": (EnrollmentSubject, "enrollment", "Enrolled Subjects"),
}


def managed_model(slug):
    if slug not in MANAGED_MODELS:
        from django.http import Http404
        raise Http404("Unknown management section")
    return MANAGED_MODELS[slug]


@login_required
def managed_list(request, slug):
    model, module, title = managed_model(slug)
    denied = guard(request, module)
    if denied:
        return denied
    qs = model.objects.all().order_by("pk")
    if request.user.groups.filter(name="Student").exists():
        if model is Enrollment:
            qs = qs.filter(student__user=request.user)
        elif model is EnrollmentSubject:
            qs = qs.filter(enrollment__student__user=request.user)
        elif model is AssessmentItem:
            qs = qs.filter(enrollment__student__user=request.user)
        elif model is Grade:
            qs = qs.filter(enrollment_subject__enrollment__student__user=request.user)
    return render(request, "core/managed_list.html", {"slug": slug, "title": title, "objects": qs, "can_manage": can_manage(request)})


@login_required
def managed_form(request, slug, pk=None):
    model, module, title = managed_model(slug)
    denied = guard(request, module)
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can maintain these records.")
    instance = get_object_or_404(model, pk=pk) if pk is not None else None
    excluded = []
    if model is Enrollment:
        excluded = ["submitted_at", "approved_by"]
    if model is Payment:
        excluded = ["recorded_by", "paid_at"]
    if model is AuditLog:
        excluded = ["user", "created_at"]
    ModelForm = forms.modelform_factory(model, fields="__all__", exclude=excluded, widgets={
        "starts_on": forms.DateInput(attrs={"type": "date"}),
        "ends_on": forms.DateInput(attrs={"type": "date"}),
        "start_time": forms.TimeInput(attrs={"type": "time"}),
        "end_time": forms.TimeInput(attrs={"type": "time"}),
    })
    form = ModelForm(request.POST or None, instance=instance)
    if request.method == "POST" and form.is_valid():
        obj = form.save()
        AuditLog.objects.create(user=request.user, action=("Updated " if instance else "Created ") + title, object_type=model.__name__, object_id=obj.pk)
        messages.success(request, f"{title[:-1] if title.endswith('s') else title} saved.")
        return redirect("managed_list", slug=slug)
    return render(request, "core/form.html", {"form": form, "title": ("Edit " if instance else "Add ") + title, "cancel_url": reverse("managed_list", args=[slug])})


@login_required
@require_POST
def managed_delete(request, slug, pk):
    model, module, title = managed_model(slug)
    denied = guard(request, module)
    if denied:
        return denied
    if not can_manage(request):
        return HttpResponseForbidden("Only the Administrator or Registrar can delete these records.")
    obj = get_object_or_404(model, pk=pk)
    try:
        with transaction.atomic():
            AuditLog.objects.create(user=request.user, action="Deleted " + title, object_type=model.__name__, object_id=obj.pk)
            obj.delete()
        messages.success(request, "Record deleted.")
    except Exception:
        messages.error(request, "This record is being used by other records and cannot be deleted.")
    return redirect("managed_list", slug=slug)


@login_required
def enrollment_list(request):
    denied = guard(request, "enrollment")
    if denied:
        return denied
    qs = Enrollment.objects.select_related("student", "term").order_by("-submitted_at")
    if request.user.groups.filter(name="Student").exists():
        qs = qs.filter(student__user=request.user)
    return render(request, "core/enrollment_list.html", {"enrollments": qs, "can_manage": can_manage(request)})


@login_required
def enrollment_create(request):
    denied = guard(request, "enrollment")
    if denied:
        return denied
    form = EnrollmentForm(request.POST or None)
    if request.user.groups.filter(name="Student").exists():
        form.fields["student"].queryset = Student.objects.filter(user=request.user)
    if request.method == "POST" and form.is_valid():
        enrollment = form.save(commit=False)
        if request.user.groups.filter(name="Student").exists():
            enrollment.student = Student.objects.get(user=request.user)
        enrollment.save()
        AuditLog.objects.create(user=request.user, action="Submitted enrollment", object_type="Enrollment", object_id=enrollment.pk)
        messages.success(request, "Enrollment application submitted. Registrar review is required.")
        return redirect("enrollment_list")
    return render(request, "core/form.html", {"form": form, "title": "New Enrollment Application", "cancel_url": reverse("enrollment_list")})


@login_required
def billing_list(request):
    denied = guard(request, "billing")
    if denied:
        return denied
    enrollments = Enrollment.objects.select_related("student", "term").annotate(paid=Sum("payments__amount"))
    if request.user.groups.filter(name="Student").exists():
        enrollments = enrollments.filter(student__user=request.user)
    rows = []
    for e in enrollments:
        assessed = e.assessment_items.aggregate(v=Sum("amount"))["v"] or Decimal("0")
        paid = e.paid or Decimal("0")
        rows.append({"enrollment": e, "assessed": assessed, "paid": paid, "balance": assessed - paid})
    return render(request, "core/billing_list.html", {"rows": rows})


@login_required
def record_payment(request):
    denied = guard(request, "billing")
    if denied:
        return denied
    form = PaymentForm(request.POST or None)
    if request.user.groups.filter(name="Student").exists():
        form.fields["enrollment"].queryset = Enrollment.objects.filter(student__user=request.user)
    if request.method == "POST" and form.is_valid():
        payment = form.save(commit=False)
        payment.recorded_by = request.user
        payment.save()
        AuditLog.objects.create(user=request.user, action="Recorded payment", object_type="Payment", object_id=payment.pk)
        messages.success(request, "Payment recorded.")
        return redirect("billing_list")
    return render(request, "core/form.html", {"form": form, "title": "Record Payment", "cancel_url": reverse("billing_list")})


@login_required
def schedule_list(request):
    denied = guard(request, "schedules")
    if denied:
        return denied
    schedules = ClassSchedule.objects.select_related("room", "offering__curriculum_subject__subject", "offering__instructor", "offering__section")
    return render(request, "core/schedule_list.html", {"schedules": schedules})


@login_required
def grade_list(request):
    denied = guard(request, "grades")
    if denied:
        return denied
    grades = Grade.objects.select_related("enrollment_subject__enrollment__student", "enrollment_subject__offering__curriculum_subject__subject")
    if request.user.groups.filter(name="Student").exists():
        grades = grades.filter(enrollment_subject__enrollment__student__user=request.user)
    return render(request, "core/grade_list.html", {"grades": grades})


@login_required
def reports(request):
    denied = guard(request, "reports")
    if denied:
        return denied
    if request.GET.get("format") == "csv":
        import csv
        response = HttpResponse(content_type="text/csv")
        response["Content-Disposition"] = 'attachment; filename="enrollment_report.csv"'
        writer = csv.writer(response)
        writer.writerow(["Student ID", "Student", "Program", "Year", "Term", "Status"])
        for e in Enrollment.objects.select_related("student", "student__program", "term"):
            writer.writerow([e.student.student_id, str(e.student), e.student.program.code, e.student.year_level, str(e.term), e.status])
        return response
    summary = Enrollment.objects.values("term__name", "term__school_year").annotate(total=Count("id"))
    collections = Payment.objects.aggregate(total=Sum("amount"))["total"] or Decimal("0")
    return render(request, "core/reports.html", {"summary": summary, "collections": collections})
