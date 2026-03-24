from pathlib import Path
import json
import uuid


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "scripts" / "seed_data"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def id_() -> str:
    return str(uuid.uuid4())


def main() -> None:
    regions = [{"id": id_(), "name": f"Region {i}", "notes": ""} for i in range(1, 6)]
    bases = []
    units = []
    for i in range(15):
        region = regions[i % len(regions)]
        base_id = id_()
        bases.append({"id": base_id, "region_id": region["id"], "name": f"Base {i+1}", "address": "", "latitude": None, "longitude": None, "notes": ""})
    for i in range(50):
        base = bases[i % len(bases)]
        units.append({"id": id_(), "base_id": base["id"], "name": f"Unit {i+1}", "status": "uncontacted"})
    payloads = {
        "regions.json": regions,
        "bases.json": bases,
        "units.json": units,
    }
    for filename, payload in payloads.items():
        with open(OUT_DIR / filename, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
    print("Demo seed generated in scripts/seed_data")


if __name__ == "__main__":
    main()
