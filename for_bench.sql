-- 1. Самое распространенное мужское имя в банке
SELECT person_name, COUNT(*) AS cnt
FROM employees
WHERE gender = 'M'
GROUP BY person_name
ORDER BY cnt DESC
LIMIT 1;

-- 2. самое распространенное женское имя в банке
SELECT person_name, COUNT(*) AS cnt
FROM employees
WHERE gender = 'F'
GROUP BY person_name
ORDER BY cnt DESC
LIMIT 1;

-- 3. Кто знает китайский язык?
SELECT *
FROM employees
WHERE lang_with_level LIKE '%Китайский%';

-- 4. выведи распределение по уровню владения английским языком
SELECT 
  value AS level,
  COUNT(*) AS cnt
FROM employees, json_each(lang_with_level)
WHERE json_valid(lang_with_level) 
  AND value LIKE 'Английский /%'
GROUP BY level;

-- 5. покажи какими навыками в среднем обладают сотрудники трайба Core Banking
-- (среднее = наиболее частые навыки)
SELECT value AS skill, COUNT(*) AS freq
FROM employees, json_each(all_skills)
WHERE json_valid(all_skills) 
  AND tribe_name LIKE '%Core Banking%'
GROUP BY skill
ORDER BY freq DESC;

-- 6. покажи какими навыками в среднем обладают сотрудники дивизиона Core Banking
-- (дивизион – ищем 'Блок Core Banking' в full_oshs_name)
SELECT skill, COUNT(*) AS freq
FROM employees, json_each(all_skills) AS skill
WHERE full_oshs_name LIKE '%Блок Core Banking%'
GROUP BY skill
ORDER BY freq DESC;

-- 7. Сотрудники за последние 4 квартала с самыми высокими оценками за результат
-- Предполагаем, что есть оценка fp_res = 'A' и дата отчёта report_date
WITH ranked AS (
  SELECT employee_id, fp_res, report_date,
         DENSE_RANK() OVER (PARTITION BY employee_id ORDER BY fp_res ASC) AS rnk
  FROM employees
  WHERE report_date >= date('now', '-12 months')  -- 4 квартала ~ 12 мес
    AND fp_res = 'A'
)
SELECT DISTINCT employee_id FROM ranked WHERE rnk = 1;

-- 8. Сколько сотрудников закончили МГУ?
SELECT COUNT(*) FROM employees WHERE university_name LIKE '%МГУ%';

-- 9. Покажи сколько сотрудников имеют детей мужского пола в возрасте до 10 лет
SELECT COUNT(*)
FROM employees
WHERE EXISTS (
  SELECT 1 FROM json_each(children_gender) AS g,
              json_each(children_years) AS y
  WHERE g.value = 'M' AND y.value < 10 AND g.id = y.id
);

-- 10. Покажи долю сотрудников, которые имеют детей женского пола в возрасте до 18 лет
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees) AS ratio
FROM employees
WHERE EXISTS (
  SELECT 1 FROM json_each(children_gender) AS g,
              json_each(children_years) AS y
  WHERE g.value = 'F' AND y.value < 18 AND g.id = y.id
);

-- 11. Покажи самый распространенный навык в банке
SELECT skill, COUNT(*) AS cnt
FROM employees, json_each(all_skills) AS skill
GROUP BY skill
ORDER BY cnt DESC
LIMIT 1;

-- 12. покажи самый редкий навык в банке
SELECT skill, COUNT(*) AS cnt
FROM employees, json_each(all_skills) AS skill
GROUP BY skill
ORDER BY cnt ASC
LIMIT 1;

-- 13. покажи долю сотрудников с экономическим образованием специальностью "экономист"
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees) AS ratio
FROM employees
WHERE speciality_name LIKE '%Экономи%';

-- 14. доля сотрудников с карьерным статусом открыт в блоке Риски и Комплаенс
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Блок Риски и Комплаенс%') AS ratio
FROM employees
WHERE career_status = 'Открыт' AND full_oshs_name LIKE '%Блок Риски и Комплаенс%';

-- 15. Выведи распределение по семейному положению сотрудников в банке
SELECT 
  CASE family_status
    WHEN 0 THEN 'Не женат/Не замужем'
    WHEN 1 THEN 'Женат/Замужем'
    WHEN 2 THEN 'Разведён(а)'
    ELSE 'Не указано'
  END AS status,
  COUNT(*) AS cnt
FROM employees
GROUP BY family_status;

-- 16. Сколько всего ключевых сотрудников в банке?
-- (предполагаем, что "ключевые" = career_status = 'Открыт' или грейд > 13)
SELECT COUNT(*) FROM employees WHERE career_status = 'Открыт';

-- 17. покажи долю руководителей в банке
-- (руководители: lead_experience_years > 0 или должность содержит 'руководитель')
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees) AS ratio
FROM employees
WHERE position_name LIKE '%руководитель%' OR lead_experience_years > 0;

-- 18. покажи динамику изменения численности в блоке Риски и Комплаенс в 2025 году
SELECT strftime('%Y-%m', report_date) AS month, COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%Блок Риски и Комплаенс%' AND strftime('%Y', report_date) = '2025'
GROUP BY month
ORDER BY month;

-- 19. самый распространенный возраст сотрудников для каждого грейда
SELECT grade_num, age_y, COUNT(*) AS cnt
FROM employees
GROUP BY grade_num, age_y
HAVING cnt = (
  SELECT MAX(cnt2) FROM (
    SELECT age_y, COUNT(*) AS cnt2 FROM employees e2 WHERE e2.grade_num = e.grade_num GROUP BY age_y
  )
)
ORDER BY grade_num;

-- 20. на сколько сократилась численность в 2025 году по сравнению с 2024?
-- (нужны два среза – например, последняя дата 2024 и последняя дата 2025)
WITH cnt2024 AS (
  SELECT COUNT(*) AS c FROM employees WHERE strftime('%Y', report_date) = '2024'
),
cnt2025 AS (
  SELECT COUNT(*) AS c FROM employees WHERE strftime('%Y', report_date) = '2025'
)
SELECT (SELECT c FROM cnt2024) - (SELECT c FROM cnt2025) AS reduction;

-- 21. сколько стажеров в блоке Core Banking?
SELECT COUNT(*) FROM employees
WHERE full_oshs_name LIKE '%Блок Core Banking%' AND position_name LIKE '%стажер%';

-- 22. сколько сотрудников старше 40 знают английский на высоком уровне?
-- (высокий уровень: C1, C2, продвинутый)
SELECT COUNT(*)
FROM employees
WHERE age_y > 40 AND lang_with_level LIKE '%Английский%'
  AND (lang_with_level LIKE '%C1%' OR lang_with_level LIKE '%C2%' OR lang_with_level LIKE '%продвинутый%');

-- 23. покажи у кого в блоке технологии детей больше чем в среднем по компании
WITH avg_children AS (
  SELECT AVG(child_count) AS avg_c FROM employees
)
SELECT employee_id, child_count
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
  AND child_count > (SELECT avg_c FROM avg_children);

-- 24. Выведи топ 5 самых распространенных навыков блока ЛиК
SELECT skill, COUNT(*) AS freq
FROM employees, json_each(all_skills) AS skill
WHERE full_oshs_name LIKE '%Блок ЛиК%'  -- ЛиК = Лизинг и Корпоративное?
GROUP BY skill
ORDER BY freq DESC
LIMIT 5;

