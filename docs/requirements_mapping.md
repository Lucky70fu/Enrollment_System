# Functional Requirements and Implementation Mapping

| Requirement | Current implementation | Demonstration / extension |
|---|---|---|
| Student registration | Student model, StudentForm, generated unique Student ID, list and create views | Register, retrieve and update records; add edit/detail view if required |
| Subject/curriculum management | Department, Program, Subject, CurriculumSubject and prerequisite relation; Django Admin | Create a program, subjects, year/semester mapping and prerequisites |
| Enrollment processing | Enrollment and EnrollmentSubject models; application form and status | Current starter records applications. Complete subject cart and prerequisite/schedule checks before operational use |
| Fee assessment/payment | Fee, AssessmentItem, Payment; billing balance calculation; cashier payment form | Configure assessment items; add assessment service to compute units × per-unit fees + fixed fees |
| Class scheduling | SubjectOffering, Room, ClassSchedule; overlap validation for room/instructor | Configure schedules and validate via admin; add student-specific clash checks in enrollment cart |
| Reports | Enrollment counts by term, collections total, CSV export | CSV opens in Excel; add PDF report endpoint if required |
| Roles | Django authentication, Groups and `can_access` role helper | Create five named groups and assign users; tighten object-level restrictions for deployment |

## Suggested assessment formula
Tuition = total enrolled units × tuition rate per unit.
Total assessment = tuition + active fixed fees + other applicable charges − approved scholarship discount.
Balance = total assessment − sum of posted payments.
Scholarship discounts should be represented as assessment adjustments, not uploaded documents.

## Input and output forms
- Student registration: StudentForm
- Enrollment application: EnrollmentForm
- Cashier payment: PaymentForm
- Outputs: student register, enrollment application list, billing balance table, schedule list, grades table, enrollment and collection summary.
