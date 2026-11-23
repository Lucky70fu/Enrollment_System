-- =====================================================================
--  PIESdb : PalSU Student Information & Enrollment System
--  Generated from core/models.py (Django 5.2) and the project requirements
--  Requires MySQL 8.0.16+ (CHECK constraints are enforced) / InnoDB
--
--  Scope: enrollment-system data only. User accounts, passwords, groups
--  and permissions are handled by Django (auth_user, auth_group, ...).
--  Columns that refer to a user (user_id, approved_by_id, recorded_by_id)
--  are plain INT columns here; the optional last section adds their
--  foreign keys once Django has created auth_user.
--
--  Sections
--    1. Database
--    2. Core tables (1:1 with models.py)
--    3. Business-rule triggers (requirements 3 and 5)
--    4. Stored procedures (student ID generation, fee assessment)
--    5. Views (assessment form, balances, schedules, reports)
--    6. Optional foreign keys to Django's auth_user
-- =====================================================================

DROP DATABASE IF EXISTS PIESdb;
CREATE DATABASE PIESdb CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE PIESdb;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 2. CORE TABLES
-- ---------------------------------------------------------------------

-- College
CREATE TABLE department (
    id   BIGINT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(15)  NOT NULL,
    name VARCHAR(120) NOT NULL,
    CONSTRAINT uq_department_code UNIQUE (code)
) ENGINE=InnoDB;

