# 45-Minute Demonstration Plan

| Time | Topic | What to show |
|---|---|---|
| 0–3 min | Introduction | Problem, objectives, scope and users |
| 3–8 min | Tech stack | Django/Python, MySQL, HTML/CSS; explain framework, ORM, authentication and admin |
| 8–13 min | Design | ERD normalization, cardinalities, Use Case and DFD |
| 13–19 min | Admin setup | Login as administrator; show groups, departments, programs, terms, subjects, curriculum and fees |
| 19–25 min | Student registration | Create student; show generated Student ID and student list |
| 25–31 min | Enrollment | Submit application; show status and describe prerequisite/schedule/capacity validation target |
| 31–36 min | Billing and cashier | Show assessment items, record payment, show updated balance |
| 36–40 min | Scheduling and grades | Show room/instructor schedule and grade records |
| 40–43 min | Reports | Show term totals, collection total and CSV export in Excel |
| 43–45 min | Summary | Limitations, security, future enhancements and questions |

## Tech-stack justification and references
- Django documentation: built-in authentication, admin, ORM, forms and security features reduce the amount of foundational code a team must write. https://docs.djangoproject.com/en/5.2/
- Python documentation: Python is a general-purpose language with a readable syntax and broad ecosystem. https://docs.python.org/3/
- MySQL documentation: MySQL provides relational tables, constraints, transactions and indexing suitable for structured academic records. https://dev.mysql.com/doc/
- OWASP ASVS: use as a checklist for authentication, access control, validation, session management and secure configuration. https://owasp.org/www-project-application-security-verification-standard/

Avoid unsupported claims such as “most secure” or “fastest”; explain the practical fit and cite official documentation.
