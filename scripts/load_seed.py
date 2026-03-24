from pathlib import Path
import json
import os
import psycopg


ROOT = Path(__file__).resolve().parents[1]
SEED_DIR = ROOT / "scripts" / "seed_data"


def load_json(name: str):
    with open(SEED_DIR / name, "r", encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    conn_str = os.getenv("DATABASE_URL_SYNC", "postgresql://agent_tracker:agent_tracker@localhost:5432/agent_tracker")
    regions = load_json("regions.json")
    bases = load_json("bases.json")
    units = load_json("units.json")
    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            for r in regions:
                cur.execute("insert into regions (id, name, notes) values (%s,%s,%s) on conflict (id) do nothing", (r["id"], r["name"], r["notes"]))
            for b in bases:
                cur.execute(
                    "insert into bases (id, region_id, name, address, latitude, longitude, notes) values (%s,%s,%s,%s,%s,%s,%s) on conflict (id) do nothing",
                    (b["id"], b["region_id"], b["name"], b["address"], b["latitude"], b["longitude"], b["notes"]),
                )
            for u in units:
                cur.execute(
                    "insert into reserve_units (id, base_id, name, status) values (%s,%s,%s,%s) on conflict (id) do nothing",
                    (u["id"], u["base_id"], u["name"], u["status"]),
                )
        conn.commit()
    print("Seed loaded")


if __name__ == "__main__":
    main()
