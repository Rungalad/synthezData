"""Synthetic HR-data generator for an IT+banking company.

Produces a relational long-format table: rows = (employee_id, report_date).
Each employee_id persists across monthly snapshots with natural dynamics
(tenure grows, occasional position/department changes, quarterly review
refresh, ~1.5%/month attrition with backfill hiring).

Schema follows COLUMNS_DESCRIPTION from db_info.py (55 columns).
Target company mix: ~20% IT headcount, ~80% banking/ops.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any

import numpy as np
import pandas as pd
from dateutil.relativedelta import relativedelta
from faker import Faker

# ---------------------------------------------------------------------------
# Reference pools
# ---------------------------------------------------------------------------

BLOCK_KEYWORDS = ["Блок", "Дивизион", "Центр", "Банк", "Отделение", "Департамент", "Упр-ние"]

# (name, is_it, target_headcount_share)
L1_BLOCKS = [
    ("Блок Технологии и Данные", True, 0.20),
    ("Блок Розничный Бизнес", False, 0.32),
    ("Блок Корпоративно-Инвестиционный", False, 0.22),
    ("Блок Риски и Комплаенс", False, 0.13),
    ("Блок Операционный", False, 0.13),
]

L2_NAME_POOL_IT = [
    "Департамент Платформы Данных", "Центр Машинного Обучения",
    "Дивизион Клиентских Сервисов", "Департамент Кибербезопасности",
    "Центр Инженерии DevOps", "Департамент Облачной Инфраструктуры",
    "Центр Ananas Engineering", "Департамент Core Banking Platform",
]
L2_NAME_POOL_BANK = [
    "Департамент Розничного Кредитования", "Центр Премиальных Клиентов",
    "Дивизион Корпоративных Продаж", "Департамент Ипотечного Бизнеса",
    "Центр Карточных Продуктов", "Департамент Казначейства",
    "Дивизион Инвестиционных Решений", "Центр Управления Рисками",
    "Департамент Комплаенса", "Упр-ние Операционной Поддержки",
    "Центр Claims Processing", "Департамент Back-Office",
]

L3_NAME_POOL = [
    "Упр-ние Ананасов", "Упр-ние Бананов", "Упр-ние Манго",
    "Упр-ние Customer Journey", "Упр-ние Data Quality",
    "Упр-ние Разработки Продуктов", "Упр-ние Аналитики",
    "Упр-ние Мониторинга", "Упр-ние Интеграции", "Упр-ние Архитектуры",
    "Упр-ние Поддержки", "Упр-ние Маркетплейса", "Упр-ние Автоматизации",
    "Упр-ние Лояльности", "Упр-ние Стратегии", "Упр-ние Transformation",
]

L4_NAME_POOL = [
    "Отделение Alpha", "Отделение Beta", "Отделение Gamma", "Отделение Delta",
    "Отдел Юпитер", "Отдел Сатурн", "Отдел Нептун", "Отдел Меркурий",
    "Команда Pineapple", "Команда Banana", "Команда Mango", "Команда Kiwi",
    "Отдел Поддержки Клиентов", "Отдел Разработки", "Отдел Сопровождения",
]

IT_POSITIONS = [
    "Младший разработчик", "Разработчик", "Старший разработчик", "Ведущий разработчик",
    "Главный инженер-программист", "Data Scientist", "Старший Data Scientist",
    "ML Engineer", "Data Engineer", "Старший Data Engineer", "DevOps инженер",
    "Старший DevOps инженер", "SRE инженер", "QA инженер", "Старший QA инженер",
    "Системный аналитик", "Старший системный аналитик", "Архитектор решений",
    "Главный архитектор", "Инженер по кибербезопасности", "Product Owner", "Scrum Master",
]

BANK_POSITIONS = [
    "Клиентский менеджер", "Старший клиентский менеджер", "Главный клиентский менеджер",
    "Специалист по кредитованию", "Ведущий специалист по кредитованию",
    "Андеррайтер", "Старший андеррайтер", "Кредитный аналитик",
    "Риск-аналитик", "Старший риск-аналитик", "Специалист комплаенса",
    "Операционист", "Старший операционист", "Кассир-операционист",
    "Финансовый аналитик", "Старший финансовый аналитик", "Бухгалтер",
    "Главный бухгалтер", "Юрист", "Ведущий юрист", "HR-специалист",
    "Специалист по маркетингу", "Ведущий специалист по продажам",
]

PROF_LEVELS_IT = ["Engineering", "Data", "Architecture", "Security", "Product", "QA"]
PROF_LEVELS_BANK = ["Sales", "Credit", "Risk", "Operations", "Finance", "Legal", "HR", "Marketing"]

IT_SKILLS = [
    "Python", "Java", "Scala", "Go", "Kotlin", "SQL", "PySpark", "Airflow", "Kafka",
    "Kubernetes", "Docker", "Terraform", "AWS", "GCP", "Hadoop", "ClickHouse",
    "PostgreSQL", "Oracle", "Kubernetes Operators", "Git", "CI/CD", "Jenkins",
    "Machine Learning", "Deep Learning", "NLP", "Computer Vision", "PyTorch",
    "TensorFlow", "Scikit-learn", "Pandas", "NumPy", "REST API", "GraphQL",
    "Microservices", "Linux", "Bash", "Ansible", "Prometheus", "Grafana",
]
BANK_SKILLS = [
    "Кредитный анализ", "МСФО", "РСБУ", "1С", "SAP", "Работа с клиентами",
    "Переговоры", "AML/KYC", "Basel III", "Управление рисками",
    "Финансовое моделирование", "Excel (продвинутый)", "Bloomberg Terminal",
    "Продажи B2B", "Продажи B2C", "Презентации", "Юридический английский",
    "Подготовка отчётности", "Комплаенс", "Due diligence", "Оценка залогов",
    "Андеррайтинг", "Бухгалтерский учёт", "Налоговое право",
]
SOFT_SKILLS = [
    "Коммуникации", "Лидерство", "Тайм-менеджмент", "Критическое мышление",
    "Работа в команде", "Наставничество", "Публичные выступления",
]

UNIVERSITIES = [
    "МГУ им. М.В. Ломоносова", "МФТИ", "НИУ ВШЭ", "МГТУ им. Н.Э. Баумана",
    "СПбГУ", "ИТМО", "РЭУ им. Г.В. Плеханова", "Финансовый университет при Правительстве РФ",
    "РАНХиГС", "МИСиС", "РУДН", "НГУ", "КФУ", "УрФУ",
]
SPECIALITIES_IT = [
    "Прикладная математика и информатика", "Программная инженерия",
    "Информационная безопасность", "Компьютерные науки", "Data Science",
]
SPECIALITIES_BANK = [
    "Финансы и кредит", "Экономика", "Банковское дело", "Юриспруденция",
    "Менеджмент", "Бухгалтерский учёт и аудит", "Маркетинг",
]

LANGUAGES = [("Английский", ["A2", "B1", "B2", "C1", "C2"]),
             ("Немецкий", ["A1", "A2", "B1"]),
             ("Китайский", ["A1", "A2", "B1"]),
             ("Французский", ["A1", "A2", "B1"])]

CAREER_STATUSES = ["Открыт", "Закрыт", "Не заполнено", None]
GRADES_AB = "ABCDE"

# ---------------------------------------------------------------------------
# Hierarchical org tree
# ---------------------------------------------------------------------------


@dataclass
class Unit:
    uid: int
    name: str
    level: int
    is_it: bool
    parent: "Unit | None" = None
    children: list["Unit"] = field(default_factory=list)
    size_weight: float = 1.0


@dataclass
class AgileTeam:
    tribe_name: str; tribe_code: int
    cluster_name: str; cluster_code: int
    team_name: str; team_code: int
    is_it: bool


def _next_uid(counter: list[int]) -> int:
    counter[0] += 1
    return 1000 + counter[0]


def build_org_tree(rng: random.Random) -> tuple[list[Unit], list[Unit]]:
    """Build a 4-level org tree. Return (all_units, leaf_units)."""
    counter = [0]
    all_units: list[Unit] = []
    leaves: list[Unit] = []

    for l1_name, is_it, share in L1_BLOCKS:
        l1 = Unit(_next_uid(counter), l1_name, 1, is_it)
        all_units.append(l1)

        pool = L2_NAME_POOL_IT if is_it else L2_NAME_POOL_BANK
        l2_names = rng.sample(pool, k=rng.randint(3, 5))
        for l2_name in l2_names:
            l2 = Unit(_next_uid(counter), l2_name, 2, is_it, parent=l1)
            l1.children.append(l2); all_units.append(l2)

            for l3_name in rng.sample(L3_NAME_POOL, k=rng.randint(2, 4)):
                # append a short tag to avoid duplicates across branches
                tag = rng.choice(["N", "E", "S", "W", "Core", "Plus", "X"])
                l3 = Unit(_next_uid(counter), f"{l3_name} {tag}", 3, is_it, parent=l2)
                l2.children.append(l3); all_units.append(l3)

                for l4_name in rng.sample(L4_NAME_POOL, k=rng.randint(2, 5)):
                    tag2 = rng.randint(1, 99)
                    leaf = Unit(_next_uid(counter), f"{l4_name}-{tag2}", 4, is_it, parent=l3)
                    leaf.size_weight = rng.uniform(0.6, 1.6)
                    l3.children.append(leaf); all_units.append(leaf); leaves.append(leaf)
        # normalise leaf weights so total over block matches target share
        block_leaves = [u for u in all_units if u.level == 4 and _root(u) is l1]
        w_sum = sum(u.size_weight for u in block_leaves)
        for u in block_leaves:
            u.size_weight = u.size_weight / w_sum * share
    return all_units, leaves


def _root(u: Unit) -> Unit:
    while u.parent is not None:
        u = u.parent
    return u


def unit_tree_path(u: Unit) -> list[int]:
    path: list[int] = []
    cur: Unit | None = u
    while cur is not None:
        path.append(cur.uid); cur = cur.parent
    return list(reversed(path))


def unit_full_name(u: Unit) -> str:
    names: list[str] = []
    cur: Unit | None = u
    while cur is not None:
        names.append(cur.name); cur = cur.parent
    return " / ".join(reversed(names))


TRIBE_THEMES_IT = [
    "Data Platform", "ML & AI", "Customer Experience", "Core Banking",
    "DevSecOps", "Cloud Foundation", "Mobile Engineering", "Web Engineering",
    "API Gateway", "Cybersecurity", "Data Governance", "Analytics & BI",
    "Digital Identity", "Payments Tech", "Risk Engine", "Fraud Detection",
]
TRIBE_THEMES_BANK = [
    "Retail Lending", "Mortgage", "Premium Clients", "SME Banking",
    "Corporate Sales", "Treasury", "Investment Solutions", "Cards",
    "Acquiring", "Loyalty", "Claims", "Collection", "Compliance Ops",
    "Back-Office Operations", "Financial Reporting",
]
TRIBE_ADJECTIVES = [
    "Next", "Smart", "Digital", "Unified", "Agile", "One", "Prime",
    "Express", "Atlas", "Orion", "Phoenix", "Vector", "Quantum",
    "Nova", "Fusion", "Horizon", "Compass", "Beacon",
]
CLUSTER_THEMES_IT = [
    "Ingestion", "Streaming", "Feature Store", "MLOps", "Model Serving",
    "Search", "Personalization", "Recommender", "CI/CD", "Observability",
    "Identity", "Access Management", "Data Lake", "Data Warehouse",
    "Frontend", "Backend", "Mobile iOS", "Mobile Android", "Integration Bus",
]
CLUSTER_THEMES_BANK = [
    "Онбординг", "Скоринг", "Сопровождение сделок", "Кросс-продажи",
    "Досрочное погашение", "Верификация", "Мониторинг портфеля",
    "Реструктуризация", "Взыскание", "Открытие счетов",
    "Выпуск карт", "Комиссии и тарифы", "Претензионная работа",
    "Отчётность ЦБ", "Антифрод",
]
TEAM_NICKS = [
    "Ananas", "Banana", "Mango", "Kiwi", "Papaya", "Peach", "Lychee",
    "Durian", "Apple", "Cherry", "Grape", "Lemon", "Melon",
    "Falcon", "Hawk", "Eagle", "Raven", "Sparrow", "Owl",
    "Neptune", "Jupiter", "Saturn", "Mercury", "Venus", "Mars", "Pluto",
    "Alpha", "Beta", "Gamma", "Delta", "Sigma", "Omega", "Zeta", "Theta",
    "Nord", "Sud", "Est", "West", "Core", "Edge", "Prime", "Zero", "One",
]
TEAM_SUFFIXES_IT = [
    "Engineering", "Platform", "Experience", "Analytics", "Automation",
    "Reliability", "Security", "Insights", "Delivery", "Innovation",
]
TEAM_SUFFIXES_BANK = [
    "Продаж", "Поддержки", "Контроля", "Обслуживания", "Аналитики",
    "Развития", "Взаимодействия", "Сопровождения", "Мониторинга",
]


def _make_tribe_name(rng: random.Random, is_it: bool, idx: int) -> str:
    themes = TRIBE_THEMES_IT if is_it else TRIBE_THEMES_BANK
    style = rng.randint(0, 3)
    theme = rng.choice(themes)
    adj = rng.choice(TRIBE_ADJECTIVES)
    if style == 0:
        return f"Трайб «{theme}»"
    if style == 1:
        return f"Трайб {adj} {theme}"
    if style == 2:
        return f"Tribe {theme} {idx % 50}"
    return f"Трайб {theme} {rng.choice(['RU', 'EU', 'Global', 'Digital', 'Core'])}"


def _make_cluster_name(rng: random.Random, is_it: bool, idx: int) -> str:
    themes = CLUSTER_THEMES_IT if is_it else CLUSTER_THEMES_BANK
    style = rng.randint(0, 2)
    theme = rng.choice(themes)
    if style == 0:
        return f"Кластер {theme}"
    if style == 1:
        return f"Кластер {theme} {rng.choice(TRIBE_ADJECTIVES)}"
    return f"Кластер {theme} {idx % 40}"


def _make_team_name(rng: random.Random, is_it: bool, leaf: "Unit") -> str:
    style = rng.randint(0, 4)
    nick = rng.choice(TEAM_NICKS)
    suffix_pool = TEAM_SUFFIXES_IT if is_it else TEAM_SUFFIXES_BANK
    suffix = rng.choice(suffix_pool)
    if style == 0:
        return f"Команда {nick}"
    if style == 1:
        return f"Команда {nick} {suffix}"
    if style == 2:
        return f"Team {nick} {rng.randint(1, 99)}"
    if style == 3:
        # use leaf name tail for traceability
        short = leaf.name.split()[-1] if leaf.name else nick
        return f"Команда {nick}-{short}"
    return f"Команда {nick} {rng.choice(['North', 'South', 'East', 'West', 'Core', 'Edge'])}"


def build_agile_teams(
    rng: random.Random,
    leaves: list[Unit],
    coverage: float = 0.80,
) -> list[AgileTeam]:
    """Assign agile tribe/cluster/team to ~`coverage` of ALL leaves.

    Both IT and non-IT leaves get agile structure; names are themed by
    IT/bank flavour. The remaining ~(1-coverage) of leaves stay without
    agile (tribe/cluster/team fields will be NULL for those employees).
    """
    teams: list[AgileTeam] = []
    tribe_counter = 5000
    cluster_counter = 6000
    team_counter = 7000

    # 1. decide which leaves are covered, preserving weighted headcount share
    rng.shuffle(leaves)
    total_w = sum(lf.size_weight for lf in leaves)
    target_w = coverage * total_w
    covered_set: set[int] = set()
    acc = 0.0
    for lf in leaves:
        if acc >= target_w: break
        covered_set.add(lf.uid); acc += lf.size_weight
    covered = [lf for lf in leaves if lf.uid in covered_set]

    # 2. group covered leaves by (is_it, L2 parent) → one tribe per group
    by_l2: dict[tuple[bool, int], list[Unit]] = {}
    for lf in covered:
        l2 = lf.parent.parent  # type: ignore[union-attr]
        by_l2.setdefault((lf.is_it, l2.uid), []).append(lf)  # type: ignore[union-attr]

    leaf_to_team: dict[int, AgileTeam] = {}
    for (is_it, _l2_uid), lfs in by_l2.items():
        tribe_counter += 1
        tribe_name = _make_tribe_name(rng, is_it, tribe_counter)
        rng.shuffle(lfs)
        # 1-3 clusters per tribe
        n_clusters = max(1, min(len(lfs), rng.randint(1, 3)))
        chunk = max(1, len(lfs) // n_clusters)
        for i in range(0, len(lfs), chunk):
            cluster_counter += 1
            cluster_name = _make_cluster_name(rng, is_it, cluster_counter)
            for lf in lfs[i:i + chunk]:
                team_counter += 1
                t = AgileTeam(tribe_name, tribe_counter, cluster_name, cluster_counter,
                              _make_team_name(rng, is_it, lf), team_counter, is_it=is_it)
                teams.append(t); leaf_to_team[lf.uid] = t
    for lf in leaves:
        lf.agile = leaf_to_team.get(lf.uid)  # type: ignore[attr-defined]
    return teams


# ---------------------------------------------------------------------------
# Employee state
# ---------------------------------------------------------------------------


def _position_for(unit: Unit, is_manager: bool, rng: random.Random, grade: int) -> tuple[str, str]:
    """Return (position_name, professionlevel_name)."""
    if is_manager:
        # e.g. "Руководитель управления Ананасов N"
        level_word = {1: "блока", 2: "департамента", 3: "управления", 4: "отдела"}[unit.level]
        # strip leading keyword from unit name for cleaner title
        bare = unit.name
        for kw in BLOCK_KEYWORDS + ["Отдел", "Отделение", "Команда"]:
            if bare.startswith(kw + " "):
                bare = bare[len(kw) + 1:]; break
        pos = f"Руководитель {level_word} {bare}"
        prof = "Management"
        return pos, prof
    if unit.is_it:
        pos = rng.choice(IT_POSITIONS)
        prof = rng.choice(PROF_LEVELS_IT)
    else:
        pos = rng.choice(BANK_POSITIONS)
        prof = rng.choice(PROF_LEVELS_BANK)
    return pos, prof


def _grade_for(unit: Unit, is_manager: bool, rng: random.Random) -> int:
    if is_manager:
        return rng.randint(14, 17) if unit.level <= 2 else rng.randint(11, 14)
    return rng.randint(7, 13)


def _skills_for(unit: Unit, is_manager: bool, rng: random.Random) -> list[str]:
    base = IT_SKILLS if unit.is_it else BANK_SKILLS
    n = rng.randint(3, 8)
    skills = rng.sample(base, k=min(n, len(base)))
    if is_manager or rng.random() < 0.4:
        skills += rng.sample(SOFT_SKILLS, k=rng.randint(1, 3))
    return skills


def _languages(rng: random.Random, is_it: bool) -> list[str]:
    out = []
    # english nearly always, higher level for IT
    if rng.random() < (0.95 if is_it else 0.7):
        lvl = rng.choices(["A2", "B1", "B2", "C1", "C2"],
                          weights=[1, 3, 4, 2, 1] if is_it else [3, 4, 2, 1, 0.5])[0]
        out.append(f"Английский / {lvl}")
    # sometimes second language
    if rng.random() < 0.15:
        lang, lvls = rng.choice(LANGUAGES[1:])
        out.append(f"{lang} / {rng.choice(lvls)}")
    return out


def _goals_for(unit: Unit, is_manager: bool, rng: random.Random) -> list[str]:
    tmpls_it = [
        "Вывести сервис {x} в промышленную эксплуатацию",
        "Сократить время отклика API до {x} мс",
        "Повысить покрытие тестами до {x}%",
        "Внедрить модель {x} в продукт",
        "Мигрировать {x} на облачную платформу",
    ]
    tmpls_bank = [
        "Выполнить план продаж по {x}",
        "Снизить долю проблемных кредитов до {x}%",
        "Привлечь клиентов сегмента {x}",
        "Запустить продукт {x}",
        "Сократить срок обработки заявок до {x} дней",
    ]
    tmpls = tmpls_it if unit.is_it else tmpls_bank
    n = rng.randint(2, 5)
    return [t.format(x=rng.choice(["A", "B", "X", str(rng.randint(5, 95))])) for t in rng.sample(tmpls, n)]


def _achievements(rng: random.Random, is_it: bool) -> list[str]:
    pool_it = ["Запустил ML-модель в прод", "Ускорил pipeline в 2 раза",
              "Получил сертификат AWS", "Выиграл внутренний хакатон",
              "Реализовал миграцию на K8s"]
    pool_bank = ["Выполнил план продаж на 120%", "Получил благодарность от клиента",
                "Закрыл крупную сделку", "Прошёл обучение МСФО",
                "Оптимизировал процесс обработки заявок"]
    pool = pool_it if is_it else pool_bank
    return rng.sample(pool, k=rng.randint(0, 3))


def _birthdate_from_age(age: int, ref: date, rng: random.Random) -> date:
    # approximate — pick random day in the year that gives this age on ref
    y = ref.year - age
    try:
        return date(y, rng.randint(1, 12), rng.randint(1, 28))
    except ValueError:
        return date(y, 1, 1)


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------


def _new_employee(
    emp_id: str,
    unit: Unit,
    is_manager: bool,
    fake: Faker,
    rng: random.Random,
    report_date: date,
    hire_date: date,
) -> dict[str, Any]:
    gender = rng.choices(["M", "F", None], weights=[0.55, 0.43, 0.02])[0]
    if gender == "M":
        name = fake.first_name_male(); patr = fake.middle_name_male(); surn = fake.last_name_male()
    elif gender == "F":
        name = fake.first_name_female(); patr = fake.middle_name_female(); surn = fake.last_name_female()
    else:
        name = fake.first_name(); patr = fake.middle_name(); surn = fake.last_name()

    age = rng.randint(22, 62)
    grade = _grade_for(unit, is_manager, rng)
    pos, prof = _position_for(unit, is_manager, rng, grade)
    skills = _skills_for(unit, is_manager, rng)
    langs = _languages(rng, unit.is_it)
    goals = _goals_for(unit, is_manager, rng)
    num_goals = len(goals)
    mean_completion = round(rng.uniform(0.3, 1.0), 4)
    not_completed = max(0, num_goals - int(round(num_goals * mean_completion)))
    risked = rng.randint(0, max(0, not_completed))
    children_cnt = rng.choices([0, 1, 2, 3], weights=[0.45, 0.25, 0.22, 0.08])[0] if age >= 24 else 0
    children_genders = [rng.choices(["M", "F", None], weights=[0.48, 0.48, 0.04])[0] for _ in range(children_cnt)]
    children_years = [rng.randint(0, min(25, age - 20)) if age > 20 else 0 for _ in range(children_cnt)]
    family = rng.choices([0, 1, 2, 3, 4, 5], weights=[0.3, 0.45, 0.08, 0.02, 0.1, 0.05])[0]

    email_slug = fake.user_name()
    wrk = f"{email_slug}@synthbank.ru"
    ext = f"{email_slug}{rng.randint(10, 999)}@{rng.choice(['gmail.com', 'mail.ru', 'yandex.ru', 'outlook.com'])}"
    phone = f"+7{rng.randint(9000000000, 9999999999)}"

    stage_days = (report_date - hire_date).days
    is_trial = 1 if stage_days < 90 else 0
    parental = 1 if (gender == "F" and rng.random() < 0.04) else 0

    fp_res = rng.choices(list(GRADES_AB), weights=[0.1, 0.3, 0.4, 0.15, 0.05])[0]
    fp_comp = rng.choices(list(GRADES_AB), weights=[0.1, 0.35, 0.4, 0.1, 0.05])[0]

    lead_exp = rng.randint(1, min(25, max(1, age - 25))) if is_manager else rng.choices(
        [0, rng.randint(1, 5)], weights=[0.85, 0.15])[0] if age > 28 else 0

    career = rng.choices(CAREER_STATUSES, weights=[0.25, 0.5, 0.2, 0.05])[0]
    univ = rng.choice(UNIVERSITIES)
    spec = rng.choice(SPECIALITIES_IT if unit.is_it else SPECIALITIES_BANK)
    finish_edu = f"{rng.randint(max(1985, report_date.year - age + 20), report_date.year - 1)}-06-30"

    vac = rng.randint(0, 28)
    date_since_raise = rng.randint(0, 900)

    return {
        "employee_id": emp_id,
        "unit": unit,               # keep ref, serialize later
        "is_manager": is_manager,
        "hire_date": hire_date,
        "grade_num": grade,
        "position_name": pos,
        "professionlevel_name": prof,
        "person_surname": surn, "person_name": name, "person_patronimics": patr,
        "gender": gender, "age_y": age,
        "wrk_email": wrk, "ext_email": ext, "employee_kipphn": phone,
        "child_count": children_cnt,
        "children_gender": children_genders,
        "children_years": children_years,
        "family_status": family,
        "is_on_trial": is_trial,
        "sber_los_cnt_days": stage_days,
        "is_parental_leave": parental,
        "all_skills": skills,
        "date_since_salary_change_last": date_since_raise,
        "fp_res": fp_res, "fp_comp": fp_comp,
        "all_goals_desc": goals,
        "mean_value_completion": mean_completion,
        "num_goals": num_goals,
        "not_completed_goals": not_completed,
        "risked_goals": risked,
        "achievement_desc": _achievements(rng, unit.is_it),
        "career_status": career,
        "university_name": univ,
        "speciality_name": spec,
        "date_finish_education": finish_edu,
        "lead_experience_years": lead_exp,
        "vac_days": vac,
        "lang_with_level": langs,
    }


def _pick_unit(rng: random.Random, leaves: list[Unit], weights: list[float]) -> Unit:
    return rng.choices(leaves, weights=weights, k=1)[0]


def generate_synthetic_hr(
    n_employees: int = 20_000,
    start_month_end: date = date(2025, 10, 31),
    n_months: int = 6,
    it_share: float = 0.20,
    attrition_per_month: float = 0.015,
    position_change_per_month: float = 0.02,
    seed: int = 42,
) -> pd.DataFrame:
    """Generate a long-format synthetic HR dataset.

    Returns a pandas DataFrame with 55 columns (see COLUMNS_DESCRIPTION).
    Each employee persists across snapshots with natural dynamics:
    tenure grows monthly, quarterly review grades refresh, a small share
    of employees change position/unit, ~1.5%/month leave and are replaced
    by new hires (new employee_id).
    """
    rng = random.Random(seed); np.random.seed(seed)
    fake = Faker("ru_RU"); Faker.seed(seed)

    units, leaves = build_org_tree(rng)
    _ = build_agile_teams(rng, leaves)
    leaf_weights = [lf.size_weight for lf in leaves]

    # month-end dates
    dates: list[date] = []
    cur = start_month_end
    for _ in range(n_months):
        dates.append(cur)
        cur = (cur + relativedelta(months=1) + relativedelta(day=31))

    # ------------------------------------------------------------------
    # initial population at dates[0]
    # ------------------------------------------------------------------
    employees: dict[str, dict[str, Any]] = {}
    emp_counter = [10_000_000]
    def new_emp_id() -> str:
        emp_counter[0] += 1; return str(emp_counter[0])

    # ensure at least one "manager" per unit that will produce lid_* leaders.
    # we mark ~10% of employees as managers, concentrated in upper levels.
    for _ in range(n_employees):
        unit = _pick_unit(rng, leaves, leaf_weights)
        is_manager = rng.random() < 0.10
        hire_date = dates[0] - timedelta(days=rng.randint(30, 365 * 15))
        eid = new_emp_id()
        employees[eid] = _new_employee(eid, unit, is_manager, fake, rng, dates[0], hire_date)

    # assign designated managers per unit at each level
    def pick_leader_for(unit: Unit) -> str | None:
        candidates = [eid for eid, e in employees.items()
                      if _root(e["unit"]) is _root(unit) and e["is_manager"]]
        return rng.choice(candidates) if candidates else None

    # precompute some cross-employee fields (succesors)
    all_ids = list(employees.keys())

    # ------------------------------------------------------------------
    # month-by-month snapshots
    # ------------------------------------------------------------------
    all_rows: list[dict[str, Any]] = []
    for mi, rep_date in enumerate(dates):
        # dynamics (except month 0)
        if mi > 0:
            # attrition
            n_leave = int(round(len(employees) * attrition_per_month))
            leavers = rng.sample(list(employees.keys()), k=n_leave)
            for eid in leavers: del employees[eid]
            # backfill hires
            for _ in range(n_leave):
                unit = _pick_unit(rng, leaves, leaf_weights)
                is_manager = rng.random() < 0.05
                hire_date = rep_date - timedelta(days=rng.randint(0, 60))
                eid = new_emp_id()
                employees[eid] = _new_employee(eid, unit, is_manager, fake, rng, rep_date, hire_date)
            # tenure & raise counter bump, trial flag refresh
            for e in employees.values():
                e["sber_los_cnt_days"] = (rep_date - e["hire_date"]).days
                e["is_on_trial"] = 1 if e["sber_los_cnt_days"] < 90 else 0
                if rng.random() < 0.03:
                    e["date_since_salary_change_last"] = 0
                else:
                    e["date_since_salary_change_last"] += 30
                # quarterly review refresh
                if rep_date.month in (3, 6, 9, 12):
                    e["fp_res"] = rng.choices(list(GRADES_AB), weights=[0.1, 0.3, 0.4, 0.15, 0.05])[0]
                    e["fp_comp"] = rng.choices(list(GRADES_AB), weights=[0.1, 0.35, 0.4, 0.1, 0.05])[0]
                    e["mean_value_completion"] = round(rng.uniform(0.3, 1.0), 4)
            # position / unit changes
            n_change = int(round(len(employees) * position_change_per_month))
            for eid in rng.sample(list(employees.keys()), k=n_change):
                e = employees[eid]
                if rng.random() < 0.3:
                    e["unit"] = _pick_unit(rng, leaves, leaf_weights)
                e["position_name"], e["professionlevel_name"] = _position_for(
                    e["unit"], e["is_manager"], rng, e["grade_num"])
                if rng.random() < 0.3:
                    e["grade_num"] = min(17, e["grade_num"] + 1)
            all_ids = list(employees.keys())

        # designate leaders per hierarchy path for this month (stable-ish)
        # cluster leaders = first manager of each L2; lvl1/2/3 from L1/L2/L3.
        leaders_by_level: dict[tuple[int, int], str] = {}
        for u in units:
            mgr_ids = [eid for eid, e in employees.items()
                       if e["is_manager"] and (e["unit"] is u or _is_descendant(e["unit"], u))]
            if mgr_ids:
                leaders_by_level[(u.level, u.uid)] = mgr_ids[0]
        # tribe/cluster leaders for agile
        tribe_leaders: dict[int, str] = {}
        cluster_leaders: dict[int, str] = {}
        for lf in leaves:
            agile = getattr(lf, "agile", None)
            if agile is None: continue
            if agile.tribe_code not in tribe_leaders:
                cand = [eid for eid, e in employees.items()
                        if e["is_manager"] and getattr(e["unit"], "agile", None) is not None
                        and e["unit"].agile.tribe_code == agile.tribe_code]
                if cand: tribe_leaders[agile.tribe_code] = cand[0]
            if agile.cluster_code not in cluster_leaders:
                cand = [eid for eid, e in employees.items()
                        if e["is_manager"] and getattr(e["unit"], "agile", None) is not None
                        and e["unit"].agile.cluster_code == agile.cluster_code]
                if cand: cluster_leaders[agile.cluster_code] = cand[0]

        # serialize rows
        for eid, e in employees.items():
            u: Unit = e["unit"]
            path = unit_tree_path(u)  # [l1,l2,l3,l4]
            full_name = unit_full_name(u)
            agile: AgileTeam | None = getattr(u, "agile", None)

            # successors: 0..3 random other emp_ids
            succ = rng.sample(all_ids, k=min(len(all_ids) - 1, rng.randint(0, 3))) if len(all_ids) > 1 else []

            def as_int(eid_or_none: str | None) -> int:
                return int(eid_or_none) if eid_or_none else 0

            row = {
                "report_date": rep_date,
                "employee_id": eid,
                "grade_num": e["grade_num"],
                "position_name": e["position_name"],
                "unit_id_tree": path,
                "person_surname": e["person_surname"],
                "person_name": e["person_name"],
                "person_patronimics": e["person_patronimics"],
                "gender": e["gender"],
                "age_y": e["age_y"],
                "wrk_email": e["wrk_email"],
                "ext_email": e["ext_email"],
                "employee_kipphn": e["employee_kipphn"],
                "child_count": e["child_count"],
                "family_status": e["family_status"],
                "is_on_trial": e["is_on_trial"],
                "sber_los_cnt_days": e["sber_los_cnt_days"],
                "is_parental_leave": e["is_parental_leave"],
                "all_skills": e["all_skills"],
                "date_since_salary_change_last": e["date_since_salary_change_last"],
                "po_i_pernr": as_int(leaders_by_level.get((min(u.level, 3), path[min(u.level, 3) - 1]))),
                "fp_res": e["fp_res"],
                "fp_comp": e["fp_comp"],
                "full_oshs_name": full_name,
                "all_succesors": succ,
                "children_gender": e["children_gender"],
                "children_years": e["children_years"],
                "lang_with_level": e["lang_with_level"],
                "tribe_name": agile.tribe_name if agile else None,
                "cluster_name": agile.cluster_name if agile else None,
                "team_name": agile.team_name if agile else None,
                "tribe_code": agile.tribe_code if agile else None,
                "cluster_code": agile.cluster_code if agile else None,
                "team_code": agile.team_code if agile else None,
                "all_goals_desc": e["all_goals_desc"],
                "mean_value_completion": e["mean_value_completion"],
                "num_goals": e["num_goals"],
                "not_completed_goals": e["not_completed_goals"],
                "risked_goals": e["risked_goals"],
                "achievement_desc": e["achievement_desc"],
                "career_status": e["career_status"],
                "university_name": e["university_name"],
                "speciality_name": e["speciality_name"],
                "date_finish_education": e["date_finish_education"],
                "lead_experience_years": e["lead_experience_years"],
                "professionlevel_name": e["professionlevel_name"],
                "vac_days": e["vac_days"],
                "lid_tribe_i_pernr": as_int(tribe_leaders.get(agile.tribe_code)) if agile else 0,
                "lid_1_lvl_i_pernr": as_int(leaders_by_level.get((1, path[0]))),
                "lid_2_lvl_i_pernr": as_int(leaders_by_level.get((2, path[1]))) if len(path) > 1 else 0,
                "lid_3_lvl_i_pernr": as_int(leaders_by_level.get((3, path[2]))) if len(path) > 2 else 0,
                "lid_cluster_i_pernr": as_int(cluster_leaders.get(agile.cluster_code)) if agile else 0,
                "it_lid_cluster_i_pernr": as_int(cluster_leaders.get(agile.cluster_code)) if agile else 0,
                "cur_tribe_i_pernr": as_int(tribe_leaders.get(agile.tribe_code)) if agile else 0,
            }
            all_rows.append(row)

    df = pd.DataFrame(all_rows)
    # column order exactly as in COLUMNS_DESCRIPTION
    col_order = [
        "report_date", "employee_id", "grade_num", "position_name", "unit_id_tree",
        "person_surname", "person_name", "person_patronimics", "gender", "age_y",
        "wrk_email", "ext_email", "employee_kipphn", "child_count", "family_status",
        "is_on_trial", "sber_los_cnt_days", "is_parental_leave", "all_skills",
        "date_since_salary_change_last", "po_i_pernr", "fp_res", "fp_comp",
        "full_oshs_name", "all_succesors", "children_gender", "children_years",
        "lang_with_level", "tribe_name", "cluster_name", "team_name",
        "tribe_code", "cluster_code", "team_code", "all_goals_desc",
        "mean_value_completion", "num_goals", "not_completed_goals", "risked_goals",
        "achievement_desc", "career_status", "university_name", "speciality_name",
        "date_finish_education", "lead_experience_years", "professionlevel_name",
        "vac_days", "lid_tribe_i_pernr", "lid_1_lvl_i_pernr", "lid_2_lvl_i_pernr",
        "lid_3_lvl_i_pernr", "lid_cluster_i_pernr", "it_lid_cluster_i_pernr",
        "cur_tribe_i_pernr",
    ]
    return df[col_order]


def _is_descendant(u: Unit, ancestor: Unit) -> bool:
    cur: Unit | None = u
    while cur is not None:
        if cur is ancestor: return True
        cur = cur.parent
    return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse, time
    p = argparse.ArgumentParser(description="Generate synthetic HR data.")
    p.add_argument("--n", type=int, default=20_000, help="employees per snapshot")
    p.add_argument("--months", type=int, default=6)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", type=str, default="sample_data.parquet")
    args = p.parse_args()

    t0 = time.time()
    df = generate_synthetic_hr(n_employees=args.n, n_months=args.months, seed=args.seed)
    print(f"Generated {len(df):,} rows × {len(df.columns)} cols in {time.time() - t0:.1f}s")
    df.to_parquet(args.out, index=False, compression="snappy")
    import os
    print(f"Wrote {args.out} ({os.path.getsize(args.out) / 1e6:.1f} MB)")
    # quick sanity stats
    it_share_snap0 = (df[df["report_date"] == df["report_date"].min()]["position_name"]
                      .str.contains("разработчик|Data|ML|DevOps|QA|архитектор|Product Owner|Scrum|кибербезопасности|SRE|системный аналитик",
                                    case=False, regex=True).mean())
    print(f"IT share (by position at first snapshot): {it_share_snap0:.1%}")
    print(df.head(3).T)