-- Academic Program
CREATE TABLE program (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    code              VARCHAR(20)  NOT NULL,
    name              VARCHAR(150) NOT NULL,
    years_to_complete SMALLINT UNSIGNED NOT NULL DEFAULT 4,
    department_id     BIGINT NOT NULL,
    CONSTRAINT uq_program_code UNIQUE (code),
    CONSTRAINT fk_program_department FOREIGN KEY (department_id)
        REFERENCES department (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Student (Req. 1). student_id is generated as STU-000001 by sp_register_student
CREATE TABLE student (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NULL,
    student_id  VARCHAR(20)  NOT NULL,
    first_name  VARCHAR(80)  NOT NULL,
    middle_name VARCHAR(80)  NOT NULL DEFAULT '',
    last_name   VARCHAR(80)  NOT NULL,
    birth_date  DATE         NULL,
    gender      CHAR(1)      NOT NULL DEFAULT '',
    email       VARCHAR(254) NOT NULL DEFAULT '',
    phone       VARCHAR(30)  NOT NULL DEFAULT '',
    address     TEXT         NULL,
    program_id  BIGINT       NOT NULL,
    year_level  SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uq_student_user       UNIQUE (user_id),
    CONSTRAINT uq_student_student_id UNIQUE (student_id),
    CONSTRAINT ck_student_gender CHECK (gender IN ('', 'F', 'M', 'X')),
    CONSTRAINT fk_student_program FOREIGN KEY (program_id) REFERENCES program (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Semester / school year
CREATE TABLE schoolterm (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(30) NOT NULL,          -- e.g. 1st Semester
    school_year VARCHAR(20) NOT NULL,          -- e.g. 2026-2027
    starts_on   DATE NULL,
    ends_on     DATE NULL,
    is_open     TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT unique_school_term UNIQUE (name, school_year)
) ENGINE=InnoDB;

-- Subject catalogue (Req. 2)
CREATE TABLE subject (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(20)  NOT NULL,
    title       VARCHAR(160) NOT NULL,
    units       DECIMAL(4,1) NOT NULL,
    description TEXT NULL,
    CONSTRAINT uq_subject_code UNIQUE (code),
    CONSTRAINT ck_subject_units CHECK (units >= 0.5)
) ENGINE=InnoDB;

-- Subject placed in a program / year level / semester (Req. 2)
CREATE TABLE curriculumsubject (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    program_id BIGINT NOT NULL,
    subject_id BIGINT NOT NULL,
    year_level SMALLINT UNSIGNED NOT NULL,
    semester   VARCHAR(20) NOT NULL,
    CONSTRAINT unique_curriculum_subject UNIQUE (program_id, subject_id, year_level, semester),
    CONSTRAINT fk_curr_program FOREIGN KEY (program_id) REFERENCES program (id) ON DELETE CASCADE,
    CONSTRAINT fk_curr_subject FOREIGN KEY (subject_id) REFERENCES subject (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Prerequisite rules (many-to-many: curriculum placement requires Subject)
CREATE TABLE curriculumsubject_prerequisites (
    id                   BIGINT AUTO_INCREMENT PRIMARY KEY,
    curriculumsubject_id BIGINT NOT NULL,
    subject_id           BIGINT NOT NULL,
    CONSTRAINT uq_curr_prereq UNIQUE (curriculumsubject_id, subject_id),
    CONSTRAINT fk_prereq_curr    FOREIGN KEY (curriculumsubject_id) REFERENCES curriculumsubject (id) ON DELETE CASCADE,
    CONSTRAINT fk_prereq_subject FOREIGN KEY (subject_id)           REFERENCES subject (id)           ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE instructor (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT         NOT NULL,
    employee_no   VARCHAR(30) NOT NULL,
    department_id BIGINT      NOT NULL,
    CONSTRAINT uq_instructor_user        UNIQUE (user_id),
    CONSTRAINT uq_instructor_employee_no UNIQUE (employee_no),
    CONSTRAINT fk_instructor_department FOREIGN KEY (department_id) REFERENCES department (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE room (
    id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    code     VARCHAR(30) NOT NULL,
    capacity INT UNSIGNED NOT NULL DEFAULT 40,
    CONSTRAINT uq_room_code UNIQUE (code)
) ENGINE=InnoDB;

CREATE TABLE section (
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    code       VARCHAR(30) NOT NULL,
    term_id    BIGINT      NOT NULL,
    program_id BIGINT      NOT NULL,
    year_level SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT unique_section_term UNIQUE (code, term_id),
    CONSTRAINT fk_section_term    FOREIGN KEY (term_id)    REFERENCES schoolterm (id) ON DELETE RESTRICT,
    CONSTRAINT fk_section_program FOREIGN KEY (program_id) REFERENCES program (id)    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- A subject opened for a section, taught by an instructor
CREATE TABLE subjectoffering (
    id                    BIGINT AUTO_INCREMENT PRIMARY KEY,
    curriculum_subject_id BIGINT NOT NULL,
    section_id            BIGINT NOT NULL,
    instructor_id         BIGINT NOT NULL,
    capacity              INT UNSIGNED NOT NULL DEFAULT 40,
    CONSTRAINT fk_offering_curriculum FOREIGN KEY (curriculum_subject_id) REFERENCES curriculumsubject (id) ON DELETE RESTRICT,
    CONSTRAINT fk_offering_section    FOREIGN KEY (section_id)            REFERENCES section (id)           ON DELETE RESTRICT,
    CONSTRAINT fk_offering_instructor FOREIGN KEY (instructor_id)         REFERENCES instructor (id)        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Day / time / room (Req. 5). day: 0=Monday ... 6=Sunday
CREATE TABLE classschedule (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    offering_id BIGINT  NOT NULL,
    day         CHAR(1) NOT NULL,
    start_time  TIME    NOT NULL,
    end_time    TIME    NOT NULL,
    room_id     BIGINT  NOT NULL,
    CONSTRAINT ck_schedule_day  CHECK (day IN ('0','1','2','3','4','5','6')),
    CONSTRAINT ck_schedule_time CHECK (start_time < end_time),
    CONSTRAINT fk_schedule_offering FOREIGN KEY (offering_id) REFERENCES subjectoffering (id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_room     FOREIGN KEY (room_id)     REFERENCES room (id)            ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE INDEX idx_schedule_day_time ON classschedule (day, start_time, end_time);

-- Enrollment application (Req. 3)
CREATE TABLE enrollment (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id      BIGINT      NOT NULL,
    term_id         BIGINT      NOT NULL,
    enrollment_type VARCHAR(15) NOT NULL DEFAULT 'REGULAR',
    status          VARCHAR(10) NOT NULL DEFAULT 'PENDING',
    submitted_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    approved_by_id  INT NULL,
    CONSTRAINT one_enrollment_per_student_term UNIQUE (student_id, term_id),
    CONSTRAINT ck_enrollment_type CHECK (enrollment_type IN
        ('FRESHMAN','REGULAR','IRREGULAR','LATE','TRANSFEREE','SHIFTY','RETURNING')),
    CONSTRAINT ck_enrollment_status CHECK (status IN ('PENDING','APPROVED','ENROLLED','REJECTED')),
    CONSTRAINT fk_enrollment_student  FOREIGN KEY (student_id)     REFERENCES student (id)    ON DELETE RESTRICT,
    CONSTRAINT fk_enrollment_term     FOREIGN KEY (term_id)        REFERENCES schoolterm (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Subjects (with section) the student enrolled in
CREATE TABLE enrollmentsubject (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id BIGINT NOT NULL,
    offering_id   BIGINT NOT NULL,
    CONSTRAINT unique_enrollment_offering UNIQUE (enrollment_id, offering_id),
    CONSTRAINT fk_es_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollment (id)     ON DELETE CASCADE,
    CONSTRAINT fk_es_offering   FOREIGN KEY (offering_id)   REFERENCES subjectoffering (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Fee assessment & payment (Req. 4)
CREATE TABLE fee (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100)  NOT NULL,
    amount      DECIMAL(10,2) NOT NULL,
    is_per_unit TINYINT(1)    NOT NULL DEFAULT 0,
    active      TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT ck_fee_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE assessmentitem (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id BIGINT        NOT NULL,
    fee_id        BIGINT        NOT NULL,
    description   VARCHAR(150)  NOT NULL,
    amount        DECIMAL(10,2) NOT NULL,      -- snapshot of the charge (negative = adjustment/discount)
    CONSTRAINT fk_ai_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollment (id) ON DELETE CASCADE,
    CONSTRAINT fk_ai_fee        FOREIGN KEY (fee_id)        REFERENCES fee (id)        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE payment (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id  BIGINT        NOT NULL,
    amount         DECIMAL(10,2) NOT NULL,
    method         VARCHAR(10)   NOT NULL,
    reference_no   VARCHAR(100)  NOT NULL DEFAULT '',
    recorded_by_id INT           NOT NULL,
    paid_at        DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT ck_payment_amount CHECK (amount >= 0.01),
    CONSTRAINT ck_payment_method CHECK (method IN ('CASH','GCASH','MAYA','BANK','OTHER')),
    CONSTRAINT fk_payment_enrollment FOREIGN KEY (enrollment_id)  REFERENCES enrollment (id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Grades
CREATE TABLE grade (
    id                    BIGINT AUTO_INCREMENT PRIMARY KEY,
    enrollment_subject_id BIGINT NOT NULL,
    prelim                DECIMAL(4,2) NULL,
    midterm               DECIMAL(4,2) NULL,
    final                 DECIMAL(4,2) NULL,
    remarks               VARCHAR(30)  NOT NULL DEFAULT '',
    CONSTRAINT uq_grade_es UNIQUE (enrollment_subject_id),
    CONSTRAINT fk_grade_es FOREIGN KEY (enrollment_subject_id) REFERENCES enrollmentsubject (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Accountability
CREATE TABLE auditlog (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NULL,
    action      VARCHAR(150) NOT NULL,
    object_type VARCHAR(80)  NOT NULL DEFAULT '',
    object_id   VARCHAR(40)  NOT NULL DEFAULT '',
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    KEY idx_audit_user (user_id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 3. BUSINESS-RULE TRIGGERS
-- ---------------------------------------------------------------------
DELIMITER $$

-- Req. 5: prevent double-booking of rooms or instructors (insert)
CREATE TRIGGER trg_schedule_no_clash_ins BEFORE INSERT ON classschedule
FOR EACH ROW
BEGIN
    DECLARE v_instructor BIGINT;
    DECLARE v_clashes INT;
    SELECT instructor_id INTO v_instructor FROM subjectoffering WHERE id = NEW.offering_id;
    SELECT COUNT(*) INTO v_clashes
      FROM classschedule cs
      JOIN subjectoffering so ON so.id = cs.offering_id
     WHERE cs.day = NEW.day
       AND cs.start_time < NEW.end_time
       AND cs.end_time   > NEW.start_time
       AND (cs.room_id = NEW.room_id OR so.instructor_id = v_instructor);
    IF v_clashes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule conflict: room or instructor is already booked.';
    END IF;
END$$

-- Req. 5: same rule on update
CREATE TRIGGER trg_schedule_no_clash_upd BEFORE UPDATE ON classschedule
FOR EACH ROW
BEGIN
    DECLARE v_instructor BIGINT;
    DECLARE v_clashes INT;
    SELECT instructor_id INTO v_instructor FROM subjectoffering WHERE id = NEW.offering_id;
    SELECT COUNT(*) INTO v_clashes
      FROM classschedule cs
      JOIN subjectoffering so ON so.id = cs.offering_id
     WHERE cs.id <> OLD.id
       AND cs.day = NEW.day
       AND cs.start_time < NEW.end_time
       AND cs.end_time   > NEW.start_time
       AND (cs.room_id = NEW.room_id OR so.instructor_id = v_instructor);
    IF v_clashes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule conflict: room or instructor is already booked.';
    END IF;
END$$

-- Req. 3: capacity, prerequisite and student schedule-conflict checks
-- A prerequisite counts as satisfied when the student has a grade row
-- for that subject whose remarks = 'PASSED'.
CREATE TRIGGER trg_enrollmentsubject_validate BEFORE INSERT ON enrollmentsubject
FOR EACH ROW
BEGIN
    DECLARE v_student   BIGINT;
    DECLARE v_curr      BIGINT;
    DECLARE v_capacity  INT;
    DECLARE v_taken     INT;
    DECLARE v_unmet     INT;
    DECLARE v_clashes   INT;

    SELECT student_id INTO v_student FROM enrollment WHERE id = NEW.enrollment_id;
    SELECT curriculum_subject_id, capacity INTO v_curr, v_capacity
      FROM subjectoffering WHERE id = NEW.offering_id;

    -- capacity
    SELECT COUNT(*) INTO v_taken FROM enrollmentsubject WHERE offering_id = NEW.offering_id;
    IF v_taken >= v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is full.';
    END IF;

    -- prerequisites
    SELECT COUNT(*) INTO v_unmet
      FROM curriculumsubject_prerequisites p
     WHERE p.curriculumsubject_id = v_curr
       AND NOT EXISTS (
            SELECT 1
              FROM enrollmentsubject es2
              JOIN enrollment e2          ON e2.id  = es2.enrollment_id AND e2.student_id = v_student
              JOIN subjectoffering so2    ON so2.id = es2.offering_id
              JOIN curriculumsubject cs2  ON cs2.id = so2.curriculum_subject_id
              JOIN grade g2               ON g2.enrollment_subject_id = es2.id
             WHERE cs2.subject_id = p.subject_id
               AND g2.remarks = 'PASSED');
    IF v_unmet > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prerequisite not satisfied for this subject.';
    END IF;

    -- student's own schedule clash within the same enrollment (same term)
    SELECT COUNT(*) INTO v_clashes
      FROM classschedule new_s
      JOIN enrollmentsubject es3 ON es3.enrollment_id = NEW.enrollment_id
      JOIN classschedule old_s    ON old_s.offering_id = es3.offering_id
     WHERE new_s.offering_id = NEW.offering_id
       AND old_s.day = new_s.day
       AND old_s.start_time < new_s.end_time
       AND old_s.end_time   > new_s.start_time;
    IF v_clashes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Schedule conflict with a subject already selected.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 4. STORED PROCEDURES
-- ---------------------------------------------------------------------

-- Req. 1: register a student and generate the unique ID (STU-000001 ...)
CREATE PROCEDURE sp_register_student (
    IN  p_first_name  VARCHAR(80),
    IN  p_middle_name VARCHAR(80),
    IN  p_last_name   VARCHAR(80),
    IN  p_birth_date  DATE,
    IN  p_gender      CHAR(1),
    IN  p_email       VARCHAR(254),
    IN  p_phone       VARCHAR(30),
    IN  p_address     TEXT,
    IN  p_program_id  BIGINT,
    IN  p_year_level  SMALLINT UNSIGNED,
    OUT p_student_id  VARCHAR(20)
)
BEGIN
    DECLARE v_pk BIGINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    INSERT INTO student
        (student_id, first_name, middle_name, last_name, birth_date, gender,
         email, phone, address, program_id, year_level)
    VALUES
        (LEFT(CONCAT('TMP', REPLACE(UUID(), '-', '')), 20),
         p_first_name, COALESCE(p_middle_name, ''), p_last_name, p_birth_date, COALESCE(p_gender, ''),
         COALESCE(p_email, ''), COALESCE(p_phone, ''), p_address, p_program_id, COALESCE(p_year_level, 1));
    SET v_pk = LAST_INSERT_ID();
    SET p_student_id = CONCAT('STU-', LPAD(v_pk, 6, '0'));
    UPDATE student SET student_id = p_student_id WHERE id = v_pk;
    COMMIT;
END$$

-- Req. 4: compute tuition and other fees from the selected subjects
--   per-unit fees  = fee amount x total enrolled units
--   fixed fees     = fee amount
-- Re-running replaces the existing assessment of that enrollment.
CREATE PROCEDURE sp_generate_assessment (IN p_enrollment_id BIGINT)
BEGIN
    DECLARE v_units DECIMAL(8,1);

    SELECT COALESCE(SUM(s.units), 0) INTO v_units
      FROM enrollmentsubject es
      JOIN subjectoffering so   ON so.id = es.offering_id
      JOIN curriculumsubject cs ON cs.id = so.curriculum_subject_id
      JOIN subject s            ON s.id  = cs.subject_id
     WHERE es.enrollment_id = p_enrollment_id;

    START TRANSACTION;
    DELETE FROM assessmentitem WHERE enrollment_id = p_enrollment_id;
    INSERT INTO assessmentitem (enrollment_id, fee_id, description, amount)
    SELECT p_enrollment_id,
           f.id,
           IF(f.is_per_unit, CONCAT(f.name, ' (', v_units, ' units x ', f.amount, ')'), f.name),
           IF(f.is_per_unit, f.amount * v_units, f.amount)
      FROM fee f
     WHERE f.active = 1;
    COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 5. VIEWS (outputs / reports)
-- ---------------------------------------------------------------------

-- Req. 4: Assessment Form - every charge with payment breakdown per enrollment
CREATE VIEW v_assessment_form AS
SELECT e.id            AS enrollment_id,
       st.student_id,
       CONCAT(st.last_name, ', ', st.first_name, ' ', st.middle_name) AS student_name,
       p.code          AS program,
       st.year_level,
       CONCAT(t.name, ' AY ', t.school_year) AS term,
       ai.description  AS charge,
       ai.amount       AS charge_amount
  FROM assessmentitem ai
  JOIN enrollment e ON e.id = ai.enrollment_id
  JOIN student st   ON st.id = e.student_id
  JOIN program p    ON p.id = st.program_id
  JOIN schoolterm t ON t.id = e.term_id;

-- Req. 4: assessed - paid = balance (balance is derived, never stored)
CREATE VIEW v_enrollment_balance AS
SELECT e.id AS enrollment_id,
       st.student_id,
       CONCAT(st.last_name, ', ', st.first_name) AS student_name,
       CONCAT(t.name, ' AY ', t.school_year)     AS term,
       COALESCE((SELECT SUM(ai.amount) FROM assessmentitem ai WHERE ai.enrollment_id = e.id), 0) AS assessed,
       COALESCE((SELECT SUM(pm.amount) FROM payment pm        WHERE pm.enrollment_id = e.id), 0) AS paid,
       COALESCE((SELECT SUM(ai.amount) FROM assessmentitem ai WHERE ai.enrollment_id = e.id), 0)
     - COALESCE((SELECT SUM(pm.amount) FROM payment pm        WHERE pm.enrollment_id = e.id), 0) AS balance
  FROM enrollment e
  JOIN student st   ON st.id = e.student_id
  JOIN schoolterm t ON t.id  = e.term_id;

-- Req. 5: classes (with day, time, room, instructor) shown during enrollment
CREATE VIEW v_available_classes AS
SELECT so.id AS offering_id,
       t.id  AS term_id,
       CONCAT(t.name, ' AY ', t.school_year) AS term,
       sec.program_id,
       sec.year_level,
       sec.code AS section,
       sub.code AS subject_code,
       sub.title AS subject_title,
       sub.units,
       CASE cs.day WHEN '0' THEN 'Monday' WHEN '1' THEN 'Tuesday' WHEN '2' THEN 'Wednesday'
                   WHEN '3' THEN 'Thursday' WHEN '4' THEN 'Friday' WHEN '5' THEN 'Saturday'
                   WHEN '6' THEN 'Sunday' END AS day_name,
       cs.start_time, cs.end_time,
       r.code AS room,
       ins.employee_no AS instructor_employee_no,
       so.capacity,
       so.capacity - (SELECT COUNT(*) FROM enrollmentsubject es WHERE es.offering_id = so.id) AS slots_left
  FROM subjectoffering so
  JOIN section sec           ON sec.id = so.section_id
  JOIN schoolterm t          ON t.id   = sec.term_id
  JOIN curriculumsubject cur ON cur.id = so.curriculum_subject_id
  JOIN subject sub           ON sub.id = cur.subject_id
  JOIN instructor ins        ON ins.id = so.instructor_id
  LEFT JOIN classschedule cs ON cs.offering_id = so.id
  LEFT JOIN room r           ON r.id   = cs.room_id;

-- Req. 6: list of enrolled students per course (program) and year level
CREATE VIEW v_enrolled_students_per_course AS
SELECT CONCAT(t.name, ' AY ', t.school_year) AS term,
       p.code AS program,
       st.year_level,
       st.student_id,
       CONCAT(st.last_name, ', ', st.first_name, ' ', st.middle_name) AS student_name
  FROM enrollment e
  JOIN student st   ON st.id = e.student_id
  JOIN program p    ON p.id  = st.program_id
  JOIN schoolterm t ON t.id  = e.term_id
 WHERE e.status = 'ENROLLED';

-- Req. 6: total enrollment per semester
CREATE VIEW v_enrollment_per_term AS
SELECT t.id AS term_id, t.name AS term_name, t.school_year,
       COUNT(e.id) AS total_applications,
       SUM(e.status = 'ENROLLED') AS total_enrolled
  FROM schoolterm t
  LEFT JOIN enrollment e ON e.term_id = t.id
 GROUP BY t.id, t.name, t.school_year;

-- Req. 6: collection report for finance
CREATE VIEW v_collection_report AS
SELECT DATE(pm.paid_at) AS payment_date,
       pm.method,
       COUNT(*)         AS transactions,
       SUM(pm.amount)   AS total_collected
  FROM payment pm
 GROUP BY DATE(pm.paid_at), pm.method;

-- Grades table output
CREATE VIEW v_student_grades AS
SELECT st.student_id,
       CONCAT(st.last_name, ', ', st.first_name) AS student_name,
       CONCAT(t.name, ' AY ', t.school_year)     AS term,
       sub.code AS subject_code, sub.title AS subject_title,
       g.prelim, g.midterm, g.final, g.remarks
  FROM grade g
  JOIN enrollmentsubject es  ON es.id  = g.enrollment_subject_id
  JOIN enrollment e          ON e.id   = es.enrollment_id
  JOIN student st            ON st.id  = e.student_id
  JOIN schoolterm t          ON t.id   = e.term_id
  JOIN subjectoffering so    ON so.id  = es.offering_id
  JOIN curriculumsubject cur ON cur.id = so.curriculum_subject_id
  JOIN subject sub           ON sub.id = cur.subject_id;

-- ---------------------------------------------------------------------
-- 6. OPTIONAL: foreign keys to Django's auth_user
--    Run this block only AFTER Django has created auth_user
--    (python manage.py migrate auth). Safe to skip.
-- ---------------------------------------------------------------------
-- ALTER TABLE student    ADD CONSTRAINT fk_student_user       FOREIGN KEY (user_id)        REFERENCES auth_user (id) ON DELETE SET NULL;
-- ALTER TABLE instructor ADD CONSTRAINT fk_instructor_user    FOREIGN KEY (user_id)        REFERENCES auth_user (id) ON DELETE CASCADE;
-- ALTER TABLE enrollment ADD CONSTRAINT fk_enrollment_approver FOREIGN KEY (approved_by_id) REFERENCES auth_user (id) ON DELETE SET NULL;
-- ALTER TABLE payment    ADD CONSTRAINT fk_payment_user       FOREIGN KEY (recorded_by_id) REFERENCES auth_user (id) ON DELETE RESTRICT;
-- ALTER TABLE auditlog   ADD CONSTRAINT fk_audit_user         FOREIGN KEY (user_id)        REFERENCES auth_user (id) ON DELETE SET NULL;

-- =====================================================================
--  Example usage
--    CALL sp_register_student('Juan', '', 'Santos', '2005-05-15', 'M',
--         'juan@example.com', '09170000000', 'Puerto Princesa', 1, 1, @sid);
--    SELECT @sid;
--    CALL sp_generate_assessment(1);
--    SELECT * FROM v_enrollment_balance;
-- =====================================================================