-- 25. выведи топ 5 навыков самых возрастных сотрудников
-- (топ-5 навыков среди 10% самых старших)
WITH oldest AS (
  SELECT employee_id FROM employees ORDER BY age_y DESC LIMIT (SELECT COUNT(*)*0.1 FROM employees)
)
SELECT skill, COUNT(*) AS freq
FROM oldest o JOIN employees e ON o.employee_id = e.employee_id,
     json_each(e.all_skills) AS skill
GROUP BY skill
ORDER BY freq DESC
LIMIT 5;

-- 26. выведи долю сотрудников накопивших более 28 дней отпуска
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees) AS ratio
FROM employees
WHERE vac_days > 28;

-- 27. покажи основные достижения сотрудников трайба Core Banking
-- (извлекаем из achievement_desc)
SELECT employee_id, achievement_desc
FROM employees
WHERE tribe_name LIKE '%Core Banking%' AND achievement_desc IS NOT NULL;

-- 28. покажи долю сотрудников с процентом выполнения целей 75% в 4 квартале 2025
-- (mean_value_completion = 0.75)
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE strftime('%Y', report_date) = '2025') AS ratio
FROM employees
WHERE mean_value_completion = 0.75 AND strftime('%Y', report_date) = '2025'
  AND strftime('%m', report_date) BETWEEN '10' AND '12';

-- 29. какой средний возраст сотрудников с грейдом выше 12 в блоке технологии и блоке риски?
SELECT AVG(age_y) AS avg_age
FROM employees
WHERE grade_num > 12
  AND (full_oshs_name LIKE '%Блок Технологии%' OR full_oshs_name LIKE '%Блок Риски%');

-- 30. Общая численность сотрудников банка кроме Московского банка
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name NOT LIKE '%Московский банк%';

-- 31. Сколько руководителей в подразделениях Среднерусского и Волго-Вятского банков
SELECT COUNT(*)
FROM employees
WHERE (full_oshs_name LIKE '%Среднерусский банк%' OR full_oshs_name LIKE '%Волго-Вятский банк%')
  AND (position_name LIKE '%руководитель%' OR lead_experience_years > 0);

-- 32. Кол-во сотрудников говорящих на французском
SELECT COUNT(*) FROM employees WHERE lang_with_level LIKE '%Французский%';

-- 33. Кол-во мужчин старше 50 в компании, кроме Сибирского и Уральского банков
SELECT COUNT(*)
FROM employees
WHERE gender = 'M' AND age_y > 50
  AND full_oshs_name NOT LIKE '%Сибирский банк%'
  AND full_oshs_name NOT LIKE '%Уральский банк%';

-- 34. Разбивка по стажам и по грейдам в блоке риски
SELECT sber_los_cnt_days AS seniority_days, grade_num, COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%Блок Риски%'
GROUP BY sber_los_cnt_days, grade_num;

-- 35. Доля поколения X по блоку КИБ и Розничные клиенты и сеть продаж
-- (поколение X = 1965-1980, возраст в 2025: 45-60)
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%КИБ%' OR full_oshs_name LIKE '%Розничные клиенты%') AS ratio
FROM employees
WHERE (full_oshs_name LIKE '%КИБ%' OR full_oshs_name LIKE '%Розничные клиенты%')
  AND age_y BETWEEN 45 AND 60;

-- 36. Число женатых сотрудников по блоки ЛиК, за исключением Поволжского банка
SELECT COUNT(*)
FROM employees
WHERE family_status = 1
  AND full_oshs_name LIKE '%Блок ЛиК%'
  AND full_oshs_name NOT LIKE '%Поволжский банк%';

-- 37. У скольких сотрудников ВСП Среднерусского банка есть больше 2 навыков?
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Среднерусский банк%' AND full_oshs_name LIKE '%ВСП%'
  AND (json_array_length(all_skills) > 2);

-- 38. Штатная численность сотрудников ВСП без учета Байкальского банка
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%ВСП%'
  AND full_oshs_name NOT LIKE '%Байкальский банк%';

-- 39. Обученность сотрудников КИЦ Байкальского банка
-- (обученность = количество навыков на человека)
SELECT employee_id, json_array_length(all_skills) AS skills_count
FROM employees
WHERE full_oshs_name LIKE '%КИЦ%' AND full_oshs_name LIKE '%Байкальский банк%';

-- 40. Процент работающих сотрудников КИЦ кроме Юго-Западного банка
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%КИЦ%') AS ratio
FROM employees
WHERE full_oshs_name LIKE '%КИЦ%'
  AND full_oshs_name NOT LIKE '%Юго-Западный банк%'
  AND is_parental_leave = 0;  -- работающие = не в декрете

-- 41. Доля разведенных в ГОСБах Уральского банка без учета Чувашского и Пермского отделения
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Уральский банк%' AND full_oshs_name LIKE '%ГОСБ%') AS ratio
FROM employees
WHERE family_status = 2
  AND full_oshs_name LIKE '%Уральский банк%' AND full_oshs_name LIKE '%ГОСБ%'
  AND full_oshs_name NOT LIKE '%Чувашское%' AND full_oshs_name NOT LIKE '%Пермское%';

-- 42. Численность всех ГОСБов Сбера
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%ГОСБ%';

-- 43. Средние возраста сотрудников по всем ГОСБам, кроме МБ
SELECT AVG(age_y) AS avg_age
FROM employees
WHERE full_oshs_name LIKE '%ГОСБ%' AND full_oshs_name NOT LIKE '%Московский банк%';

-- 44. Выведи табельные номера всех женщин с 2 и более детьми
SELECT employee_id
FROM employees
WHERE gender = 'F' AND child_count >= 2;

-- 45. Самая популярная фамилия в блоке Риски
SELECT person_surname, COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%Блок Риски%'
GROUP BY person_surname
ORDER BY cnt DESC
LIMIT 1;

-- 46. Топ-5 самых молодых сотрудников в блоке технологии
SELECT employee_id, person_name, person_surname, age_y
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
ORDER BY age_y ASC
LIMIT 5;

-- 47. Сколько сотрудников выше 11 грейда в команде Ивановой Марии?
-- (предполагаем, что Иванова Мария – руководитель, её команда = те, у кого lid_1_lvl_i_pernr = её employee_id)
SELECT COUNT(*)
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name = 'Мария' AND person_surname = 'Иванова')
  AND grade_num > 11;

-- 48. Самый высокий грейд сотрудника младше 30 лет
SELECT MAX(grade_num) FROM employees WHERE age_y < 30;

-- 49. Покажи распределение возрастов по каждому грейду
SELECT grade_num, age_y, COUNT(*) AS cnt
FROM employees
GROUP BY grade_num, age_y
ORDER BY grade_num, age_y;

-- 50. Список всех сотрудников моей команды, кто владеет 2 и более иностранными языками
-- (иностранные = всё кроме русского, считаем элементы в lang_with_level)
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT e.employee_id, e.person_name, e.person_surname
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
  AND (json_array_length(lang_with_level) >= 2);

-- 51. Сотрудники какого грейда чаще всего получали повышенные оценки за результативность в прошлом году?
-- (повышенные = fp_res = 'A' или 'B')
SELECT grade_num, COUNT(*) AS cnt
FROM employees
WHERE fp_res IN ('A', 'B') AND strftime('%Y', report_date) = strftime('%Y', 'now', '-1 year')
GROUP BY grade_num
ORDER BY cnt DESC
LIMIT 1;

