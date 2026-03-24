# Agent Tracker v2.0 - Seed Data Strategy

## Source Inputs

- `docs/US Army_all_states_in_one.xlsx` (partial source)
- Existing v2.0 conceptual model in HTML doc
- Manually curated region mapping table

## Transformation Plan

1. Read workbook sheets and infer canonical columns.
2. Normalize text (trim, uppercase state code, standard phone/email formats).
3. Deduplicate bases by normalized name + address.
4. Map each base to region via state-to-region mapping.
5. Build reserve units linked to base IDs.
6. Flag rows requiring manual review (missing base/unit names, invalid state).

## Expected Deliverables

- `seed/seed_regions.json`
- `seed/seed_bases.json`
- `seed/seed_reserve_units.json`
- `seed/seed_users.json`
- `seed/seed_contacts.json`
- `seed/seed_briefs.json`
- `seed/seed_conversations.json`
- `seed/import_errors.csv`

## Demo Seed Targets

- 5 regions
- 15 bases
- 50 reserve units
- 10 users
- 30 contacts
- 20 conversations
- 15 briefs

## Import Pipeline (Python)

- `scripts/import_excel.py` reads XLSX.
- `scripts/transform_seed.py` outputs normalized JSON.
- `scripts/load_seed.py` inserts into PostgreSQL in dependency order.

## Validation Rules

- Every base must map to region.
- Every reserve unit must map to base.
- Date fields must be parseable ISO or known source format.
- Reject invalid email/phone into review queue, do not fail entire batch.
