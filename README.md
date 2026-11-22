# Student Information and Enrollment System (Django + MySQL)

Academic project starter implementation for a computerized enrollment system.

## Included modules
- Student registration with generated unique Student ID (`STU-000001` style)
- Program, department, subject, curriculum, prerequisite, term, section, room, instructor, offering and schedule data models
- Enrollment application with type and status tracking
- Schedule conflict validation at model level (room and instructor)
- Assessment item and payment ledger models; balance summary view
- Grade records
- Role/group access helper for Administrator, Registrar, Cashier, Instructor, Student
- Website-based CRUD screens for student records and academic master records, with Django Admin retained for advanced administration
- Enrollment summary, collections total and CSV export for Excel
- Audit log model for important actions

## Requirements
- Python 3.11+
- Django 5.2
- MySQL 8.0+ (or SQLite fallback for local evaluation)
- VS Code recommended

## Setup (Windows / XAMPP MySQL)
1. Extract the ZIP and open the `enrollment_system` folder in VS Code.
2. Create and activate a virtual environment:
   ```powershell
   py -m venv .venv
   .venv\\Scripts\\activate
   ```
3. Install packages:
   ```powershell
   pip install -r requirements.txt
   ```
4. Create a MySQL database:
   ```sql
   CREATE DATABASE enrollment_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
5. Copy `.env.example` to `.env`, then enter your database credentials and a secure `DJANGO_SECRET_KEY`.
   If `DB_NAME` is blank, Django uses SQLite for a quick demonstration.
6. Create tables and administrator:
   ```powershell
   python manage.py makemigrations core
   python manage.py migrate
   python manage.py createsuperuser
   python manage.py runserver
   ```
7. Open `http://127.0.0.1:8000/` and sign in. Use **Students** for student registration, search, semester status filtering, profile viewing, editing, and deletion (where no linked records prevent deletion). Use **Academic Setup** for website-based create/edit/delete screens for colleges, programs, terms, subjects, curriculum, instructors, rooms, sections, offerings, schedules, fees, enrollment records/status, enrolled subjects, assessment items, and grades. `/admin/` remains available for advanced user/group setup.

## Student enrollment status
The student list shows **Enrolled** only when the student has an `Enrollment` record with status `ENROLLED` for the selected semester. Otherwise, for that semester, the student is shown as **Unenrolled**. Pending, approved, and rejected records do not count as officially enrolled. Select a semester in the student list to view the correct term-specific status. A student can therefore be enrolled in one semester and unenrolled in another.

## Student portal login
When a Registrar or Administrator registers a student, the system creates a linked portal login automatically:
- **Username:** the generated Student ID (for example, `STU-000123`)
- **Initial password:** the student's last name exactly as entered (passwords are case-sensitive)
- The account is assigned to the `Student` role group.
- Students can sign in at `/accounts/login/` and change their password using **Change Password** in the top navigation.
- For a student record created before this feature, open the student's profile and use **Create Student Login Account** if no account is linked.

**Security note:** A last name is a weak temporary password and may be guessable. Use this only for a classroom demonstration or controlled pilot. In real deployment, require a password change at first login or issue a random one-time password through a verified channel, enable HTTPS, and apply rate limiting. Never distribute student credentials publicly.

## Configure role groups
In Django Admin, create Groups named exactly:
- Administrator
- Registrar
- Cashier
- Instructor
- Student

Assign users to the appropriate group. Create Instructor records linked to instructor users. For a student portal account, create a Student record linked to the student's User account.

## Suggested initial data sequence
1. College (Department)
2. Academic Program
3. School Term (set `is_open=True`)
4. Subjects
5. Curriculum Subject rows (assign prerequisites)
6. Rooms, Instructor profiles, Sections
7. Subject Offerings and Class Schedules
8. Fees
9. Student records and enrollment applications

## Important implementation notes / items to complete before production
- The project is a functional academic starter, not a certified production SIS. Run and test it in your environment and tailor workflows to your school's policies.
- Subject selection in an enrollment cart, automated prerequisite completion checking, schedule-conflict checking across a student's selected subjects, seat-capacity enforcement, approval workflow actions, and automatic assessment generation are not yet wired into the browser workflow. The underlying normalized entities are present; these workflow screens/services are extension tasks.
- Assessment items must be created for an enrollment through Django Admin or a future assessment service. The balance view calculates assessed total less recorded payments.
- Online payment provider checkout and verified webhooks are not activated. Cashier payment recording is available; GCash/Maya/card acceptance requires merchant credentials, provider SDK/API implementation, signature verification and sandbox testing. Do not collect card credentials in this application.
- Schedule `clean()` validates room/instructor overlaps when model validation is invoked. Django Admin/forms call model validation; direct scripts should call `full_clean()` before saving.
- Automated tests and a full runtime/browser test were not run on this updated package in the build environment. Add automated tests, rate limiting, email verification, secure backups, privacy notices, audit review, HTTPS, least-privilege database accounts and production secrets before deployment.
- Sensitive personal data should only be collected when necessary and must have restricted access and an approved retention policy.

## Useful commands
```powershell
python manage.py check
python manage.py makemigrations
python manage.py migrate
python manage.py test
```

## Project structure
- `config/` settings and URL routing
- `core/` normalized models, forms, permissions, views and admin registration
- `templates/` HTML templates
- `static/` CSS
- `docs/` diagrams, requirements mapping and demonstration script
