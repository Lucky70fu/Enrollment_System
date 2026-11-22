
from datetime import date

from django.core.management.base import BaseCommand
from core.models import (
    Department,
    Program,
    SchoolTerm,
    Subject,
    CurriculumSubject,
    Student,
)


class Command(BaseCommand):
    help = "Populate the database with temporary demonstration data"

    def handle(self, *args, **options):

        self.stdout.write("Creating PSU-style demo records...")

        # 1. Colleges
        colleges = [
            ("CEAT", "College of Engineering, Architecture and Technology"),
            ("CBA", "College of Business and Accountancy"),
            ("CTE", "College of Teacher Education"),
            ("CS", "College of Sciences"),
            ("CHMT", "College of Hospitality Management and Tourism"),
            ("CNHS", "College of Nursing and Health Sciences"),
            ("CAH", "College of Arts and Humanities"),
            ("CCJE", "College of Criminal Justice Education"),
        ]

        college_objects = {}

        for code, name in colleges:
            college, created = Department.objects.get_or_create(
                code=code,
                defaults={"name": name}
            )
            college_objects[code] = college

        # 2. Academic Programs (sample offerings only)
        programs = [
            ("BSIT", "Bachelor of Science in Information Technology", "CEAT"),
            ("BSCE", "Bachelor of Science in Civil Engineering", "CEAT"),
            ("BSBA", "Bachelor of Science in Business Administration", "CBA"),
            ("BSED", "Bachelor of Secondary Education", "CTE"),
            ("BSBIO", "Bachelor of Science in Biology", "CS"),
            ("BSHM", "Bachelor of Science in Hospitality Management", "CHMT"),
            ("BSN", "Bachelor of Science in Nursing", "CNHS"),
            ("BSCrim", "Bachelor of Science in Criminology", "CCJE"),
        ]

        program_objects = {}

        for code, name, college_code in programs:
            program, created = Program.objects.get_or_create(
                code=code,
                defaults={
                    "name": name,
                    "department": college_objects[college_code],
                    "years_to_complete": 4,
                }
            )
            program_objects[code] = program

        # 3. Academic Term
        term, created = SchoolTerm.objects.get_or_create(
            name="1st Semester",
            school_year="2026-2027",
            defaults={
                "starts_on": date(2026, 8, 1),
                "ends_on": date(2026, 12, 31),
                "is_open": True,
            }
        )

        # 4. Sample Subjects
        subjects = [
            ("GE101", "Understanding the Self", 3),
            ("GE102", "Mathematics in the Modern World", 3),
            ("GE103", "Purposive Communication", 3),
            ("IT101", "Introduction to Computing", 3),
            ("IT102", "Computer Programming 1", 3),
            ("NSTP1", "National Service Training Program 1", 3),
            ("PE101", "Physical Education 1", 2),
        ]

        subject_objects = {}

        for code, title, units in subjects:
            subject, created = Subject.objects.get_or_create(
                code=code,
                defaults={
                    "title": title,
                    "units": units,
                }
            )
            subject_objects[code] = subject

        # 5. Connect sample subjects to programs
        for program_code, program in program_objects.items():
            for subject_code in subjects:
                subject = subject_objects[subject_code[0]]

                CurriculumSubject.objects.get_or_create(
                    program=program,
                    subject=subject,
                    year_level=1,
                    semester="1st Semester",
                )

        # 6. Sample Students
        sample_students = [
            ("Juan", "Santos", "juan.santos.demo@example.com", "BSIT"),
            ("Maria", "Reyes", "maria.reyes.demo@example.com", "BSBA"),
            ("Pedro", "Cruz", "pedro.cruz.demo@example.com", "BSED"),
            ("Ana", "Garcia", "ana.garcia.demo@example.com", "BSBIO"),
            ("Jose", "Mendoza", "jose.mendoza.demo@example.com", "BSHM"),
            ("Angela", "Dela Cruz", "angela.delacruz.demo@example.com", "BSN"),
        ]

        for first, last, email, program_code in sample_students:
            Student.objects.get_or_create(
                email=email,
                defaults={
                    "first_name": first,
                    "last_name": last,
                    "program": program_objects[program_code],
                    "year_level": 1,
                    "birth_date": date(2005, 5, 15),
                    "gender": "F" if first in ["Maria", "Ana", "Angela"] else "M",
                    "phone": "09170000000",
                    "address": "Puerto Princesa City, Palawan",
                }
            )

        self.stdout.write(self.style.SUCCESS(
            "Demo data successfully created!"
        ))
        self.stdout.write("8 Colleges")
        self.stdout.write("8 Academic Programs")
        self.stdout.write("1 Academic Term")
        self.stdout.write("7 Subjects")
        self.stdout.write("Curriculum assignments for all programs")
        self.stdout.write("6 Sample Students")
