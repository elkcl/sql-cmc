DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

CREATE TYPE degree_t AS ENUM ('бакалавр', 'магистр', 'кандидат', 'доктор');
CREATE TYPE tuition_t AS ENUM ('бюджет', 'контракт');

CREATE FUNCTION next_degree(degree_t) RETURNS degree_t AS
$$
SELECT *
FROM unnest(enum_range(NULL::degree_t)) AS d
WHERE d > $1
ORDER BY d
LIMIT 1;
$$ LANGUAGE SQL STABLE;


CREATE TABLE departments (
	department_id SERIAL PRIMARY KEY,
	"name" text NOT NULL,
	dean text NOT NULL
);

CREATE TABLE majors (
	major_id SERIAL PRIMARY KEY,
	department_id integer REFERENCES departments (department_id) NOT NULL,
	"name" text NOT NULL,
	duration integer NOT NULL,
	free_places integer NOT NULL,
	paid_places integer NOT NULL,
	"degree" degree_t NOT NULL CHECK (degree <= 'кандидат')
);

CREATE TABLE "groups" (
	group_id SERIAL PRIMARY KEY,
	major_id integer REFERENCES majors (major_id) NOT NULL,
	"name" text NOT NULL
);

CREATE TABLE subjects (
	subject_id SERIAL PRIMARY KEY,
	"name" text NOT NULL,
	credits integer NOT NULL
);

CREATE TABLE studies (
	group_id integer REFERENCES "groups" (group_id) NOT NULL,
	subject_id integer REFERENCES subjects (subject_id) NOT NULL,
	UNIQUE (group_id, subject_id)
);

CREATE TABLE teachers (
	teacher_id SERIAL PRIMARY KEY,
	last_name text NOT NULL,
	first_name text NOT NULL,
	patronym text,
	"degree" degree_t NOT NULL CHECK (degree >= 'магистр')
);

CREATE TABLE teachings (
	teacher_id integer REFERENCES teachers (teacher_id) NOT NULL,
	subject_id integer REFERENCES subjects (subject_id) NOT NULL,
	UNIQUE (teacher_id, subject_id)
);

CREATE TABLE students (
	student_id SERIAL PRIMARY KEY,
	last_name text NOT NULL,
	first_name text NOT NULL,
	patronym text,
	birthday date NOT NULL,
	city text NOT NULL
);

CREATE TABLE enrollments (
	student_id integer REFERENCES students (student_id) NOT NULL,
	group_id integer REFERENCES "groups" (group_id) NOT NULL,
	mentor_id integer REFERENCES teachers (teacher_id),
	enrollment_year integer NOT NULL,
	tuition_type tuition_t NOT NULL,
	UNIQUE (student_id, group_id)
);

CREATE FUNCTION enroll_check() RETURNS trigger AS $enroll_check$
    DECLARE
	    mentor_degree degree_t;
		my_degree degree_t;
		my_major integer;
		my_free_places integer;
		my_paid_places integer;
		curr_free integer;
		curr_paid integer;
    BEGIN
		mentor_degree := (
		    SELECT teachers.degree 
		    FROM teachers
			WHERE teachers.teacher_id = NEW.mentor_id
		);
		my_degree := (
		    SELECT majors.degree 
			FROM majors
			JOIN "groups" ON "groups".major_id = majors.major_id AND "groups".group_id = NEW.group_id
		);
		IF my_degree >= mentor_degree THEN
		    RAISE EXCEPTION 'mentor''s degree must be higher than the student''s';
		END IF;

        SELECT majors.free_places, majors.paid_places
		INTO my_free_places, my_paid_places
		FROM majors
		JOIN "groups" ON "groups".major_id = majors.major_id AND "groups".group_id = NEW.group_id;

        my_major := (
            SELECT "groups".major_id
			FROM "groups"
			WHERE "groups".group_id = NEW.group_id
		);

		curr_free := (
            SELECT count(*)
			FROM enrollments
			JOIN "groups" ON "groups".group_id = enrollments.group_id AND "groups".major_id = my_major
			WHERE enrollments.tuition_type = 'бюджет'
		);
		curr_paid := (
            SELECT count(*)
			FROM enrollments
			JOIN "groups" ON "groups".group_id = enrollments.group_id AND "groups".major_id = my_major
			WHERE enrollments.tuition_type = 'контракт'
		);

		IF NEW.tuition_type = 'бюджет' THEN
		    curr_free := curr_free + 1;
		END IF;
		IF NEW.tuition_type = 'контракт' THEN
		    curr_paid := curr_paid + 1;
		END IF;
		IF OLD IS NOT NULL THEN
            IF OLD.tuition_type = 'бюджет' THEN
		        curr_free := curr_free - 1;
		    END IF;
		    IF OLD.tuition_type = 'контракт' THEN
		        curr_paid := curr_paid - 1;
		    END IF;
		END IF;

		IF curr_free > my_free_places THEN
		    RAISE EXCEPTION 'not enough free places in a major';
		END IF;
		IF curr_paid > my_paid_places THEN
		    RAISE EXCEPTION 'not enough paid places in a major';
		END IF;
		
        RETURN NEW;
    END;
$enroll_check$ LANGUAGE plpgsql;

CREATE TRIGGER enroll_check 
BEFORE INSERT OR UPDATE OF mentor_id, group_id, tuition_type
ON enrollments
FOR EACH ROW EXECUTE FUNCTION enroll_check();

CREATE FUNCTION mentor_check() RETURNS trigger AS $mentor_check$
    BEGIN
	    IF EXISTS (
		    SELECT
		    FROM enrollments
		         JOIN "groups" USING (group_id)
			     JOIN majors USING (major_id)
		    WHERE enrollments.mentor_id = NEW.teacher_id AND majors.degree >= NEW.degree
		) THEN
		    RAISE EXCEPTION 'mentor''s degree must be higher than the student''s';
		END IF;
        RETURN NEW;
    END;
$mentor_check$ LANGUAGE plpgsql;