-- 52. Доля женщин старше 45 лет на адаптации
-- (на адаптации = is_on_trial = 1)
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE gender='F' AND age_y>45) AS ratio
FROM employees
WHERE gender='F' AND age_y>45 AND is_on_trial=1;

-- 53. На сколько изменилась численность блока риски за год?
WITH cnt_prev AS (
  SELECT COUNT(*) AS c FROM employees WHERE full_oshs_name LIKE '%Блок Риски%' AND report_date = date('now', '-1 year')
),
cnt_curr AS (
  SELECT COUNT(*) AS c FROM employees WHERE full_oshs_name LIKE '%Блок Риски%' AND report_date = date('now')
)
SELECT (SELECT c FROM cnt_curr) - (SELECT c FROM cnt_prev) AS delta;

-- 54. Сравни процент женатых сотрудников моей команды по месяцам с сентября прошлого года (current_user_id: 10021469)
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = 10021469
)
SELECT strftime('%Y-%m', report_date) AS month,
       1.0 * SUM(CASE WHEN family_status=1 THEN 1 ELSE 0 END) / COUNT(*) AS married_ratio
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
  AND report_date >= date('now', '-1 year', 'start of month', '+8 months') -- с сентября
GROUP BY month
ORDER BY month;

-- 55. в какой команде больше всего невыполненных целей в 3 квартале прошлого года?
-- (not_completed_goals > 0)
SELECT team_name, SUM(not_completed_goals) AS total_not_completed
FROM employees
WHERE strftime('%Y', report_date) = strftime('%Y', 'now', '-1 year')
  AND strftime('%m', report_date) BETWEEN '07' AND '09'
GROUP BY team_name
ORDER BY total_not_completed DESC
LIMIT 1;

-- 56. Какой средний возраст детей сотрудников блоке Т
SELECT AVG(y.value) AS avg_child_age
FROM employees, json_each(children_years) AS y
WHERE full_oshs_name LIKE '%Блок Т%' OR full_oshs_name LIKE '%Блок Технологии%';

-- 57. Какой % сотрудников с детьми находится в декрете?
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE child_count > 0) AS ratio
FROM employees
WHERE child_count > 0 AND is_parental_leave = 1;

-- 58. Покажи распределние по грейдам в трайбе Core Banking
SELECT grade_num, COUNT(*) AS cnt
FROM employees
WHERE tribe_name LIKE '%Core Banking%'
GROUP BY grade_num
ORDER BY grade_num;

-- 59. Покажи кол-во сотрудников в трайбе уведомления
SELECT COUNT(*)
FROM employees
WHERE tribe_name LIKE '%уведомления%' OR tribe_name LIKE '%Уведомления%';

-- 60. Покажи кол-во сотрудников в трайбе технологогии маркетинга
SELECT COUNT(*)
FROM employees
WHERE tribe_name LIKE '%технологии маркетинга%' OR tribe_name LIKE '%Маркетинга%';

-- 61. сколько мужчин старше 35 лет в кластере аналитика проф.пользователя
SELECT COUNT(*)
FROM employees
WHERE gender='M' AND age_y>35
  AND cluster_name LIKE '%аналитика проф.пользователя%';

-- 62. Сколько сотрудников в головных отделениях на правах филиалов волговятского банка
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Волго-Вятский банк%'
  AND full_oshs_name LIKE '%головное отделение%';

-- 63. Сколько сотрудников в аппарате банка среднерусского банка
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Среднерусский банк%' AND full_oshs_name LIKE '%аппарат банка%';

-- 64. Сколько сотрудников в моей команде знают итальянский язык?
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
  AND e.lang_with_level LIKE '%Итальянский%';

-- 65. Сколько сотрудников в блоке "Технологии" знают итальянский язык?
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
  AND lang_with_level LIKE '%Итальянский%';

-- 66. Покажи какими иностранными языками владеют сотрудники банка
SELECT DISTINCT json_extract(value, '$') AS language
FROM employees, json_each(lang_with_level)
WHERE value NOT LIKE '%Русский%';

-- 67. Сколько сотрудников в декрете?
SELECT COUNT(*) FROM employees WHERE is_parental_leave = 1;

-- 68. сколько девушек у меня в команде
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.gender = 'F';

-- 69. Выведи имя моего начальника
SELECT person_name, person_surname
FROM employees
WHERE employee_id = (SELECT lid_1_lvl_i_pernr FROM employees WHERE employee_id = :current_user_id);

-- 70. Сколько человек в моей команде?
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name;

-- 71. Сколько человек в команде Иванова Ивана Ивановича?
SELECT COUNT(*)
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов' AND person_patronimics='Иванович');

-- 72. Сколько клиентских менеджеров на испытательном сроке?
SELECT COUNT(*)
FROM employees
WHERE position_name LIKE '%клиентский менеджер%' AND is_on_trial = 1;

-- 73. Выведи сотрудников моложе 30 лет со стажем более 5 лет
-- (стаж = sber_los_cnt_days / 365)
SELECT *
FROM employees
WHERE age_y < 30 AND (sber_los_cnt_days / 365.0) > 5;

-- 74. Выведи почту моего руководителя
SELECT wrk_email
FROM employees
WHERE employee_id = (SELECT lid_1_lvl_i_pernr FROM employees WHERE employee_id = :current_user_id);

-- 75. Какие подразделения имеют сотрудников на испытательном сроке?
SELECT DISTINCT full_oshs_name
FROM employees
WHERE is_on_trial = 1;

-- 76. Сколько команд имеют численность более 15 человек выведи число?
SELECT COUNT(*) AS teams_with_more_than_15
FROM (
    SELECT team_name
    FROM employees
    WHERE team_name IS NOT NULL
    GROUP BY team_name
    HAVING COUNT(*) > 15
) AS large_teams;

-- 77. В каком отделе работает Иванова Мария Ивановна?
SELECT full_oshs_name
FROM employees
WHERE person_name='Мария' AND person_surname='Иванова' AND person_patronimics='Ивановна';

-- 78. Какое распределение сотрудников по полу в кампании?
SELECT gender, COUNT(*) AS cnt FROM employees GROUP BY gender;

-- 79. Какие сотрудники имеют Оценку за результативность выше чем C
-- (выше C = A или B)
SELECT * FROM employees WHERE fp_res IN ('A', 'B');

-- 80. Сколько сотрудников с грейдом выше 13 имеют оценку за результативность ниже 3
-- (оценка ниже 3 – предположим fp_res = 'D' или 'E')
SELECT COUNT(*)
FROM employees
WHERE grade_num > 13 AND fp_res IN ('D', 'E');

-- 81. Как называется команда Ивана Иванова?
SELECT team_name
FROM employees
WHERE person_name='Иван' AND person_surname='Иванов'
LIMIT 1;

-- 82. Какой средний возраст сотрудников женщин в декрете
SELECT AVG(age_y) FROM employees WHERE gender='F' AND is_parental_leave=1;

-- 83. Кавова разница между средним возрасом мужчин и женщин в кампании
SELECT AVG(CASE WHEN gender='M' THEN age_y END) - AVG(CASE WHEN gender='F' THEN age_y END) AS diff
FROM employees;

