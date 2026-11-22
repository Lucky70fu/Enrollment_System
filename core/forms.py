from django import forms
from .models import Student, Enrollment, EnrollmentSubject, Payment

class StudentForm(forms.ModelForm):
    class Meta:
        model = Student
        fields = ["first_name","middle_name","last_name","birth_date","gender","email","phone","address","program","year_level"]
        widgets = {"birth_date": forms.DateInput(attrs={"type":"date"})}

class EnrollmentForm(forms.ModelForm):
    class Meta:
        model = Enrollment
        fields = ["student","term","enrollment_type"]

class PaymentForm(forms.ModelForm):
    class Meta:
        model = Payment
        fields = ["enrollment","amount","method","reference_no"]