CREATE TRIGGER mentor_check 
BEFORE UPDATE OF "degree"
ON teachers
FOR EACH ROW EXECUTE FUNCTION mentor_check();

CREATE FUNCTION group_check() RETURNS trigger AS $group_check$
    DECLARE
		my_degree degree_t;
		my_free_places integer;
		my_paid_places integer;
		curr_free integer;
		curr_paid integer;
    BEGIN
        SELECT majors.free_places, majors.paid_places
		INTO my_free_places, my_paid_places
		FROM majors
		WHERE majors.major_id = NEW.major_id;
		curr_free := (
            SELECT count(*)
			FROM enrollments
			WHERE enrollments.group_id = NEW.group_id AND enrollments.tuition_type = 'бюджет'
		);
		curr_paid := (
            SELECT count(*)
			FROM enrollments
			WHERE enrollments.group_id = NEW.group_id AND enrollments.tuition_type = 'контракт'
		);
		IF curr_free > my_free_places THEN
		    RAISE EXCEPTION 'not enough free places in a major';
		END IF;
		IF curr_paid > my_paid_places THEN
		    RAISE EXCEPTION 'not enough paid places in a major';
		END IF;

		my_degree := (
            SELECT majors.degree
			FROM majors
			WHERE majors.major_id = NEW.major_id
		);
		IF EXISTS (
		    SELECT
		    FROM enrollments
			     JOIN teachers ON teachers.teacher_id = enrollments.mentor_id
			                      AND enrollments.group_id = NEW.group_id
		    WHERE my_degree >= teachers.degree
		) THEN
		    RAISE EXCEPTION 'mentor''s degree must be higher than the student''s';
		END IF;
		
        RETURN NEW;
    END;
$group_check$ LANGUAGE plpgsql;

CREATE TRIGGER group_check 
BEFORE UPDATE OF major_id
ON "groups"
FOR EACH ROW EXECUTE FUNCTION group_check();

CREATE FUNCTION major_check() RETURNS trigger AS $major_check$
    DECLARE
		curr_free integer;
		curr_paid integer;
    BEGIN
        curr_free := (
            SELECT count(*)
			FROM enrollments
			JOIN "groups" ON "groups".group_id = enrollments.group_id
			                 AND "groups".major_id = NEW.major_id
 			                 AND enrollments.tuition_type = 'бюджет'
		);
		curr_paid := (
            SELECT count(*)
			FROM enrollments
			JOIN "groups" ON "groups".group_id = enrollments.group_id
			                 AND "groups".major_id = NEW.major_id
 			                 AND enrollments.tuition_type = 'контракт'
		);
		IF curr_free > NEW.free_places THEN
		    RAISE EXCEPTION 'not enough free places in a major';
		END IF;
		IF curr_paid > NEW.paid_places THEN
		    RAISE EXCEPTION 'not enough paid places in a major';
		END IF;
		IF EXISTS (
		    SELECT
		    FROM "groups"
		         JOIN enrollments ON enrollments.group_id = "groups".group_id
			                      AND "groups".major_id = NEW.major_id
			     JOIN teachers ON teachers.teacher_id = enrollments.mentor_id
		                          AND NEW.degree >= teachers.degree
		) THEN
		    RAISE EXCEPTION 'mentor''s degree must be higher than the student''s';
		END IF;
		
        RETURN NEW;
    END;
$major_check$ LANGUAGE plpgsql;

CREATE TRIGGER major_check 
BEFORE UPDATE OF free_places, paid_places, "degree"
ON majors
FOR EACH ROW EXECUTE FUNCTION major_check();

INSERT INTO departments VALUES (DEFAULT, 'ШВТ', 'Лапшин Родион Петрович');
INSERT INTO departments VALUES (DEFAULT, 'ЗПБ', 'Седова Мария Сергеевна');
INSERT INTO departments VALUES (DEFAULT, 'ЛЦТ', 'Уварова Валерия Максимовна');
INSERT INTO departments VALUES (DEFAULT, 'ШДВ', 'Медведева Моника Святославовна');
INSERT INTO departments VALUES (DEFAULT, 'ШЦВ', 'Елисеев Игорь Юрьевич');
INSERT INTO departments VALUES (DEFAULT, 'УШБ', 'Зайцева Елизавета Ильинична');
INSERT INTO departments VALUES (DEFAULT, 'СДН', 'Иванова Анна Ильинична');
INSERT INTO departments VALUES (DEFAULT, 'ЗФТ', 'Тимофеев Иван Георгиевич');
INSERT INTO departments VALUES (DEFAULT, 'УЛК', 'Кириллов Ярослав Глебович');
INSERT INTO departments VALUES (DEFAULT, 'ВСР', 'Уваров Георгий Юрьевич');

