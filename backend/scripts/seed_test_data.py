#!/usr/bin/env python3
"""
Seed test data from docs/US Army_all_states_in_one.xlsx

Inserts:
  • bases + reserve_units  — sampled from the Army Excel spreadsheet
                             (SAMPLE_PER_STATE per state, 48 states × 3 = 144 rows)
  • users                  — 5 agents + 1 manager with realistic fake data
  • user_state_licenses    — per-agent licensed states
  • unit_agents            — assigns units to agents whose licensed states match
  • briefs                 — mix of scheduled / outreach / completed with brief_units links
  • conversation_logs      — a few scheduling call notes tied to outreach briefs

Usage (from repo root):
    cd backend
    DATABASE_URL=postgresql+psycopg2://... python scripts/seed_test_data.py

    # or if .env is in backend/:
    python scripts/seed_test_data.py

Flags:
    --dry-run   Print what would be inserted without touching the DB
    --sample N  Units per state (default 3)

The script is idempotent: skips rows whose natural key already exists.
"""

import os
import random
import sys
import uuid
from collections import defaultdict
from datetime import date, time, timedelta
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from dotenv import load_dotenv
load_dotenv(BACKEND_DIR / ".env")

import openpyxl
import sqlalchemy as sa
from sqlalchemy import text

# ── Tunables ──────────────────────────────────────────────────────────────────

XLSX_PATH = REPO_ROOT / "docs" / "US Army_all_states_in_one.xlsx"
SAMPLE_PER_STATE = 3
RANDOM_SEED = 42   # reproducible picks

SKIP_STATES = {"Hawaii", "Alaska"}   # not in any Readiness Division

# ── Reference data ────────────────────────────────────────────────────────────

STATE_NAME_TO_CODE: dict[str, str] = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
    "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
    "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
    "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
    "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
    "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
    "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
    "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
    "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
    "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
    "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
    "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
    "Wisconsin": "WI", "Wyoming": "WY",
}

REGION_STATES: dict[str, set[str]] = {
    "63rd": {"CA", "NV", "AZ", "NM", "TX", "OK", "AR"},
    "81st": {"LA", "MS", "AL", "GA", "FL", "TN", "KY", "NC", "SC"},
    "88th": {"WA", "OR", "ID", "MT", "WY", "UT", "CO", "ND", "SD",
             "NE", "KS", "MO", "IA", "MN", "WI", "IL", "IN", "MI", "OH"},
    "99th": {"VA", "WV", "MD", "DE", "NJ", "PA", "NY", "CT",
             "RI", "MA", "VT", "NH", "ME", "DC"},
}

# ── Test agents ───────────────────────────────────────────────────────────────
# Each agent gets:
#   states  — licensed states used for unit_agents assignments
#   home    — address_state
#
# Mix of regions so briefs appear across the board.

