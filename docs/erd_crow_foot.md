# Normalized ERD — Crow's Foot Relationship Specification

Use this specification to draw the ERD in diagrams.net / draw.io. `||` means exactly one, `o|` zero or one, `|{` one or many, and `o{` zero or many.

```text
DEPARTMENT ||——o{ PROGRAM
PROGRAM ||——o{ STUDENT
PROGRAM ||——o{ CURRICULUM_SUBJECT
SUBJECT ||——o{ CURRICULUM_SUBJECT
CURRICULUM_SUBJECT }o——o{ SUBJECT : prerequisites (self-referencing M:N)
SCHOOL_TERM ||——o{ SECTION
PROGRAM ||——o{ SECTION
SECTION ||——o{ SUBJECT_OFFERING
CURRICULUM_SUBJECT ||——o{ SUBJECT_OFFERING
INSTRUCTOR ||——o{ SUBJECT_OFFERING
SUBJECT_OFFERING ||——o{ CLASS_SCHEDULE
ROOM ||——o{ CLASS_SCHEDULE
STUDENT ||——o{ ENROLLMENT
SCHOOL_TERM ||——o{ ENROLLMENT
ENROLLMENT ||——o{ ENROLLMENT_SUBJECT
SUBJECT_OFFERING ||——o{ ENROLLMENT_SUBJECT
ENROLLMENT ||——o{ ASSESSMENT_ITEM
FEE ||——o{ ASSESSMENT_ITEM
ENROLLMENT ||——o{ PAYMENT
ENROLLMENT_SUBJECT ||——o| GRADE
USER ||——o| STUDENT
USER ||——o| INSTRUCTOR
USER ||——o{ PAYMENT : recorded_by
USER ||——o{ AUDIT_LOG
```

## Normalization notes
- Department and Program are separate reference entities.
- Subject catalog is independent of program placement; CurriculumSubject resolves program/year/semester mapping.
- Prerequisites are a self-referencing many-to-many relationship on curriculum placements/subjects.
- Student and User are separate: a student profile can exist before portal credentials are created.
- EnrollmentSubject resolves the many-to-many relationship between Enrollment and SubjectOffering.
- AssessmentItem stores the assessed charge snapshot for a specific enrollment.
- Payment is a separate transaction ledger. Balance is derived from assessment minus payments, not stored redundantly.
- ClassSchedule owns room/time/day assignment, avoiding room duplication on the offering.
- Grade is linked to the student's enrollment in a particular offering.
- AuditLog records accountability events.

For final submission, recreate this specification as a visual ERD with crow's-foot connectors and show PK/FK attributes in every entity.