INSERT INTO students VALUES (DEFAULT, 'Игнатова', 'Анна', 'Павловна', date '2008-10-24', 'Новгород');
INSERT INTO students VALUES (DEFAULT, 'Алехина', 'Анна', 'Николаевна', date '2001-5-13', 'Барнаул');
INSERT INTO students VALUES (DEFAULT, 'Соколова', 'Софья', 'Петровна', date '2001-2-14', 'Владивосток');
INSERT INTO students VALUES (DEFAULT, 'Афанасьев', 'Михаил', NULL, date '2006-12-22', 'Уфа');
INSERT INTO students VALUES (DEFAULT, 'Самсонов', 'Александр', 'Никитич', date '1999-11-1', 'Владивосток');
INSERT INTO students VALUES (DEFAULT, 'Ермакова', 'Ясмина', 'Андреевна', date '2004-4-6', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Александрова', 'Полина', 'Кирилловна', date '2009-8-20', 'Омск');
INSERT INTO students VALUES (DEFAULT, 'Воронцова', 'Варвара', 'Григорьевна', date '2010-9-20', 'Краснодар');
INSERT INTO students VALUES (DEFAULT, 'Белова', 'Мелания', 'Лукинична', date '2010-10-2', 'Ульяновск');
INSERT INTO students VALUES (DEFAULT, 'Носова', 'Полина', 'Данииловна', date '1996-2-10', 'Казань');
INSERT INTO students VALUES (DEFAULT, 'Чернов', 'Михаил', 'Артёмович', date '2008-6-1', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Алехина', 'Анна', 'Николаевна', date '1997-9-2', 'Иркутск');
INSERT INTO students VALUES (DEFAULT, 'Орлова', 'Анастасия', 'Васильевна', date '1999-4-20', 'Новгород');
INSERT INTO students VALUES (DEFAULT, 'Ульянов', 'Артём', 'Артёмович', date '1995-11-2', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Петров', 'Иван', 'Артурович', date '2008-8-1', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Зуева', 'Василиса', 'Даниэльевна', date '2010-12-12', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Макаров', 'Даниил', 'Иванович', date '2010-5-9', 'Новосибирск');
INSERT INTO students VALUES (DEFAULT, 'Покровская', 'Арина', NULL, date '1995-6-27', 'Новосибирск');
INSERT INTO students VALUES (DEFAULT, 'Козлов', 'Валерий', 'Робертович', date '2007-5-2', 'Тольятти');
INSERT INTO students VALUES (DEFAULT, 'Басова', 'Эмма', 'Николаевна', date '2009-12-2', 'Волгоград');
INSERT INTO students VALUES (DEFAULT, 'Прохоров', 'Илья', 'Михайлович', date '1994-1-21', 'Красноярск');
INSERT INTO students VALUES (DEFAULT, 'Николаев', 'Александр', 'Тимофеевич', date '1996-6-22', 'Ульяновск');
INSERT INTO students VALUES (DEFAULT, 'Жукова', 'Варвара', 'Михайловна', date '1996-3-16', 'Пермь');
INSERT INTO students VALUES (DEFAULT, 'Чернов', 'Фёдор', 'Андреевич', date '1995-4-23', 'Владивосток');
INSERT INTO students VALUES (DEFAULT, 'Алехина', 'Анна', 'Николаевна', date '1996-10-14', 'Кемерово');
INSERT INTO students VALUES (DEFAULT, 'Алексеев', 'Давид', 'Кириллович', date '2009-12-21', 'Ростов-на-Дону');
INSERT INTO students VALUES (DEFAULT, 'Александрова', 'Софья', 'Ярославовна', date '2009-4-21', 'Волгоград');
INSERT INTO students VALUES (DEFAULT, 'Кудрявцев', 'Алексей', 'Фёдорович', date '2007-6-25', 'Пермь');
INSERT INTO students VALUES (DEFAULT, 'Лазарев', 'Владимир', 'Максимович', date '1999-8-19', 'Пермь');
INSERT INTO students VALUES (DEFAULT, 'Большакова', 'Александра', 'Николаевна', date '1998-12-8', 'Пермь');
INSERT INTO students VALUES (DEFAULT, 'Полякова', 'Маргарита', 'Максимовна', date '1990-6-3', 'Владивосток');
INSERT INTO students VALUES (DEFAULT, 'Филиппов', 'Денис', 'Даниилович', date '2009-7-5', 'Санкт-Петербург');
INSERT INTO students VALUES (DEFAULT, 'Кожевникова', 'Анна', 'Тиграновна', date '1996-11-15', 'Екатеринбург');
INSERT INTO students VALUES (DEFAULT, 'Логинов', 'Платон', 'Даниилович', date '2005-12-7', 'Уфа');
INSERT INTO students VALUES (DEFAULT, 'Игнатова', 'Анна', 'Павловна', date '1998-10-4', 'Ульяновск');
INSERT INTO students VALUES (DEFAULT, 'Громова', 'Анастасия', 'Захаровна', date '2008-11-21', 'Санкт-Петербург');
INSERT INTO students VALUES (DEFAULT, 'Парфенова', 'Софья', 'Борисовна', date '1990-3-5', 'Красноярск');
INSERT INTO students VALUES (DEFAULT, 'Смирнов', 'Семён', NULL, date '2010-12-20', 'Воронеж');
INSERT INTO students VALUES (DEFAULT, 'Крюкова', 'Дарья', 'Владимировна', date '1990-3-26', 'Казань');
INSERT INTO students VALUES (DEFAULT, 'Власова', 'Алия', 'Егоровна', date '1997-11-2', 'Барнаул');
INSERT INTO students VALUES (DEFAULT, 'Рудакова', 'Таисия', 'Андреевна', date '2002-11-10', 'Иркутск');
INSERT INTO students VALUES (DEFAULT, 'Александрова', 'Полина', 'Кирилловна', date '2003-6-26', 'Ярославль');
INSERT INTO students VALUES (DEFAULT, 'Семенова', 'Татьяна', 'Артёмовна', date '1992-12-1', 'Кемерово');
INSERT INTO students VALUES (DEFAULT, 'Антипов', 'Степан', 'Романович', date '1996-3-22', 'Казань');
INSERT INTO students VALUES (DEFAULT, 'Фомичев', 'Евгений', 'Дмитриевич', date '2007-11-13', 'Краснодар');
INSERT INTO students VALUES (DEFAULT, 'Касьянов', 'Али', NULL, date '1991-7-8', 'Ульяновск');
INSERT INTO students VALUES (DEFAULT, 'Краснова', 'София', 'Дмитриевна', date '2007-8-16', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Фролова', 'Сафия', 'Романовна', date '1992-11-22', 'Нижний');
INSERT INTO students VALUES (DEFAULT, 'Яковлева', 'Ангелина', 'Дмитриевна', date '2002-1-1', 'Кемерово');
INSERT INTO students VALUES (DEFAULT, 'Касьянов', 'Али', 'Иванович', date '2007-2-28', 'Ярославль');
INSERT INTO students VALUES (DEFAULT, 'Шубина', 'Вера', NULL, date '2006-9-10', 'Нижний');
INSERT INTO students VALUES (DEFAULT, 'Митрофанова', 'Ксения', 'Саввична', date '2003-5-16', 'Уфа');
INSERT INTO students VALUES (DEFAULT, 'Козлова', 'Софья', 'Константиновна', date '2000-1-25', 'Ижевск');
INSERT INTO students VALUES (DEFAULT, 'Миронова', 'Виктория', 'Мирославовна', date '1991-6-26', 'Волгоград');
INSERT INTO students VALUES (DEFAULT, 'Андреев', 'Ярослав', 'Александрович', date '1995-1-16', 'Ульяновск');
INSERT INTO students VALUES (DEFAULT, 'Воронина', 'Лея', 'Михайловна', date '2003-4-3', 'Тольятти');
INSERT INTO students VALUES (DEFAULT, 'Зуева', 'Василиса', 'Даниэльевна', date '1995-7-8', 'Оренбург');
INSERT INTO students VALUES (DEFAULT, 'Смирнов', 'Семён', NULL, date '2006-3-14', 'Москва');
INSERT INTO students VALUES (DEFAULT, 'Михайлова', 'Ольга', NULL, date '2006-9-25', 'Челябинск');
INSERT INTO students VALUES (DEFAULT, 'Горюнов', 'Фёдор', 'Саввич', date '2010-6-10', 'Санкт-Петербург');
INSERT INTO students VALUES (DEFAULT, 'Новиков', 'Захар', 'Денисович', date '2000-1-25', 'Уфа');
INSERT INTO students VALUES (DEFAULT, 'Ковалева', 'Стефания', 'Марковна', date '1996-2-18', 'Москва');
INSERT INTO students VALUES (DEFAULT, 'Прохоров', 'Леонид', 'Николаевич', date '2006-7-2', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Афанасьев', 'Михаил', 'Тимурович', date '2010-1-22', 'Ижевск');
INSERT INTO students VALUES (DEFAULT, 'Комарова', 'Варвара', 'Данииловна', date '1992-6-20', 'Саратов');
INSERT INTO students VALUES (DEFAULT, 'Андреева', 'Есения', 'Богдановна', date '1996-2-15', 'Краснодар');
INSERT INTO students VALUES (DEFAULT, 'Ефимова', 'Дарья', 'Дмитриевна', date '1991-3-5', 'Екатеринбург');
INSERT INTO students VALUES (DEFAULT, 'Агафонов', 'Александр', 'Егорович', date '2003-3-5', 'Казань');
INSERT INTO students VALUES (DEFAULT, 'Логинов', 'Александр', 'Янович', date '2000-2-12', 'Ижевск');
INSERT INTO students VALUES (DEFAULT, 'Назаров', 'Фёдор', 'Глебович', date '2009-8-9', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Петрова', 'Алиса', 'Денисовна', date '1998-8-9', 'Нижний');
INSERT INTO students VALUES (DEFAULT, 'Исаев', 'Александр', 'Львович', date '1994-12-23', 'Новгород');
INSERT INTO students VALUES (DEFAULT, 'Орлова', 'Анна', 'Данииловна', date '1990-1-8', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Ермакова', 'Ясмина', 'Андреевна', date '1996-11-3', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Дмитриев', 'Павел', 'Миронович', date '2006-10-13', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Самсонов', 'Александр', 'Никитич', date '1995-12-27', 'Уфа');
INSERT INTO students VALUES (DEFAULT, 'Назаров', 'Фёдор', NULL, date '2006-11-2', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Логинов', 'Платон', 'Даниилович', date '2007-6-10', 'Ростов-на-Дону');
INSERT INTO students VALUES (DEFAULT, 'Ефимова', 'Евгения', NULL, date '1998-7-11', 'Ростов-на-Дону');
INSERT INTO students VALUES (DEFAULT, 'Кузнецова', 'Полина', 'Михайловна', date '2007-10-9', 'Тольятти');
INSERT INTO students VALUES (DEFAULT, 'Кузнецова', 'Евангелина', 'Алексеевна', date '2000-1-5', 'Волгоград');
INSERT INTO students VALUES (DEFAULT, 'Бирюков', 'Леонид', 'Николаевич', date '2010-10-11', 'Новгород');
INSERT INTO students VALUES (DEFAULT, 'Данилова', 'Василиса', NULL, date '1990-8-3', 'Краснодар');
INSERT INTO students VALUES (DEFAULT, 'Левин', 'Сергей', 'Игоревич', date '2007-7-24', 'Челябинск');
INSERT INTO students VALUES (DEFAULT, 'Архипов', 'Максим', 'Александрович', date '2005-11-20', 'Ижевск');
INSERT INTO students VALUES (DEFAULT, 'Масленников', 'Алексей', 'Тимурович', date '2008-3-13', 'Пермь');
INSERT INTO students VALUES (DEFAULT, 'Федотова', 'Елизавета', 'Ивановна', date '1998-6-5', 'Омск');
INSERT INTO students VALUES (DEFAULT, 'Касаткин', 'Тимофей', 'Михайлович', date '2006-5-4', 'Екатеринбург');
INSERT INTO students VALUES (DEFAULT, 'Егоров', 'Александр', 'Вадимович', date '2003-3-17', 'Екатеринбург');
INSERT INTO students VALUES (DEFAULT, 'Громова', 'Анастасия', 'Захаровна', date '2001-11-14', 'Тольятти');
INSERT INTO students VALUES (DEFAULT, 'Носова', 'Полина', 'Данииловна', date '1999-2-13', 'Хабаровск');
INSERT INTO students VALUES (DEFAULT, 'Федотова', 'Елизавета', 'Ивановна', date '2004-1-4', 'Санкт-Петербург');
INSERT INTO students VALUES (DEFAULT, 'Николаева', 'Ева', 'Максимовна', date '1994-4-23', 'Новосибирск');
INSERT INTO students VALUES (DEFAULT, 'Панина', 'Алина', 'Петровна', date '1991-10-2', 'Краснодар');
INSERT INTO students VALUES (DEFAULT, 'Зуева', 'Василиса', 'Даниэльевна', date '2008-12-28', 'Ростов-на-Дону');
INSERT INTO students VALUES (DEFAULT, 'Громова', 'Анастасия', 'Захаровна', date '2000-4-10', 'Ижевск');
INSERT INTO students VALUES (DEFAULT, 'Тарасов', 'Даниил', NULL, date '1999-10-13', 'Тюмень');
INSERT INTO students VALUES (DEFAULT, 'Попова', 'Алиса', 'Дмитриевна', date '1991-9-20', 'Новокузнецк');
INSERT INTO students VALUES (DEFAULT, 'Басова', 'Ярослава', NULL, date '2003-7-13', 'Самара');
INSERT INTO students VALUES (DEFAULT, 'Аксенова', 'Ариана', 'Львовна', date '1992-4-1', 'Барнаул');

INSERT INTO majors VALUES (DEFAULT, 10, 'ТЯЛЯ', 5, 118, 182, 'магистр');
INSERT INTO majors VALUES (DEFAULT, 5, 'ВЭЧИ', 5, 47, 128, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 7, 'ТРЭИ', 5, 99, 189, 'бакалавр');
INSERT INTO majors VALUES (DEFAULT, 6, 'ДПБС', 5, 193, 196, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 8, 'ДСОЖ', 6, 167, 31, 'бакалавр');
INSERT INTO majors VALUES (DEFAULT, 7, 'БТУЦ', 4, 70, 46, 'магистр');
INSERT INTO majors VALUES (DEFAULT, 4, 'ПТСХ', 6, 105, 130, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 4, 'ОЧОЖ', 4, 176, 66, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 9, 'ОЧУР', 6, 169, 136, 'бакалавр');
INSERT INTO majors VALUES (DEFAULT, 9, 'РЧЯФ', 6, 165, 185, 'магистр');
INSERT INTO majors VALUES (DEFAULT, 5, 'УЕУН', 4, 69, 132, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 5, 'ИОАД', 4, 130, 93, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 3, 'УПВГ', 6, 193, 184, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 5, 'ЯГРД', 6, 84, 60, 'бакалавр');
INSERT INTO majors VALUES (DEFAULT, 6, 'ВГЧД', 5, 60, 140, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 6, 'УОГА', 6, 100, 123, 'магистр');
INSERT INTO majors VALUES (DEFAULT, 4, 'ТТЛЮ', 5, 56, 179, 'магистр');
INSERT INTO majors VALUES (DEFAULT, 4, 'ВЯПЦ', 4, 90, 145, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 10, 'ТЮУБ', 6, 116, 70, 'кандидат');
INSERT INTO majors VALUES (DEFAULT, 8, 'ЕШУС', 4, 111, 156, 'магистр');

INSERT INTO "groups" VALUES (DEFAULT, 9, 'ЮЭ9556');
INSERT INTO "groups" VALUES (DEFAULT, 18, 'З19');
INSERT INTO "groups" VALUES (DEFAULT, 20, 'Б7112');
INSERT INTO "groups" VALUES (DEFAULT, 8, 'УЖ486');
INSERT INTO "groups" VALUES (DEFAULT, 11, '4711');
INSERT INTO "groups" VALUES (DEFAULT, 1, 'Ж11');
INSERT INTO "groups" VALUES (DEFAULT, 3, '6459');
INSERT INTO "groups" VALUES (DEFAULT, 2, 'Ш354');
INSERT INTO "groups" VALUES (DEFAULT, 7, '06');
INSERT INTO "groups" VALUES (DEFAULT, 5, 'З096');
INSERT INTO "groups" VALUES (DEFAULT, 8, '5163');
INSERT INTO "groups" VALUES (DEFAULT, 9, 'ЛЗ9844');
INSERT INTO "groups" VALUES (DEFAULT, 2, 'ХЧ07');
INSERT INTO "groups" VALUES (DEFAULT, 12, 'Д409');
INSERT INTO "groups" VALUES (DEFAULT, 6, '40');
INSERT INTO "groups" VALUES (DEFAULT, 18, 'ОС260');
INSERT INTO "groups" VALUES (DEFAULT, 8, 'ГЦ5376');
INSERT INTO "groups" VALUES (DEFAULT, 10, '8390');
INSERT INTO "groups" VALUES (DEFAULT, 12, 'ЛТ15');
INSERT INTO "groups" VALUES (DEFAULT, 2, 'Э980');
INSERT INTO "groups" VALUES (DEFAULT, 2, 'ДА035');
INSERT INTO "groups" VALUES (DEFAULT, 15, 'РГ967');
INSERT INTO "groups" VALUES (DEFAULT, 12, '12');
INSERT INTO "groups" VALUES (DEFAULT, 20, 'Н62');
INSERT INTO "groups" VALUES (DEFAULT, 16, 'У2882');
INSERT INTO "groups" VALUES (DEFAULT, 18, '9411');
INSERT INTO "groups" VALUES (DEFAULT, 7, '6160');
INSERT INTO "groups" VALUES (DEFAULT, 12, '105');
INSERT INTO "groups" VALUES (DEFAULT, 20, 'ЛВ087');
INSERT INTO "groups" VALUES (DEFAULT, 12, 'ГЭ9722');

INSERT INTO teachers VALUES (DEFAULT, 'Анисимова', 'Арина', 'Фёдоровна', 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Белова', 'Мелания', 'Лукинична', 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Румянцев', 'Михаил', 'Петрович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Григорьев', 'Андрей', 'Ярославович', 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Попов', 'Артём', 'Даниилович', 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Смирнова', 'Алиса', NULL, 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Бирюков', 'Леонид', 'Николаевич', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Касаткин', 'Тимофей', 'Михайлович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Данилова', 'Василиса', NULL, 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Анохина', 'Анна', 'Львовна', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Левин', 'Сергей', 'Игоревич', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Карташова', 'Кира', 'Робертовна', 'магистр');
INSERT INTO teachers VALUES (DEFAULT, 'Львов', 'Тимур', 'Адамович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Масленников', 'Алексей', 'Тимурович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Лебедев', 'Александр', 'Маркович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Федотова', 'Елизавета', 'Ивановна', 'кандидат');
INSERT INTO teachers VALUES (DEFAULT, 'Белоусов', 'Илья', 'Ильич', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Касуткин', 'Михаил', 'Михайлович', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Королева', 'Мария', 'Германовна', 'доктор');
INSERT INTO teachers VALUES (DEFAULT, 'Егоров', 'Александр', 'Вадимович', 'доктор');

INSERT INTO enrollments VALUES (53, 5, 7, 2012, 'контракт');
INSERT INTO enrollments VALUES (90, 30, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (100, 30, NULL, 2010, 'контракт');
INSERT INTO enrollments VALUES (93, 13, 15, 2022, 'бюджет');
INSERT INTO enrollments VALUES (14, 2, 9, 2012, 'бюджет');
INSERT INTO enrollments VALUES (90, 3, 1, 2009, 'бюджет');
INSERT INTO enrollments VALUES (75, 17, 3, 2018, 'бюджет');
INSERT INTO enrollments VALUES (79, 27, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (77, 23, NULL, 2018, 'контракт');
INSERT INTO enrollments VALUES (79, 13, NULL, 2013, 'бюджет');
INSERT INTO enrollments VALUES (69, 20, NULL, 2011, 'контракт');
INSERT INTO enrollments VALUES (55, 13, NULL, 2022, 'бюджет');
INSERT INTO enrollments VALUES (30, 1, 17, 2013, 'контракт');
INSERT INTO enrollments VALUES (35, 25, 20, 2018, 'контракт');
INSERT INTO enrollments VALUES (58, 6, NULL, 2008, 'контракт');
INSERT INTO enrollments VALUES (41, 15, NULL, 2017, 'бюджет');
INSERT INTO enrollments VALUES (68, 16, NULL, 2011, 'контракт');
INSERT INTO enrollments VALUES (7, 25, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (75, 15, NULL, 2022, 'бюджет');
INSERT INTO enrollments VALUES (67, 22, NULL, 2018, 'контракт');
INSERT INTO enrollments VALUES (52, 20, 17, 2009, 'бюджет');
INSERT INTO enrollments VALUES (81, 27, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (94, 9, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (69, 28, NULL, 2020, 'контракт');
INSERT INTO enrollments VALUES (76, 18, 15, 2021, 'бюджет');
INSERT INTO enrollments VALUES (19, 11, 7, 2020, 'контракт');
INSERT INTO enrollments VALUES (14, 28, 9, 2015, 'контракт');
INSERT INTO enrollments VALUES (34, 6, 16, 2015, 'контракт');
INSERT INTO enrollments VALUES (14, 16, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (72, 30, NULL, 2014, 'бюджет');
INSERT INTO enrollments VALUES (25, 17, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (5, 26, NULL, 2012, 'бюджет');
INSERT INTO enrollments VALUES (73, 24, NULL, 2019, 'контракт');
INSERT INTO enrollments VALUES (67, 20, NULL, 2014, 'бюджет');
INSERT INTO enrollments VALUES (67, 11, 8, 2018, 'контракт');
INSERT INTO enrollments VALUES (41, 18, NULL, 2016, 'бюджет');
INSERT INTO enrollments VALUES (57, 10, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (26, 25, 9, 2016, 'бюджет');
INSERT INTO enrollments VALUES (86, 5, NULL, 2012, 'бюджет');
INSERT INTO enrollments VALUES (13, 17, NULL, 2019, 'контракт');
INSERT INTO enrollments VALUES (97, 3, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (33, 14, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (36, 16, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (16, 20, 15, 2016, 'бюджет');
INSERT INTO enrollments VALUES (41, 17, 11, 2023, 'контракт');
INSERT INTO enrollments VALUES (17, 14, 10, 2022, 'бюджет');
INSERT INTO enrollments VALUES (66, 10, NULL, 2009, 'контракт');
INSERT INTO enrollments VALUES (63, 25, NULL, 2016, 'бюджет');
INSERT INTO enrollments VALUES (97, 10, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (49, 24, 6, 2018, 'бюджет');
INSERT INTO enrollments VALUES (45, 28, NULL, 2008, 'контракт');
INSERT INTO enrollments VALUES (58, 28, NULL, 2024, 'контракт');
INSERT INTO enrollments VALUES (81, 16, 13, 2015, 'бюджет');
INSERT INTO enrollments VALUES (96, 8, NULL, 2016, 'бюджет');
INSERT INTO enrollments VALUES (19, 22, NULL, 2023, 'контракт');
INSERT INTO enrollments VALUES (85, 25, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (87, 11, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (99, 4, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (12, 30, 15, 2014, 'контракт');
INSERT INTO enrollments VALUES (25, 23, 11, 2021, 'бюджет');
INSERT INTO enrollments VALUES (30, 7, NULL, 2008, 'контракт');
INSERT INTO enrollments VALUES (24, 19, NULL, 2018, 'бюджет');
INSERT INTO enrollments VALUES (91, 10, NULL, 2017, 'контракт');
INSERT INTO enrollments VALUES (5, 15, NULL, 2023, 'контракт');
INSERT INTO enrollments VALUES (41, 26, NULL, 2015, 'бюджет');
INSERT INTO enrollments VALUES (61, 10, 14, 2024, 'бюджет');
INSERT INTO enrollments VALUES (58, 11, NULL, 2020, 'контракт');
INSERT INTO enrollments VALUES (61, 21, NULL, 2023, 'контракт');
INSERT INTO enrollments VALUES (13, 16, NULL, 2024, 'контракт');
INSERT INTO enrollments VALUES (7, 8, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (68, 21, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (80, 7, NULL, 2020, 'контракт');
INSERT INTO enrollments VALUES (42, 8, NULL, 2017, 'бюджет');
INSERT INTO enrollments VALUES (41, 16, NULL, 2008, 'бюджет');
INSERT INTO enrollments VALUES (17, 4, NULL, 2014, 'контракт');
INSERT INTO enrollments VALUES (67, 12, 9, 2024, 'контракт');
INSERT INTO enrollments VALUES (70, 5, 8, 2016, 'бюджет');
INSERT INTO enrollments VALUES (30, 25, NULL, 2017, 'бюджет');
INSERT INTO enrollments VALUES (95, 3, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (45, 18, 19, 2021, 'контракт');
INSERT INTO enrollments VALUES (30, 18, NULL, 2014, 'бюджет');
INSERT INTO enrollments VALUES (93, 29, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (70, 4, 7, 2021, 'бюджет');
INSERT INTO enrollments VALUES (17, 6, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (32, 14, 9, 2020, 'бюджет');
INSERT INTO enrollments VALUES (32, 18, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (96, 12, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (42, 26, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (53, 23, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (66, 25, NULL, 2019, 'бюджет');
INSERT INTO enrollments VALUES (81, 15, 16, 2021, 'контракт');
INSERT INTO enrollments VALUES (2, 22, NULL, 2014, 'контракт');
INSERT INTO enrollments VALUES (30, 11, 17, 2008, 'контракт');
INSERT INTO enrollments VALUES (18, 8, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (39, 28, NULL, 2021, 'контракт');
INSERT INTO enrollments VALUES (53, 16, NULL, 2008, 'бюджет');
INSERT INTO enrollments VALUES (91, 5, NULL, 2008, 'бюджет');
INSERT INTO enrollments VALUES (49, 2, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (71, 29, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (64, 7, 2, 2016, 'контракт');
INSERT INTO enrollments VALUES (62, 23, 14, 2008, 'контракт');
INSERT INTO enrollments VALUES (57, 25, NULL, 2011, 'контракт');
INSERT INTO enrollments VALUES (37, 21, NULL, 2010, 'контракт');
INSERT INTO enrollments VALUES (93, 27, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (81, 2, NULL, 2014, 'бюджет');
INSERT INTO enrollments VALUES (26, 22, NULL, 2011, 'бюджет');
INSERT INTO enrollments VALUES (81, 18, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (43, 6, 7, 2022, 'контракт');
INSERT INTO enrollments VALUES (18, 3, NULL, 2011, 'бюджет');
INSERT INTO enrollments VALUES (56, 15, NULL, 2020, 'бюджет');
INSERT INTO enrollments VALUES (48, 17, NULL, 2021, 'бюджет');
INSERT INTO enrollments VALUES (50, 19, NULL, 2020, 'бюджет');
INSERT INTO enrollments VALUES (84, 14, NULL, 2024, 'контракт');
INSERT INTO enrollments VALUES (69, 9, NULL, 2014, 'контракт');
INSERT INTO enrollments VALUES (6, 6, 18, 2012, 'контракт');
INSERT INTO enrollments VALUES (57, 20, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (70, 24, NULL, 2009, 'бюджет');
INSERT INTO enrollments VALUES (95, 29, NULL, 2020, 'контракт');
INSERT INTO enrollments VALUES (72, 12, 4, 2015, 'контракт');
INSERT INTO enrollments VALUES (97, 14, NULL, 2017, 'контракт');
INSERT INTO enrollments VALUES (24, 8, 11, 2012, 'контракт');
INSERT INTO enrollments VALUES (35, 26, NULL, 2017, 'бюджет');
INSERT INTO enrollments VALUES (44, 5, 19, 2018, 'контракт');
INSERT INTO enrollments VALUES (56, 25, NULL, 2024, 'бюджет');
INSERT INTO enrollments VALUES (27, 21, 10, 2013, 'контракт');
INSERT INTO enrollments VALUES (36, 7, NULL, 2015, 'бюджет');
INSERT INTO enrollments VALUES (53, 7, NULL, 2010, 'контракт');
INSERT INTO enrollments VALUES (27, 23, NULL, 2013, 'контракт');
INSERT INTO enrollments VALUES (8, 28, NULL, 2008, 'контракт');
INSERT INTO enrollments VALUES (99, 9, 13, 2012, 'контракт');
INSERT INTO enrollments VALUES (31, 6, 11, 2012, 'контракт');
INSERT INTO enrollments VALUES (95, 10, 20, 2017, 'контракт');
INSERT INTO enrollments VALUES (78, 26, NULL, 2019, 'контракт');
INSERT INTO enrollments VALUES (4, 20, 10, 2019, 'контракт');
INSERT INTO enrollments VALUES (63, 20, 19, 2012, 'бюджет');
INSERT INTO enrollments VALUES (50, 5, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (31, 11, 11, 2021, 'контракт');
INSERT INTO enrollments VALUES (22, 20, 9, 2017, 'бюджет');
INSERT INTO enrollments VALUES (39, 23, NULL, 2016, 'контракт');
INSERT INTO enrollments VALUES (5, 12, NULL, 2010, 'бюджет');
INSERT INTO enrollments VALUES (33, 10, NULL, 2015, 'контракт');
INSERT INTO enrollments VALUES (38, 7, 3, 2010, 'контракт');
INSERT INTO enrollments VALUES (7, 7, 14, 2011, 'контракт');
INSERT INTO enrollments VALUES (6, 17, 13, 2012, 'контракт');
INSERT INTO enrollments VALUES (5, 29, 6, 2009, 'бюджет');
INSERT INTO enrollments VALUES (46, 6, NULL, 2008, 'контракт');
INSERT INTO enrollments VALUES (38, 5, 15, 2024, 'бюджет');
INSERT INTO enrollments VALUES (82, 14, NULL, 2018, 'бюджет');
INSERT INTO enrollments VALUES (62, 6, NULL, 2024, 'бюджет');
INSERT INTO enrollments VALUES (68, 23, 8, 2019, 'контракт');

INSERT INTO subjects VALUES (DEFAULT, 'Коммуникативный курс китайского языка', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Бюджетный учет и отчетность', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Бухгалтерский учет в коммерческом банке', 4);
INSERT INTO subjects VALUES (DEFAULT, 'Основы учебной и научно-исследовательской деятельности', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Деньги, кредит, банки', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Общая и промышленная экология Севера', 3);
INSERT INTO subjects VALUES (DEFAULT, 'Экономический анализ в отраслях', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Налоговый учет и отчетность', 2);
INSERT INTO subjects VALUES (DEFAULT, 'Геосоциальное пространство Севера', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Качество и уровень жизни населения циркумполярных регионов мира', 4);
INSERT INTO subjects VALUES (DEFAULT, 'Деловой иностранный язык', 2);
INSERT INTO subjects VALUES (DEFAULT, 'Коммуникативный курс русского языка', 2);
INSERT INTO subjects VALUES (DEFAULT, 'Психология социального взаимодействия', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Геокультурное пространство Арктики', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Менеджмент', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Лабораторный практикум бухгалтерского учета', 2);
INSERT INTO subjects VALUES (DEFAULT, 'Экономика фирмы', 1);
INSERT INTO subjects VALUES (DEFAULT, 'Философия', 4);
INSERT INTO subjects VALUES (DEFAULT, 'Патриотическая литература России', 3);
INSERT INTO subjects VALUES (DEFAULT, 'Риторика', 2);

INSERT INTO studies VALUES (5, 6);
INSERT INTO studies VALUES (5, 1);
INSERT INTO studies VALUES (4, 8);
INSERT INTO studies VALUES (6, 4);
INSERT INTO studies VALUES (17, 20);
INSERT INTO studies VALUES (30, 16);
INSERT INTO studies VALUES (25, 3);
INSERT INTO studies VALUES (8, 8);
INSERT INTO studies VALUES (6, 14);
INSERT INTO studies VALUES (3, 13);
INSERT INTO studies VALUES (13, 7);
INSERT INTO studies VALUES (7, 5);
INSERT INTO studies VALUES (11, 1);
INSERT INTO studies VALUES (19, 6);
INSERT INTO studies VALUES (21, 12);
INSERT INTO studies VALUES (30, 7);
INSERT INTO studies VALUES (27, 9);
INSERT INTO studies VALUES (20, 13);
INSERT INTO studies VALUES (6, 20);
INSERT INTO studies VALUES (14, 17);
INSERT INTO studies VALUES (14, 13);
INSERT INTO studies VALUES (4, 1);
INSERT INTO studies VALUES (29, 9);
INSERT INTO studies VALUES (10, 18);
INSERT INTO studies VALUES (23, 4);
INSERT INTO studies VALUES (5, 16);
INSERT INTO studies VALUES (24, 20);
INSERT INTO studies VALUES (14, 10);
INSERT INTO studies VALUES (11, 5);
INSERT INTO studies VALUES (27, 4);
INSERT INTO studies VALUES (1, 3);
INSERT INTO studies VALUES (4, 3);
INSERT INTO studies VALUES (2, 19);
INSERT INTO studies VALUES (10, 7);
INSERT INTO studies VALUES (17, 16);
INSERT INTO studies VALUES (9, 7);
INSERT INTO studies VALUES (1, 8);
INSERT INTO studies VALUES (5, 12);
INSERT INTO studies VALUES (3, 4);
INSERT INTO studies VALUES (15, 1);
INSERT INTO studies VALUES (16, 1);
INSERT INTO studies VALUES (12, 9);
INSERT INTO studies VALUES (21, 11);
INSERT INTO studies VALUES (26, 19);
INSERT INTO studies VALUES (23, 9);
INSERT INTO studies VALUES (18, 5);
INSERT INTO studies VALUES (6, 19);
INSERT INTO studies VALUES (13, 2);
INSERT INTO studies VALUES (3, 15);
INSERT INTO studies VALUES (6, 9);
INSERT INTO studies VALUES (10, 6);
INSERT INTO studies VALUES (21, 6);
INSERT INTO studies VALUES (4, 10);
INSERT INTO studies VALUES (17, 3);
INSERT INTO studies VALUES (9, 18);
INSERT INTO studies VALUES (18, 18);
INSERT INTO studies VALUES (8, 12);
INSERT INTO studies VALUES (25, 18);
INSERT INTO studies VALUES (16, 15);
INSERT INTO studies VALUES (28, 1);

INSERT INTO teachings VALUES (8, 10);
INSERT INTO teachings VALUES (19, 7);
INSERT INTO teachings VALUES (11, 4);
INSERT INTO teachings VALUES (9, 11);
INSERT INTO teachings VALUES (1, 19);
INSERT INTO teachings VALUES (1, 2);
INSERT INTO teachings VALUES (4, 12);
INSERT INTO teachings VALUES (10, 12);
INSERT INTO teachings VALUES (15, 16);
INSERT INTO teachings VALUES (19, 11);
INSERT INTO teachings VALUES (18, 18);
INSERT INTO teachings VALUES (12, 9);
INSERT INTO teachings VALUES (10, 5);
INSERT INTO teachings VALUES (19, 18);
INSERT INTO teachings VALUES (8, 5);
INSERT INTO teachings VALUES (3, 4);
INSERT INTO teachings VALUES (18, 1);
INSERT INTO teachings VALUES (11, 16);
INSERT INTO teachings VALUES (12, 20);
INSERT INTO teachings VALUES (15, 18);
INSERT INTO teachings VALUES (9, 8);
INSERT INTO teachings VALUES (2, 20);
INSERT INTO teachings VALUES (18, 14);
INSERT INTO teachings VALUES (16, 20);
INSERT INTO teachings VALUES (10, 2);
INSERT INTO teachings VALUES (4, 11);
INSERT INTO teachings VALUES (18, 13);
INSERT INTO teachings VALUES (13, 5);
INSERT INTO teachings VALUES (10, 18);
INSERT INTO teachings VALUES (17, 2);
INSERT INTO teachings VALUES (18, 5);
INSERT INTO teachings VALUES (8, 18);
INSERT INTO teachings VALUES (13, 17);
INSERT INTO teachings VALUES (7, 8);
INSERT INTO teachings VALUES (8, 15);
INSERT INTO teachings VALUES (12, 5);
INSERT INTO teachings VALUES (16, 3);
INSERT INTO teachings VALUES (13, 13);
INSERT INTO teachings VALUES (7, 2);
INSERT INTO teachings VALUES (12, 17);