TEST_AGENTS = [
    {
        "id": "director-chris-ktenas",
        "first_name": "Chris", "last_name": "Ktenas",
        "email": "chris@ktenas.cloud",
        "role": "director",
        "is_admin": True,
        "mobile_phone": None,
        "address_state": None,
        "ssli_agent_number": None,
        "rgli_agent_number": None,
        "states": [],
    },
    {
        "id": "agent-alex-rivera",
        "first_name": "Alex", "last_name": "Rivera",
        "email": "alex.rivera@test.example",
        "role": "agent",
        "mobile_phone": "619-555-0101",
        "address_state": "CA",
        "ssli_agent_number": "SSLI-1001",
        "rgli_agent_number": "RGLI-1001",
        "states": ["CA", "NV", "AZ"],       # 63rd
    },
    {
        "id": "agent-jordan-kim",
        "first_name": "Jordan", "last_name": "Kim",
        "email": "jordan.kim@test.example",
        "role": "agent",
        "mobile_phone": "713-555-0102",
        "address_state": "TX",
        "ssli_agent_number": "SSLI-1002",
        "rgli_agent_number": "RGLI-1002",
        "states": ["TX", "OK", "AR"],       # 63rd
    },
    {
        "id": "agent-sam-okafor",
        "first_name": "Sam", "last_name": "Okafor",
        "email": "sam.okafor@test.example",
        "role": "agent",
        "mobile_phone": "404-555-0103",
        "address_state": "GA",
        "ssli_agent_number": "SSLI-1003",
        "rgli_agent_number": None,
        "states": ["AL", "GA", "FL"],       # 81st
    },
    {
        "id": "agent-taylor-brooks",
        "first_name": "Taylor", "last_name": "Brooks",
        "email": "taylor.brooks@test.example",
        "role": "agent",
        "mobile_phone": "212-555-0104",
        "address_state": "NY",
        "ssli_agent_number": "SSLI-1004",
        "rgli_agent_number": "RGLI-1004",
        "states": ["NY", "CT", "MA", "RI"], # 99th
    },
    {
        "id": "agent-morgan-chen",
        "first_name": "Morgan", "last_name": "Chen",
        "email": "morgan.chen@test.example",
        "role": "agent",
        "mobile_phone": "312-555-0105",
        "address_state": "IL",
        "ssli_agent_number": "SSLI-1005",
        "rgli_agent_number": None,
        "states": ["IL", "OH", "IN", "MI"], # 88th
    },
    {
        "id": "manager-casey-williams",
        "first_name": "Casey", "last_name": "Williams",
        "email": "casey.williams@test.example",
        "role": "manager",
        "mobile_phone": "202-555-0200",
        "address_state": "VA",
        "ssli_agent_number": None,
        "rgli_agent_number": None,
        "states": [],
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def uid() -> str:
    return str(uuid.uuid4())


def state_to_region(state_code: str) -> str | None:
    for region_id, codes in REGION_STATES.items():
        if state_code in codes:
            return region_id
    return None


def parse_address(raw: str | None) -> tuple[str | None, str | None, str | None, str | None]:
    """
    Returns (building_name, address_street, address_city, address_zip).

    Handles the three comma-separated formats in the spreadsheet:
      2-part: "City, ST"
      4-part: "Building, Street, City, ST ZIP"   (most common)
      5-part: "Building, St, Bldg#, City, ST ZIP"
    """
    if not raw:
        return None, None, None, None

    parts = [p.strip() for p in raw.split(",")]
    last_tokens = parts[-1].strip().split()
    zip_code = last_tokens[1] if len(last_tokens) > 1 else None

    if len(parts) < 3:
        city = parts[0] if parts else None
        return None, None, city, zip_code

    building = parts[0]
    city = parts[-2]
    street = ", ".join(parts[1:-2]) or None
    return building, street, city, zip_code


# ── Load & sample spreadsheet ─────────────────────────────────────────────────

def load_sample(sample_per_state: int) -> list[dict]:
    wb = openpyxl.load_workbook(XLSX_PATH)
    ws = wb.active

    by_state: dict[str, list[tuple]] = defaultdict(list)
    for row in ws.iter_rows(min_row=2, values_only=True):
        state_name, unit_name, address, phone = row
        if state_name and state_name not in SKIP_STATES:
            by_state[state_name].append((unit_name, address, phone))

    records = []
    for state_name, rows in sorted(by_state.items()):
        state_code = STATE_NAME_TO_CODE.get(state_name)
        if not state_code:
            print(f"  [warn] unknown state: {state_name!r}")
            continue
        region_id = state_to_region(state_code)
        if not region_id:
            print(f"  [warn] {state_code} not in any region — skipping")
            continue

        for unit_name, address, phone in rows[:sample_per_state]:
            building, street, city, zip_code = parse_address(address)
            records.append({
                "state_code": state_code,
                "region_id": region_id,
                "unit_name": unit_name,
                "building_name": building,
                "address_street": street,
                "address_city": city,
                "address_zip": zip_code,
                "phone": phone,
            })

    return records


# ── Brief factory helpers ─────────────────────────────────────────────────────

TODAY = date.today()


def _future(days: int) -> date:
    return TODAY + timedelta(days=days)


def _past(days: int) -> date:
    return TODAY - timedelta(days=days)


def make_briefs(agent_units: dict[str, list[str]]) -> tuple[list[dict], list[dict]]:
    """
    Build brief rows and brief_units junction rows.

    agent_units: {agent_id: [unit_id, ...]}

    Returns (briefs_rows, brief_units_rows).

    Brief mix per agent (where they have units):
      • 1–2 scheduled  — future date, confirmation_obtained may be True/False
      • 1–2 outreach   — no confirmed date, agent is actively scheduling
      • 1   completed  — past date with actuals

    "Outreach" = status is 'outreach': brief exists, agent is calling/emailing to lock
    a date, but no brief_date confirmed yet.
    """
    rng = random.Random(RANDOM_SEED)
    briefs: list[dict] = []
    brief_units: list[dict] = []

    # Template data for realistic titles / notes
    _titles = [
        "SSLI Benefits Briefing",
        "Army Reserve Financial Readiness Brief",
        "Soldier Life Insurance Overview",
        "SGLI/SSLI Annual Review",
        "Reserve Component Benefits Brief",
    ]
    _notes_scheduled = [
        "POC confirmed; briefing room reserved.",
        "CO approved; expects 30–40 attendees.",
        "Logistics confirmed with S1.",
        "CO forwarded to XO for scheduling; room TBD.",
    ]
    _notes_outreach = [
        "Left voicemail for S1; awaiting callback.",
        "Email sent to unit admin; following up next week.",
        "Spoke with XO — awaiting CO approval to confirm date.",
        "Initial contact made; 1SG asked us to call back after drill weekend.",
        "Emailed POC 3×; no response yet. Will try direct call.",
    ]
    _notes_completed = [
        "Great turnout. Several applications submitted on-site.",
        "Small group but engaged. 2 apps completed.",
        "CO introduced us. Strong interest in RGLI.",
    ]

    agents_with_units = [(aid, units) for aid, units in agent_units.items() if units]

    for agent_id, units in agents_with_units:
        # ── Scheduled briefs (1–2 per agent) ─────────────────────────────────
        num_scheduled = rng.choice([1, 2])
        for i in range(num_scheduled):
            unit_id = rng.choice(units)
            brief_id = uid()
            days_out = rng.randint(14, 90)
            confirmed = rng.choice([True, False])
            pax = rng.choice([20, 25, 30, 35, 40])
            briefs.append({
                "id": brief_id,
                "assigned_agent_id": agent_id,
                "brief_title": rng.choice(_titles),
                "brief_date": _future(days_out).isoformat(),
                "start_time": rng.choice(["09:00", "10:00", "13:00", "14:00"]),
                "status": "scheduled",
                "confirmation_obtained": confirmed,
                "expected_pax": pax,
                "notes": rng.choice(_notes_scheduled),
            })
            brief_units.append({"brief_id": brief_id, "unit_id": unit_id})

        # ── Outreach briefs (1–2 per agent, actively scheduling) ─────────────
        num_outreach = rng.choice([1, 2])
        for _ in range(num_outreach):
            unit_id = rng.choice(units)
            brief_id = uid()
            briefs.append({
                "id": brief_id,
                "assigned_agent_id": agent_id,
                "brief_title": rng.choice(_titles),
                "brief_date": None,         # date not confirmed yet
                "start_time": None,
                "status": "outreach",
                "confirmation_obtained": False,
                "expected_pax": None,
                "notes": rng.choice(_notes_outreach),
            })
            brief_units.append({"brief_id": brief_id, "unit_id": unit_id})

        # ── Completed brief (1 per agent) ─────────────────────────────────────
        unit_id = rng.choice(units)
        brief_id = uid()
        days_ago = rng.randint(10, 120)
        actual_attendance = rng.randint(15, 45)
        final_apps = rng.randint(2, min(actual_attendance, 12))
        briefs.append({
            "id": brief_id,
            "assigned_agent_id": agent_id,
            "brief_title": rng.choice(_titles),
            "brief_date": _past(days_ago).isoformat(),
            "start_time": rng.choice(["09:00", "10:00", "13:00"]),
            "status": "completed",
            "confirmation_obtained": True,
            "expected_pax": actual_attendance + rng.randint(-5, 5),
            "actual_date": _past(days_ago).isoformat(),
            "actual_start_time": rng.choice(["09:05", "09:15", "10:03", "13:10"]),
            "actual_attendance": actual_attendance,
            "final_apps": final_apps,
            "notes": rng.choice(_notes_completed),
        })
        brief_units.append({"brief_id": brief_id, "unit_id": unit_id})

    return briefs, brief_units


# ── Main seed routine ─────────────────────────────────────────────────────────

def seed(database_url: str, sample_per_state: int, dry_run: bool = False) -> None:
    records = load_sample(sample_per_state)
    print(f"Loaded {len(records)} unit records from {XLSX_PATH.name}")
    print(f"Prepared {len(TEST_AGENTS)} test users "
          f"({sum(1 for a in TEST_AGENTS if a['role'] == 'agent')} agents, "
          f"{sum(1 for a in TEST_AGENTS if a['role'] == 'manager')} manager)")

    if dry_run:
        _dry_run_preview(records)
        return

    engine = sa.create_engine(database_url)

    with engine.begin() as conn:
        _seed_bases_and_units(conn, records)
        _seed_users(conn)
        _seed_unit_assignments(conn)
        _seed_briefs(conn)

    print("\nDone.")


# ── Section seeders ───────────────────────────────────────────────────────────

def _seed_bases_and_units(conn, records: list[dict]) -> None:
    print("\n── Bases & reserve_units ─────────────────────────────────────")

    existing_bases: set[str] = {
        r[0] for r in conn.execute(text("SELECT name FROM bases"))
    }
    existing_units: set[str] = {
        r[0] for r in conn.execute(text("SELECT name FROM reserve_units"))
    }

    # Deduplicate: same building + state → one base record, potentially many units
    seen_bases: dict[tuple, str] = {}  # (state, building_name) → base_id
    bases_to_insert: list[dict] = []
    units_to_insert: list[dict] = []

    for r in records:
        base_key = (r["state_code"], r["building_name"] or r["unit_name"])
        if base_key not in seen_bases:
            base_name = r["building_name"] or f"{r['unit_name']} (location)"
            if base_name not in existing_bases:
                base_id = uid()
                seen_bases[base_key] = base_id
                bases_to_insert.append({
                    "id": base_id,
                    "region_id": r["region_id"],
                    "state": r["state_code"],
                    "name": base_name,
                    "address_street": r["address_street"],
                    "address_city": r["address_city"],
                    "address_zip": r["address_zip"],
                })
            else:
                # base already exists — look up its id
                row = conn.execute(
                    text("SELECT id FROM bases WHERE name = :n"), {"n": base_name}
                ).fetchone()
                seen_bases[base_key] = row[0] if row else uid()

    if bases_to_insert:
        conn.execute(
            text("""
                INSERT INTO bases (id, region_id, state, name,
                                   address_street, address_city, address_zip)
                VALUES (:id, :region_id, :state, :name,
                        :address_street, :address_city, :address_zip)
            """),
            bases_to_insert,
        )
        print(f"  Inserted {len(bases_to_insert)} bases")
    else:
        print("  Bases: nothing new")

    for r in records:
        if r["unit_name"] in existing_units:
            continue
        base_key = (r["state_code"], r["building_name"] or r["unit_name"])
        base_id = seen_bases.get(base_key)
        if not base_id:
            continue
        units_to_insert.append({
            "id": uid(),
            "base_id": base_id,
            "name": r["unit_name"],
            "branch": "army",
            "phone": r["phone"],
            "crm_status": "uncontacted",
        })

    if units_to_insert:
        conn.execute(
            text("""
                INSERT INTO reserve_units (id, base_id, name, branch, phone, crm_status)
                VALUES (:id, :base_id, :name, :branch, :phone, :crm_status)
            """),
            units_to_insert,
        )
        print(f"  Inserted {len(units_to_insert)} reserve_units")
    else:
        print("  Reserve units: nothing new")


def _seed_users(conn) -> None:
    print("\n── Users & state licenses ───────────────────────────────────")

    existing_emails: set[str] = {
        r[0] for r in conn.execute(text("SELECT email FROM users"))
    }
    existing_licenses: set[tuple] = {
        (r[0], r[1]) for r in conn.execute(
            text("SELECT user_id, state_code FROM user_state_licenses")
        )
    }

    users_to_insert = []
    licenses_to_insert = []

    for agent in TEST_AGENTS:
        if agent["email"] not in existing_emails:
            users_to_insert.append({
                "id": agent["id"],
                "email": agent["email"],
                "first_name": agent["first_name"],
                "last_name": agent["last_name"],
                "role": agent["role"],
                "is_admin": agent.get("is_admin", False),
                "mobile_phone": agent.get("mobile_phone"),
                "address_state": agent.get("address_state"),
                "ssli_agent_number": agent.get("ssli_agent_number"),
                "rgli_agent_number": agent.get("rgli_agent_number"),
            })

        for state_code in agent.get("states", []):
            key = (agent["id"], state_code)
            if key not in existing_licenses:
                licenses_to_insert.append({"user_id": agent["id"], "state_code": state_code})

    if users_to_insert:
        conn.execute(
            text("""
                INSERT INTO users (id, email, first_name, last_name, role, is_admin,
                                   mobile_phone, address_state,
                                   ssli_agent_number, rgli_agent_number)
                VALUES (:id, :email, :first_name, :last_name, :role, :is_admin,
                        :mobile_phone, :address_state,
                        :ssli_agent_number, :rgli_agent_number)
            """),
            users_to_insert,
        )
        print(f"  Inserted {len(users_to_insert)} users")
    else:
        print("  Users: nothing new")

    if licenses_to_insert:
        conn.execute(
            text("""
                INSERT INTO user_state_licenses (user_id, state_code)
                VALUES (:user_id, :state_code)
            """),
            licenses_to_insert,
        )
        print(f"  Inserted {len(licenses_to_insert)} state licenses")
    else:
        print("  State licenses: nothing new")


def _seed_unit_assignments(conn) -> None:
    """Assign seeded units to agents whose licensed states match."""
    print("\n── Unit → agent assignments ──────────────────────────────────")

    # Build agent_id → licensed states map (only agents, not managers)
    agents_states: dict[str, list[str]] = {
        a["id"]: a["states"]
        for a in TEST_AGENTS if a["role"] == "agent" and a["states"]
    }

    existing_assignments: set[tuple] = {
        (r[0], r[1]) for r in conn.execute(
            text("SELECT unit_id, user_id FROM unit_agents")
        )
    }

    to_insert: list[dict] = []

    for agent_id, states in agents_states.items():
        if not states:
            continue
        placeholders = ", ".join(f":s{i}" for i in range(len(states)))
        params = {f"s{i}": s for i, s in enumerate(states)}
        rows = conn.execute(
            text(f"""
                SELECT ru.id
                FROM   reserve_units ru
                JOIN   bases b ON b.id = ru.base_id
                WHERE  b.state IN ({placeholders})
            """),
            params,
        ).fetchall()

        for (unit_id,) in rows:
            if (unit_id, agent_id) not in existing_assignments:
                to_insert.append({"unit_id": unit_id, "user_id": agent_id})
                existing_assignments.add((unit_id, agent_id))

    if to_insert:
        conn.execute(
            text("INSERT INTO unit_agents (unit_id, user_id) VALUES (:unit_id, :user_id)"),
            to_insert,
        )
        print(f"  Inserted {len(to_insert)} unit_agents rows")
    else:
        print("  Unit assignments: nothing new")


def _seed_briefs(conn) -> None:
    print("\n── Briefs ───────────────────────────────────────────────────")

    # Build {agent_id: [unit_id]} from what's actually in the DB
    agent_units: dict[str, list[str]] = defaultdict(list)
    rows = conn.execute(
        text("SELECT user_id, unit_id FROM unit_agents")
    ).fetchall()
    for user_id, unit_id in rows:
        agent_units[user_id].append(unit_id)

    # Only agents we just seeded (ignore pre-existing data)
    seeded_agent_ids = {a["id"] for a in TEST_AGENTS if a["role"] == "agent"}
    filtered = {aid: units for aid, units in agent_units.items() if aid in seeded_agent_ids}

    if not filtered:
        print("  No agent units found — skipping briefs")
        return

    briefs, brief_units = make_briefs(filtered)

    existing_brief_ids: set[str] = {
        r[0] for r in conn.execute(text("SELECT id FROM briefs"))
    }
    existing_brief_unit_pairs: set[tuple] = {
        (r[0], r[1]) for r in conn.execute(text("SELECT brief_id, unit_id FROM brief_units"))
    }

    # Separate briefs with/without actual_ fields to avoid column mismatch
    completed = [b for b in briefs if b["status"] == "completed"
                 and b["id"] not in existing_brief_ids]
    non_completed = [b for b in briefs if b["status"] != "completed"
                     and b["id"] not in existing_brief_ids]

    inserted_count = 0

    if non_completed:
        conn.execute(
            text("""
                INSERT INTO briefs
                    (id, assigned_agent_id, brief_title, brief_date, start_time,
                     status, confirmation_obtained, expected_pax, notes)
                VALUES
                    (:id, :assigned_agent_id, :brief_title, :brief_date, :start_time,
                     :status, :confirmation_obtained, :expected_pax, :notes)
            """),
            non_completed,
        )
        inserted_count += len(non_completed)

    if completed:
        conn.execute(
            text("""
                INSERT INTO briefs
                    (id, assigned_agent_id, brief_title, brief_date, start_time,
                     status, confirmation_obtained, expected_pax,
                     actual_date, actual_start_time, actual_attendance, final_apps,
                     notes)
                VALUES
                    (:id, :assigned_agent_id, :brief_title, :brief_date, :start_time,
                     :status, :confirmation_obtained, :expected_pax,
                     :actual_date, :actual_start_time, :actual_attendance, :final_apps,
                     :notes)
            """),
            completed,
        )
        inserted_count += len(completed)

    print(f"  Inserted {inserted_count} briefs  "
          f"({sum(1 for b in briefs if b['status'] == 'scheduled')} scheduled, "
          f"{sum(1 for b in briefs if b['status'] == 'outreach')} outreach, "
          f"{sum(1 for b in briefs if b['status'] == 'completed')} completed)")

    new_brief_units = [
        bu for bu in brief_units
        if (bu["brief_id"], bu["unit_id"]) not in existing_brief_unit_pairs
    ]
    if new_brief_units:
        conn.execute(
            text("INSERT INTO brief_units (brief_id, unit_id) VALUES (:brief_id, :unit_id)"),
            new_brief_units,
        )
        print(f"  Inserted {len(new_brief_units)} brief_units links")


# ── Dry-run preview ───────────────────────────────────────────────────────────

def _dry_run_preview(records: list[dict]) -> None:
    print("\n=== DRY RUN — unit sample (first 10) ===")
    for r in records[:10]:
        print(f"  [{r['region_id']}] {r['state_code']} | "
              f"{r['building_name'] or '(no building)'!r:40s} | "
              f"{r['unit_name'][:55]}")
    print(f"  ... {len(records) - 10} more units\n")

    print("=== Agents ===")
    for a in TEST_AGENTS:
        states = ", ".join(a["states"]) if a["states"] else "—"
        print(f"  [{a['role']:7s}] {a['first_name']} {a['last_name']:15s} "
              f"| {a['email']:38s} | licensed: {states}")

    print()
    print("=== Brief mix (per agent with units) ===")
    print("  Each agent → up to 2 scheduled + up to 2 outreach + 1 completed")

    # Show a sample of the make_briefs output with fake unit ids
    fake_units = {a["id"]: [uid(), uid(), uid()] for a in TEST_AGENTS if a["states"]}
    briefs, _ = make_briefs(fake_units)
    by_status: dict[str, int] = defaultdict(int)
    for b in briefs:
        by_status[b["status"]] += 1
    for status, count in sorted(by_status.items()):
        print(f"    {status:12s}: {count}")


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Seed test data from Army Excel spreadsheet"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview what would be inserted without touching the DB",
    )
    parser.add_argument(
        "--sample", type=int, default=SAMPLE_PER_STATE, metavar="N",
        help=f"Units to sample per state (default: {SAMPLE_PER_STATE})",
    )
    parser.add_argument(
        "--db", default=os.getenv("DATABASE_URL"), metavar="URL",
        help="SQLAlchemy DB URL (default: $DATABASE_URL from .env)",
    )
    args = parser.parse_args()

    if not args.dry_run and not args.db:
        print("Error: DATABASE_URL not set. Pass --db or set $DATABASE_URL in .env")
        sys.exit(1)

    seed(database_url=args.db or "", sample_per_state=args.sample, dry_run=args.dry_run)