-- 84. Сколько женщин старше 50 имеют грейд выше чем средний грейд по банку
SELECT COUNT(*)
FROM employees
WHERE gender='F' AND age_y > 50
  AND grade_num > (SELECT AVG(grade_num) FROM employees);

-- 85. Когда у меня в последний раз повышали зарплату?
SELECT date_since_salary_change_last
FROM employees
WHERE employee_id = :current_user_id;

-- 86. Какие у меня есть навыки
SELECT all_skills FROM employees WHERE employee_id = :current_user_id;

-- 87. Какие навыки самые распространные в банке, выведи топ-5
SELECT skill, COUNT(*) AS cnt
FROM employees, json_each(all_skills) AS skill
GROUP BY skill
ORDER BY cnt DESC
LIMIT 5;

-- 88. Кому повышали зарплату раньше чем мне
SELECT employee_id, date_since_salary_change_last
FROM employees
WHERE date_since_salary_change_last < (SELECT date_since_salary_change_last FROM employees WHERE employee_id = :current_user_id);

-- 89. Сколько разведенных мужчин имеют больше 2 детей?
SELECT COUNT(*)
FROM employees
WHERE gender='M' AND family_status=2 AND child_count > 2;

-- 90. Выведи распределение грейдов по интервалам возраста для сотрудников кампании
SELECT 
  CASE 
    WHEN age_y < 25 THEN '<25'
    WHEN age_y BETWEEN 25 AND 35 THEN '25-35'
    WHEN age_y BETWEEN 36 AND 45 THEN '36-45'
    WHEN age_y BETWEEN 46 AND 55 THEN '46-55'
    ELSE '55+'
  END AS age_group,
  grade_num,
  COUNT(*) AS cnt
FROM employees
GROUP BY age_group, grade_num
ORDER BY age_group, grade_num;

-- 91. Выведи первого в лексикографическом порядке сотрудника для каждого грейда
-- (лексикографический порядок по полному имени)
SELECT grade_num, MIN(person_surname || ' ' || person_name) AS first_employee
FROM employees
GROUP BY grade_num;

-- 92. выведи топ-10 сотрудников по наибольшему количеству владения иностранных языков
SELECT employee_id, person_name, person_surname, json_array_length(lang_with_level) AS lang_count
FROM employees
ORDER BY lang_count DESC
LIMIT 10;

-- 93. Сколько людей в моей команде моего руководителя получили оценку B
WITH manager_team AS (
  SELECT team_name FROM employees WHERE employee_id = (SELECT lid_1_lvl_i_pernr FROM employees WHERE employee_id = :current_user_id)
)
SELECT COUNT(*)
FROM employees e, manager_team mt
WHERE e.team_name = mt.team_name AND e.fp_res = 'B';

-- 94. Сравни доли сотрудников 10 и отдельно 9 грейда с оценкой выше C(3)
-- (выше C = A,B)
SELECT 
  grade_num,
  1.0 * SUM(CASE WHEN fp_res IN ('A','B') THEN 1 ELSE 0 END) / COUNT(*) AS ratio_above_C
FROM employees
WHERE grade_num IN (9,10)
GROUP BY grade_num;

-- 95. Какие навыки самые распространные в банке у сотрудников 11 грейда, выведи топ-5
SELECT skill, COUNT(*) AS cnt
FROM employees, json_each(all_skills) AS skill
WHERE grade_num = 11
GROUP BY skill
ORDER BY cnt DESC
LIMIT 5;

-- 96. Выведи все навыки сотрудников, у которых руководитель Иванов Иван Иванович
SELECT DISTINCT skill
FROM employees e, json_each(e.all_skills) AS skill
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов' AND person_patronimics='Иванович');

-- 97. Какие навыки самые редкие в банке у сотрудников 11 грейда старше 50 лет, выведи топ-5
SELECT skill, COUNT(*) AS cnt
FROM employees, json_each(all_skills) AS skill
WHERE grade_num = 11 AND age_y > 50
GROUP BY skill
ORDER BY cnt ASC
LIMIT 5;

-- 98. Выведи количество сотрудников у которых есть навык 'Data science'
SELECT COUNT(*)
FROM employees
WHERE all_skills LIKE '%Data science%';

-- 99. средний стаж сотрудников в годах с оценками A и B по полу
SELECT gender, AVG(sber_los_cnt_days / 365.0) AS avg_seniority_years
FROM employees
WHERE fp_res IN ('A', 'B')
GROUP BY gender;

-- 100. сколько сотрудников имеют навыки связанные с работой с данными
-- (навыки: Data science, SQL, Python, Аналитика и т.п.)
SELECT COUNT(*)
FROM employees
WHERE all_skills LIKE '%Data%' OR all_skills LIKE '%SQL%' OR all_skills LIKE '%Python%' OR all_skills LIKE '%аналитик%';

-- 101. Сколько сотрудников имеют навык Python в моей команде
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.all_skills LIKE '%Python%';

-- 102. какова доля женщин в блоке Сервисы
SELECT 1.0 * SUM(CASE WHEN gender='F' THEN 1 ELSE 0 END) / COUNT(*) AS ratio
FROM employees
WHERE full_oshs_name LIKE '%Блок Сервисы%';

-- 103. сколько сотрудников блока Риски имеют навык Java
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Блок Риски%' AND all_skills LIKE '%Java%';

-- 104. сравни средний возраст в Дальневосточном банке и Московском банке
SELECT 
  AVG(CASE WHEN full_oshs_name LIKE '%Дальневосточный банк%' THEN age_y END) AS far_east_avg,
  AVG(CASE WHEN full_oshs_name LIKE '%Московский банк%' THEN age_y END) AS moscow_avg
FROM employees;

-- 105. сравни средний возраст женщин в Дальневосточном банке и Московском банке
SELECT 
  AVG(CASE WHEN full_oshs_name LIKE '%Дальневосточный банк%' AND gender='F' THEN age_y END) AS far_east_f_avg,
  AVG(CASE WHEN full_oshs_name LIKE '%Московский банк%' AND gender='F' THEN age_y END) AS moscow_f_avg
FROM employees;

-- 106. дай мне распределение людей по возрастным интервалам в блоке Сервисы
SELECT 
  CASE 
    WHEN age_y < 25 THEN '<25'
    WHEN age_y BETWEEN 25 AND 35 THEN '25-35'
    WHEN age_y BETWEEN 36 AND 45 THEN '36-45'
    WHEN age_y BETWEEN 46 AND 55 THEN '46-55'
    ELSE '55+'
  END AS age_group,
  COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%Блок Сервисы%'
GROUP BY age_group;

-- 107. Какой процент сотрудников состоит в браке, разведен или холост?
SELECT 
  1.0 * SUM(CASE WHEN family_status=1 THEN 1 ELSE 0 END) / COUNT(*) AS married_pct,
  1.0 * SUM(CASE WHEN family_status=2 THEN 1 ELSE 0 END) / COUNT(*) AS divorced_pct,
  1.0 * SUM(CASE WHEN family_status=0 THEN 1 ELSE 0 END) / COUNT(*) AS single_pct
FROM employees;

-- 108. Сколько в среднем детей у сотрудников?
SELECT AVG(child_count) FROM employees;

