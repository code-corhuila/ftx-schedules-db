# ftx-schedules-db

> Schedules bounded context: database (schema, seeds, migrations)

Part of the **Futbolix** distributed system: football court reservations for a single sports
facility with four fixed courts.
Governance and documentation live in [`ftx-docs`](https://github.com/code-corhuila/ftx-docs).

## What this repository contains

The opening hours of each court, per day of the week, as versioned Flyway migrations. It holds
no application code: `ftx-schedules-api` reads this database, and `ftx-infra` runs the migrations
before the API starts.

```
db/migration/
├── V001__create_schedules_table.sql   table, rules, updated_at trigger
└── V002__seed_court_schedules.sql     4 courts x 7 days, 06:00-22:00
tests/verify.sql                       post-migration checks, run by CI
.github/workflows/migrations.yml       CI: migrate, re-run, validate, verify
Dockerfile                             Flyway image (pinned version) with the migrations inside
docker-compose.yml                     standalone database + migration + checks
.env.example                           local values; copy to .env
```

## Data model

| Column | Type | Rule |
|---|---|---|
| `id` | UUID | Primary key, `gen_random_uuid()` |
| `court_id` | UUID | Reference to `courts.id` in `ftx-courts-db`. **No foreign key**: it lives in another database |
| `day_of_week` | VARCHAR(3) | `MON` … `SUN` |
| `opening_time` | TIME | Whole hour |
| `closing_time` | TIME | Whole hour, later than `opening_time` |
| `created_at` / `updated_at` | TIMESTAMPTZ | `updated_at` is maintained by a trigger |

One schedule per court and day (unique constraint `uq_schedules_court_day`). Tables live in the `schedules`
schema, as does Flyway's `flyway_schema_history`.

### Contract with ftx-courts-db

The seed uses these court ids. The courts seed in `ftx-courts-db` **must use the same four ids**,
inserted explicitly (not generated). `tests/verify.sql` fails if any schedule points to another id:

| Court | id |
|---|---|
| 1 | `c0000000-0000-4000-8000-000000000001` |
| 2 | `c0000000-0000-4000-8000-000000000002` |
| 3 | `c0000000-0000-4000-8000-000000000003` |
| 4 | `c0000000-0000-4000-8000-000000000004` |

## Run it locally

Requires Docker Desktop.

```bash
cp .env.example .env                              # Windows: copy .env.example .env
docker compose up -d --wait schedules-db          # PostgreSQL 15, healthy
docker compose run --rm --build schedules-migrate # apply migrations
docker compose run --rm schedules-verify          # every line must say OK
docker compose down -v                            # stop and delete the data
```

Connect with any client at `localhost:${SCHEDULES_DB_HOST_PORT}` using the values in `.env`.

## How ftx-infra uses it

Migrations run as a one-shot container between the database and the API:

```yaml
schedules-migrate:
  build: ../ftx-schedules-db            # or an image published from this repo
  environment:
    FLYWAY_URL: jdbc:postgresql://schedules-db:5432/${SCHEDULES_DB_NAME}
    FLYWAY_USER: ${SCHEDULES_DB_USER}
    FLYWAY_PASSWORD: ${SCHEDULES_DB_PASSWORD}
  depends_on:
    schedules-db:
      condition: service_healthy

schedules-api:
  depends_on:
    schedules-migrate:
      condition: service_completed_successfully
```

`ftx-schedules-api` must therefore **not** run Flyway itself (`spring.flyway.enabled=false`) and
connects with `currentSchema=schedules` in its JDBC URL.

## Migration rules

- A migration that has run in any environment is **never edited**. Changes go in a new file.
- Naming: `V{NNN}__{snake_case_description}.sql`, numbered in sequence.
- Every new rule gets a check in `tests/verify.sql` in the same Pull Request.
- CI (`.github/workflows/migrations.yml`, job `migrations`) must be green before merging. It runs a clean
  migration, a second run that must apply nothing, `flyway validate`, and `tests/verify.sql`.

## Branching

Three permanent branches. **None of them accepts a direct commit**: you enter through a child
branch and leave through a Pull Request.

```
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  qa/...
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another.

`main` requires **1 approval from `ariel5253`**. On `develop` the required check is the
`migrations` CI job.

Full policy: `00-governance/branching-policy.md` in `ftx-docs`.

## Open items

- The 06:00-22:00 hours come from the approved mockup. Pending confirmation by the Product Owner.
- `ftx-docs` models schedules inside court-service (`06-data/models.md`). This repository
  separates them; the split must be recorded in an ADR and in `06-data/models.md`.