-- 109. Есть ли связь между грейдом и стажем работы?
-- (корреляция Пирсона, приближённо)
SELECT (AVG(grade_num * sber_los_cnt_days) - AVG(grade_num)*AVG(sber_los_cnt_days)) /
       (SQRT(AVG(grade_num*grade_num) - AVG(grade_num)*AVG(grade_num)) *
        SQRT(AVG(sber_los_cnt_days*sber_los_cnt_days) - AVG(sber_los_cnt_days)*AVG(sber_los_cnt_days))) AS correlation
FROM employees;

-- 110. Есть ли корреляция между оценкой результативности и оценкой ценностей?
-- (преобразуем буквы в числа A=5,B=4,C=3,D=2)
WITH mapped AS (
  SELECT 
    CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END AS res_num,
    CASE fp_comp WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END AS comp_num
  FROM employees
)
SELECT (AVG(res_num * comp_num) - AVG(res_num)*AVG(comp_num)) /
       (SQRT(AVG(res_num*res_num) - AVG(res_num)*AVG(res_num)) *
        SQRT(AVG(comp_num*comp_num) - AVG(comp_num)*AVG(comp_num))) AS correlation
FROM mapped;

-- 111. Сколько подчиненных у Иванова Ивана и Смирнова Ивана?
SELECT 
  (SELECT COUNT(*) FROM employees WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')) AS ivanov_sub,
  (SELECT COUNT(*) FROM employees WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Смирнов')) AS smirnov_sub;

-- 112. Пришли почту сотрудника, у которого стаж 5 лет и он мужчина
SELECT wrk_email
FROM employees
WHERE (sber_los_cnt_days / 365.0) = 5 AND gender = 'M'
LIMIT 1;

-- 113. Какой грейд самый распространенный среди сотрудников?
SELECT grade_num, COUNT(*) AS cnt
FROM employees
GROUP BY grade_num
ORDER BY cnt DESC
LIMIT 1;

-- 114. Есть ли сотрудники в моей команде, у которых оценка за результативность на 2 балла выше или ниже, чем у меня
-- (преобразуем буквы в числа)
WITH my_grade AS (
  SELECT 
    CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END AS my_num
  FROM employees WHERE employee_id = :current_user_id
)
SELECT e.employee_id, e.fp_res
FROM employees e, my_team mt, my_grade mg
WHERE e.team_name = mt.team_name
  AND ABS(CASE e.fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END - mg.my_num) = 2;

-- 115. Сравни средний возраст в блоках Core Banking, Риски, Сервисы
SELECT 
  AVG(CASE WHEN full_oshs_name LIKE '%Блок Core Banking%' THEN age_y END) AS Core Banking_avg,
  AVG(CASE WHEN full_oshs_name LIKE '%Блок Риски%' THEN age_y END) AS risk_avg,
  AVG(CASE WHEN full_oshs_name LIKE '%Блок Сервисы%' THEN age_y END) AS service_avg
FROM employees;

-- 116. Сколько разведенных мужчин и женщин в банке?
SELECT gender, COUNT(*) AS cnt
FROM employees
WHERE family_status = 2
GROUP BY gender;

-- 117. Кто имеет больше всего отпускных дней в моей команде?
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT e.employee_id, e.person_name, e.person_surname, e.vac_days
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
ORDER BY e.vac_days DESC
LIMIT 1;

-- 118. На сколько средняя оценка за результативность в моей команде отличается от средней по всему банку
-- (переводим буквы в числа)
WITH team_avg AS (
  SELECT AVG(CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END) AS team_avg
  FROM employees
  WHERE team_name = (SELECT team_name FROM employees WHERE employee_id = :current_user_id)
),
bank_avg AS (
  SELECT AVG(CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END) AS bank_avg
  FROM employees
)
SELECT team_avg - bank_avg AS diff FROM team_avg, bank_avg;

-- 119. в каких командах самый большой разрыв между максимальным и минимальным грейдом
SELECT team_name, MAX(grade_num) - MIN(grade_num) AS grade_gap
FROM employees
GROUP BY team_name
ORDER BY grade_gap DESC
LIMIT 1;

-- 120. есть ли разница в среднем количестве дней после повышения между мужчинами и женщинами
SELECT gender, AVG(date_since_salary_change_last) AS avg_days_since_raise
FROM employees
GROUP BY gender;

-- 121. Сколько людей имеют разный семейный статус - холостой, сравни с разведенными
SELECT 
  SUM(CASE WHEN family_status=0 THEN 1 ELSE 0 END) AS single,
  SUM(CASE WHEN family_status=2 THEN 1 ELSE 0 END) AS divorced
FROM employees;

-- 122. Какой средний возраст у сотрудников, которые получили повышение зарплаты за последние 90 дней?
SELECT AVG(age_y)
FROM employees
WHERE date_since_salary_change_last <= 90;

-- 123. Сколько уникальных команд в банке у Иванова Ивана
-- (Иванов Иван как руководитель)
SELECT COUNT(DISTINCT team_name)
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов');

-- 124. Есть ли команды, где больше 30% сотрудников на испытательном сроке?
SELECT team_name, 1.0 * SUM(is_on_trial) / COUNT(*) AS trial_ratio
FROM employees
GROUP BY team_name
HAVING trial_ratio > 0.3;

-- 125. Сравни численность разведенных сотрудников блоке Core Banking и блоке Риски
SELECT 
  SUM(CASE WHEN full_oshs_name LIKE '%Блок Core Banking%' AND family_status=2 THEN 1 ELSE 0 END) AS Core Banking_divorced,
  SUM(CASE WHEN full_oshs_name LIKE '%Блок Риски%' AND family_status=2 THEN 1 ELSE 0 END) AS risk_divorced
FROM employees;

-- 126. Как распределены сотрудники по полу (мужчины/женщины)
SELECT gender, COUNT(*) FROM employees GROUP BY gender;

-- 127. Можно ли выделить группу сотрудников, у которых более 2000 дней стажа, но при этом грейд ниже среднего?
SELECT employee_id, sber_los_cnt_days, grade_num
FROM employees
WHERE sber_los_cnt_days > 2000
  AND grade_num < (SELECT AVG(grade_num) FROM employees);

-- 128. Какой % сотрудников в возрасте 40+ лет имеет детей?
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE age_y >= 40) AS ratio
FROM employees
WHERE age_y >= 40 AND child_count > 0;

-- 129. Какое распределение семейного статуса среди сотрудников с 12-13 грейдом?
SELECT family_status, COUNT(*) AS cnt
FROM employees
WHERE grade_num IN (12,13)
GROUP BY family_status;

-- 130. Сколько сотрудников мужчин в декрете?
SELECT COUNT(*) FROM employees WHERE gender='M' AND is_parental_leave=1;

-- 131. Выведи команды, где больше 10% сотрудников на испытательном сроке?
SELECT team_name, 1.0 * SUM(is_on_trial) / COUNT(*) AS trial_ratio
FROM employees
GROUP BY team_name
HAVING trial_ratio > 0.3;

-- 132. В каких командах самый высокий средний возраст сотрудников?
SELECT team_name, AVG(age_y) AS avg_age
FROM employees
GROUP BY team_name
ORDER BY avg_age DESC
LIMIT 1;

-- 133. Какой % сотрудников с детьми находится в декрете? (повтор вопроса 57)
SELECT 1.0 * COUNT(*) / (SELECT COUNT(*) FROM employees WHERE child_count > 0) AS ratio
FROM employees
WHERE child_count > 0 AND is_parental_leave = 1;

-- 134. в каких командах самый большой разрыв между максимальным и минимальным грейду (повтор 119)
SELECT team_name, MAX(grade_num) - MIN(grade_num) AS grade_gap
FROM employees
GROUP BY team_name
ORDER BY grade_gap DESC
LIMIT 1;

-- 135. сравни численности блоков Риски и Core Banking и Сервисы, выведи их названия
SELECT 'Блок Риски' AS block_name, COUNT(*) AS cnt FROM employees WHERE full_oshs_name LIKE '%Блок Риски%'
UNION ALL
SELECT 'Блок Core Banking', COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Блок Core Banking%'
UNION ALL
SELECT 'Блок Сервисы', COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Блок Сервисы%';

-- 136. Сколько молодых девушек у нас в центре молодых спецов и выведи название подразделения
-- (молодые = возраст < 30)
SELECT full_oshs_name, COUNT(*) AS cnt
FROM employees
WHERE gender='F' AND age_y < 30 AND full_oshs_name LIKE '%центр молодых спецов%'
GROUP BY full_oshs_name;

-- 137. Выведи распределение сотрудников по грейдам в сберспасибо и сравни его со складской логистикой
SELECT 'СберСпасибо' AS dept, grade_num, COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%СберСпасибо%'
GROUP BY grade_num
UNION ALL
SELECT 'Складская логистика', grade_num, COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%складская логистика%'
GROUP BY grade_num;

-- 138. сколько девушек моложе 40 в моем команде и выведи название моей команды
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT mt.team_name, COUNT(*) AS young_females
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.gender='F' AND e.age_y < 40
GROUP BY mt.team_name;

-- 139. выведи распредления языков которые знают сотрудники
SELECT json_extract(value, '$') AS language, COUNT(*) AS cnt
FROM employees, json_each(lang_with_level)
GROUP BY language
ORDER BY cnt DESC;

-- 140. сколько сотрудников с повышенной оценкой (оценка A или B)
SELECT COUNT(*) FROM employees WHERE fp_res IN ('A','B');

-- 141. выведи распределение оценок за результативность по грейдам
SELECT grade_num, fp_res, COUNT(*) AS cnt
FROM employees
GROUP BY grade_num, fp_res
ORDER BY grade_num, fp_res;

-- 142. выведи возраст детей Горшкова Захара который 12 грейда
SELECT children_years
FROM employees
WHERE person_name='Захар' AND person_surname='Горшков' AND grade_num=12;

-- 143. сколько людей в дивизионе Core Banking (дивизион = блок)
SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Блок Core Banking%';

-- 144. show name and surname of women in my team with grade higher than 10
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT person_name, person_surname
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.gender='F' AND e.grade_num > 10;

-- 145. сколько сотрудников в блоке сервисы?
SELECT COUNT(*) FROM employees WHERE full_oshs_name LIKE '%Блок Сервисы%';

-- 146. выведи самого молодого сотрудника с самым высоким грейдом
-- (сначала отбираем максимальный грейд, затем среди них минимальный возраст)
SELECT *
FROM employees
WHERE grade_num = (SELECT MAX(grade_num) FROM employees)
ORDER BY age_y ASC
LIMIT 1;

-- 147. Сколько человек в моей команде получили оценку B
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.fp_res = 'B';

-- 148. Покажи распределние по грейдам в команде Иванова Ивана
SELECT grade_num, COUNT(*) AS cnt
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
GROUP BY grade_num;

-- 149. Покажи кол-во сотрудников в команде Иванова Ивана
SELECT COUNT(*)
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов');

-- 150. Сколько сотрудников в банке знают итальянский язык?
SELECT COUNT(*) FROM employees WHERE lang_with_level LIKE '%Итальянский%';

-- 151. а сколько команд с численность более 20 человек?
SELECT COUNT(DISTINCT team_name)
FROM employees
GROUP BY team_name
HAVING COUNT(*) > 20;

-- 152. Выведи все навыки сотрудников, у которых руководитель Иванов Иван Иванович (повтор 96)
SELECT DISTINCT skill
FROM employees e, json_each(e.all_skills) AS skill
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов' AND person_patronimics='Иванович');

-- 153. покажи распределение количества детей у сотрудников
SELECT child_count, COUNT(*) AS cnt
FROM employees
GROUP BY child_count
ORDER BY child_count;

-- 154. Есть ли корреляция между оценкой результативности и оценкой ценностей? (повтор 110)
-- (тот же запрос)
WITH mapped AS (
  SELECT 
    CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END AS res_num,
    CASE fp_comp WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END AS comp_num
  FROM employees
)
SELECT (AVG(res_num * comp_num) - AVG(res_num)*AVG(comp_num)) /
       (SQRT(AVG(res_num*res_num) - AVG(res_num)*AVG(res_num)) *
        SQRT(AVG(comp_num*comp_num) - AVG(comp_num)*AVG(comp_num))) AS correlation
FROM mapped;

-- 155. Распредели сотрудников трайба Core Banking по остатку отпускных дней
SELECT vac_days, COUNT(*) AS cnt
FROM employees
WHERE tribe_name LIKE '%Core Banking%'
GROUP BY vac_days
ORDER BY vac_days;

-- 156. сколько подчиненных у Иванова Ивана (повтор 111 часть)
SELECT COUNT(*)
FROM employees
WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов');

-- 157. Сколько сотрудников в центре Core Banking?
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Центр Core Banking%' OR cluster_name LIKE '%Центр Core Banking%';

-- 158. Приведи названия всех команд трайба Core Banking
SELECT DISTINCT team_name
FROM employees
WHERE tribe_name LIKE '%Core Banking%';

-- 159. отсортируй все команды в блоке Core Banking по возрастанию
SELECT DISTINCT team_name
FROM employees
WHERE full_oshs_name LIKE '%Блок Core Banking%'
ORDER BY team_name ASC;

-- 160. приведи список мужчин старше 30 и их цели из трайба Ядро-Core Banking
SELECT e.person_name, e.person_surname, e.all_goals_desc
FROM employees e
WHERE e.gender='M' AND e.age_y > 30 AND e.tribe_name LIKE '%Ядро-Core Banking%';

-- 161. у кого самый большой стаж в кластере Core Banking
SELECT employee_id, person_name, person_surname, sber_los_cnt_days
FROM employees
WHERE cluster_name LIKE '%Core Banking%'
ORDER BY sber_los_cnt_days DESC
LIMIT 1;

-- 162. в какой команде (не null) больше всего сотрудников в отпуске
-- (в отпуске = vac_days > 0 или есть признак is_on_vacation? используем vac_days)
SELECT team_name, COUNT(*) AS cnt
FROM employees
WHERE vac_days > 0
  AND team_name IS NOT NULL
GROUP BY team_name
ORDER BY cnt DESC
LIMIT 1;

-- 163. приведи график распределения мужчин и женщин в Блоке Розничный Бизнес и кластере верификация
SELECT 
  'Блок Розничный Бизнес' AS division,
  gender,
  COUNT(*) AS cnt
FROM employees
WHERE full_oshs_name LIKE '%Розничный Бизнес%'
GROUP BY gender
UNION ALL
SELECT 
  'Кластер Core Banking',
  gender,
  COUNT(*)
FROM employees
WHERE cluster_name LIKE '%Верификация%'
GROUP BY gender;

-- 164. Определи количество команд с средней долей выполнения целей выше чем 50 %
SELECT COUNT(DISTINCT team_name)
FROM employees
GROUP BY team_name
HAVING AVG(mean_value_completion) > 0.5;

-- 165. сколько девушек у меня в команде? (повтор 68)
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT COUNT(*)
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name AND e.gender = 'F';

-- 166. сколько девушек в трайбе Core Banking?
SELECT COUNT(*)
FROM employees
WHERE tribe_name LIKE '%Core Banking%' AND gender='F';

-- 167. сколько девушек в департаменте Core Banking?
SELECT COUNT(*)
FROM employees
WHERE full_oshs_name LIKE '%Департамент Core Banking%' AND gender='F';

-- 168. Сравни команду Иванова Ивана и Смирнова Ивана по численности
SELECT 
  (SELECT COUNT(*) FROM employees WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')) AS ivanov_team,
  (SELECT COUNT(*) FROM employees WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Смирнов')) AS smirnov_team;

-- 169. Сколько сотрудников знают иностранные языки? (хотя бы один)
SELECT COUNT(*)
FROM employees
WHERE json_array_length(lang_with_level) > 0;

-- 170. Приведи топ 10 уникальных языков кроме русского знают сотрудники сбер
SELECT json_extract(value, '$') AS language, COUNT(*) AS cnt
FROM employees, json_each(lang_with_level)
WHERE value NOT LIKE '%Русский%'
GROUP BY language
ORDER BY cnt DESC
LIMIT 10;

-- 171. Выведи уникальные языки кроме русского которые знают сотрудники сбер
SELECT DISTINCT json_extract(value, '$') AS language
FROM employees, json_each(lang_with_level)
WHERE value NOT LIKE '%Русский%';

-- 172. как грейд зависит от стажа? (корреляция)
SELECT (AVG(grade_num * sber_los_cnt_days) - AVG(grade_num)*AVG(sber_los_cnt_days)) /
       (SQRT(AVG(grade_num*grade_num) - AVG(grade_num)*AVG(grade_num)) *
        SQRT(AVG(sber_los_cnt_days*sber_los_cnt_days) - AVG(sber_los_cnt_days)*AVG(sber_los_cnt_days))) AS correlation
FROM employees;

-- 173. Проанализируй зависимость стажа от роли
SELECT position_name, AVG(sber_los_cnt_days) AS avg_seniority_days
FROM employees
GROUP BY position_name
ORDER BY avg_seniority_days DESC;

-- 174. Приведи топ 20 самых возрастных сотрудников: фио, табель и возраст
SELECT employee_id, person_surname, person_name, age_y
FROM employees
ORDER BY age_y DESC
LIMIT 20;

-- 175. Покажи самый популярный иностранный язык, которым владеют сотрудники женского пола
SELECT value AS language, COUNT(*) AS cnt
FROM employees, json_each(lang_with_level)
WHERE gender = 'F'
  AND json_valid(lang_with_level) = 1
  AND value NOT LIKE '%Русский%'
GROUP BY language
ORDER BY cnt DESC
LIMIT 1;

-- 176. Самый редкий иностранный язык, которым владеют сотрудники Московского банка
SELECT value AS language, COUNT(*) AS cnt
FROM employees, json_each(lang_with_level)
WHERE full_oshs_name LIKE '%Московский банк%'
  AND json_valid(lang_with_level) = 1
  AND value NOT LIKE '%Русский%'
GROUP BY language
ORDER BY cnt ASC
LIMIT 1;

-- 177. сколько сотрудников кластера Аналитика руководителя имеют навык "функциональное тестирование"
SELECT COUNT(*)
FROM employees
WHERE cluster_name LIKE '%Аналитика руководителя%' AND all_skills LIKE '%функциональное тестирование%';

-- 178. Когда окончила ВУЗ Мария Иванова
SELECT date_finish_education
FROM employees
WHERE person_name='Мария' AND person_surname='Иванова';

-- 179. Сколько в банке клиентских менеджеров
SELECT COUNT(*) FROM employees WHERE position_name LIKE '%клиентский менеджер%';

-- 180. Покажи список сотрудников, окончивших МГУ по специальностям 'Экономика', 'Менеджмент' после 2018 года.
SELECT *
FROM employees
WHERE university_name LIKE '%МГУ%'
  AND (speciality_name LIKE '%Экономика%' OR speciality_name LIKE '%Менеджмент%')
  AND date_finish_education > '2018-01-01';

-- 181. Кто из сотрудников Управления развития каркаса Core Banking имеет остаток отпуска менее десяти дней?
SELECT employee_id, person_name, person_surname, vac_days
FROM employees
WHERE full_oshs_name LIKE '%Управление развития каркаса Core Banking%' AND vac_days < 10;

-- 182. Какие сотрудники, занимающие должность руководителя направления, закончили МГУ
SELECT *
FROM employees
WHERE position_name LIKE '%руководитель направления%' AND university_name LIKE '%МГУ%';

-- 183. Какие сотрудники, занимающие должность руководителя отдела, закончили образование по направлению 'Финансы и кредит'?
SELECT *
FROM employees
WHERE position_name LIKE '%Руководитель отдела%' AND speciality_name LIKE '%Финансы и кредит%';

-- 184. Предложи кандидатов на роль заместителя директора среди сотрудников с опытом управления от восьми лет и профильной специализацией 'Управление проектами'.
SELECT *
FROM employees
WHERE lead_experience_years >= 8
  AND (speciality_name LIKE '%Управление проектами%' OR all_skills LIKE '%Управление проектами%')
  AND position_name NOT LIKE '%директор%' -- исключим уже директоров
  AND grade_num >= 12; -- предположительно высокий грейд

-- 185. кто нибудь вышел из декрета за последний квартал в моей команде?
-- (выход из декрета = is_parental_leave изменился с 1 на 0, нужна история)
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT DISTINCT e.employee_id
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
  AND e.is_parental_leave = 0
  AND EXISTS (
    SELECT 1 FROM employees_history h 
    WHERE h.employee_id = e.employee_id AND h.report_date >= date('now', '-3 months')
      AND h.is_parental_leave = 1
  );

-- 186. выведи численности команд иванова ивана и ивана смирнова сгруппированные по полам
SELECT 
  'Иванов' AS manager,
  e.gender,
  COUNT(*) AS cnt
FROM employees e
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
GROUP BY e.gender
UNION ALL
SELECT 
  'Смирнов',
  e.gender,
  COUNT(*)
FROM employees e
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Смирнов')
GROUP BY e.gender;

-- 187. сравни среднюю оценку в команду Иванова Ивана и Ивана Смирнова
-- (оценка результативности fp_res)
WITH ivanov_avg AS (
  SELECT AVG(CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END) AS avg_res
  FROM employees
  WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
),
smirnov_avg AS (
  SELECT AVG(CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END) AS avg_res
  FROM employees
  WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Смирнов')
)
SELECT ivanov_avg.avg_res AS ivanov_team_avg, smirnov_avg.avg_res AS smirnov_team_avg
FROM ivanov_avg, smirnov_avg;

-- 188. выведи людей из моей команды которые имеют грейд выше среднего по банку и возраст ниже среднего по блоку Core Banking
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
),
avg_bank_grade AS (
  SELECT AVG(grade_num) AS avg_grade FROM employees
),
avg_Core Banking_age AS (
  SELECT AVG(age_y) AS avg_age FROM employees WHERE full_oshs_name LIKE '%Блок Core Banking%'
)
SELECT e.*
FROM employees e, my_team mt, avg_bank_grade abg, avg_Core Banking_age aha
WHERE e.team_name = mt.team_name
  AND e.grade_num > abg.avg_grade
  AND e.age_y < aha.avg_age;

-- 189. найди сотрудников в блоке технологии которые владеют английским на высоком уровне
SELECT *
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
  AND lang_with_level LIKE '%Английский%'
  AND (lang_with_level LIKE '%C1%' OR lang_with_level LIKE '%C2%' OR lang_with_level LIKE '%продвинутый%');

-- 190. как изменялась средняя оценка за результативность отдельно мужчин и женщин в блоке Core Banking за пол года?
-- (нужна временная таблица с оценками по месяцам)
SELECT 
  strftime('%Y-%m', report_date) AS month,
  gender,
  AVG(CASE fp_res WHEN 'A' THEN 5 WHEN 'B' THEN 4 WHEN 'C' THEN 3 ELSE 2 END) AS avg_res
FROM employees
WHERE full_oshs_name LIKE '%Блок Core Banking%'
  AND report_date >= date('now', '-6 months')
GROUP BY month, gender
ORDER BY month, gender;

-- 191. сравни количество сотрудников в департаменте ит блока 'Core Banking' умеющих кодить на python и на java
SELECT 
  SUM(CASE WHEN all_skills LIKE '%Python%' THEN 1 ELSE 0 END) AS python_cnt,
  SUM(CASE WHEN all_skills LIKE '%Java%' THEN 1 ELSE 0 END) AS java_cnt
FROM employees
WHERE full_oshs_name LIKE '%Департамент ИТ%' AND full_oshs_name LIKE '%Core Banking%';

-- 192. сколько сотрудников знающих итальянский было в моей команде пол года назад и сколько сейчас?
WITH my_team AS (
  SELECT team_name FROM employees WHERE employee_id = :current_user_id
)
SELECT 
  SUM(CASE WHEN report_date >= date('now', '-6 months') AND report_date < date('now') THEN 1 ELSE 0 END) AS half_year_ago,
  SUM(CASE WHEN report_date = date('now') THEN 1 ELSE 0 END) AS now
FROM employees e, my_team mt
WHERE e.team_name = mt.team_name
  AND e.lang_with_level LIKE '%Итальянский%';

-- 193. выведи навыки сотрудников команды Иванова Ивана
SELECT DISTINCT skill
FROM employees e, json_each(e.all_skills) AS skill
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов');

-- 194. найди почту и грейд Ивана Смирнова
SELECT wrk_email, grade_num
FROM employees
WHERE person_name='Иван' AND person_surname='Смирнов'
LIMIT 1;

-- 195. кто из сотрудников сможет перевести текст с английского на русский язык в блоке технологии?
-- (требуется знание английского на уровне выше B2)
SELECT *
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
  AND lang_with_level LIKE '%Английский%'
  AND (lang_with_level LIKE '%B2%' OR lang_with_level LIKE '%C1%' OR lang_with_level LIKE '%C2%');

-- 196. кто ушел в декрет в команде леши иванова за последний квартал?
-- (Леша = Алексей? предположим employee_id = :alex_ivanov_id)
SELECT e.employee_id
FROM employees e
WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Алексей' AND person_surname='Иванов')
  AND e.is_parental_leave = 1
  AND EXISTS (
    SELECT 1 FROM employees_history h
    WHERE h.employee_id = e.employee_id AND h.report_date >= date('now', '-3 months')
      AND h.is_parental_leave = 0
  );

-- 197. какие навыки новые приобрели сотрудники команды Иванова Ивана за последние пол года?
-- (нужно сравнить текущий all_skills с предыдущим срезом)
WITH current_skills AS (
  SELECT employee_id, skill
  FROM employees e, json_each(e.all_skills) AS skill
  WHERE e.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
),
past_skills AS (
  SELECT employee_id, skill
  FROM employees_history h, json_each(h.all_skills) AS skill
  WHERE h.lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
    AND h.report_date = date('now', '-6 months')
)
SELECT DISTINCT cs.skill
FROM current_skills cs
LEFT JOIN past_skills ps ON cs.employee_id = ps.employee_id AND cs.skill = ps.skill
WHERE ps.skill IS NULL;

-- 198. покажи сотрудников блока технологии которые получили минимум 2 оценки 4 за результат за прошлый год
-- (оценка 4 = B? используем fp_res)
SELECT employee_id, COUNT(*) AS high_ratings
FROM employees
WHERE full_oshs_name LIKE '%Блок Технологии%'
  AND fp_res = 'B'
  AND strftime('%Y', report_date) = strftime('%Y', 'now', '-1 year')
GROUP BY employee_id
HAVING COUNT(*) >= 2;

-- 199. покажи динамику изменения грейда сотрудников старше 35 в команде Иванова Ивана за год
-- (нужна история грейдов)
SELECT employee_id, report_date, grade_num
FROM employees_history
WHERE employee_id IN (
  SELECT employee_id FROM employees
  WHERE lid_1_lvl_i_pernr = (SELECT employee_id FROM employees WHERE person_name='Иван' AND person_surname='Иванов')
    AND age_y > 35
)
ORDER BY employee_id, report_date;

-- 200. кто из сотрудников блока Core Banking за год научился новому иностранному языку?
-- (сравнить lang_with_level с историей)
WITH current_lang AS (
  SELECT employee_id, json_extract(value,'$') AS lang
  FROM employees, json_each(lang_with_level)
  WHERE full_oshs_name LIKE '%Блок Core Banking%'
),
past_lang AS (
  SELECT h.employee_id, json_extract(value,'$') AS lang
  FROM employees_history h, json_each(h.lang_with_level) AS value
  WHERE h.full_oshs_name LIKE '%Блок Core Banking%' AND h.report_date = date('now', '-1 year')
)
SELECT DISTINCT cl.employee_id, cl.lang AS new_language
FROM current_lang cl
LEFT JOIN past_lang pl ON cl.employee_id = pl.employee_id AND cl.lang = pl.lang
WHERE pl.lang IS NULL;

-- 201. Все люди с дубликатами по имени и фамилии (каждая запись сотрудника + количество дублей)
SELECT 
  employee_id,
  person_surname,
  person_name,
  person_patronimics,
  COUNT(*) OVER (PARTITION BY person_surname, person_name) AS duplicate_count
FROM employees
WHERE (person_surname, person_name) IN (
    SELECT person_surname, person_name
    FROM employees
    GROUP BY person_surname, person_name
    HAVING COUNT(*) > 1
)
ORDER BY duplicate_count DESC, person_surname, person_name, employee_id;


-- 202. Проверь, есть ли тезки по фамилии и имени, у которых разный грейд
SELECT 
  person_surname,
  person_name,
  group_concat(DISTINCT grade_num) AS different_grades,
  COUNT(*) AS total_employees,
  COUNT(DISTINCT grade_num) AS distinct_grades_count
FROM employees
WHERE person_surname IS NOT NULL AND person_name IS NOT NULL
GROUP BY person_surname, person_name
HAVING COUNT(DISTINCT grade_num) > 1
ORDER BY distinct_grades_count DESC, total_employees DESC;