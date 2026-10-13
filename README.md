# ftx-schedules-db

> Schedules domain: schema, seed, roles and Flyway migrations

Part of **Futbolix**, the distributed system for reserving the four football courts of a
single sports facility. Governance and documentation live in
[`ftx-docs`](https://github.com/code-corhuila/ftx-docs).

## What this repository is (and what it is not)

Following **Annex J** of the course norm, Futbolix has **one PostgreSQL instance**, defined in
[`ftx-infra-postgres`](https://github.com/code-corhuila/ftx-infra-postgres) with its container
and its volume. This repository:

| Does | Does not |
|---|---|
| Own the structure of the `schedules` schema: tables, functions, triggers, indexes, seed, roles | Define a database container or a volume |
| Ship the migration runner (`deploy/compose.yml`) that applies its migrations to the single instance | Create login users or extensions (that is `ftx-infra-postgres`) |
| Prove in CI that the schema builds from scratch, reverts and builds again | Contain application code (that is `ftx-schedules-api`) |

## Structure

```
01_ddl/                     definition (DDL)
  01_schemas/  V001__create_schema_schedules.sql
  03_tables/   V002__create_court_schedule.sql
  07_functions/V003__create_function_set_updated_at.sql
  09_triggers/ V004__create_trigger_court_schedule_updated_at.sql
  10_indexes/  V005__create_indexes.sql
02_dml/00_inserts/          V006__seed_court_schedule.sql      (4 courts x 7 days)
03_dcl/                     access control (DCL)
  00_roles/    V007__create_roles.sql                          (schedules_reader, schedules_writer)
  01_grants/   V008__grants.sql                                (schedules_writer -> schedules_app)
04_tcl/                     reserved: transaction blocks, manual recoveries, release tags
05_rollbacks/               one U<n> per V<n>, same family path
deploy/compose.yml          migration runner only (schedules-db-migrate)
tests/verify.sql            post-migration checks
tests/rebuild.sh            rebuild check used by the CI
flyway.toml                 Flyway configuration (own schema and control table)
.github/workflows/db-ci.yml CI on every PR to develop and qa
```

Empty folders keep a `.gitkeep`, so the order of the families is fixed from day one.

## Data model

Table `schedules.court_schedule` — opening hours of each court per day of the week.

| Column | Type | Rule |
|---|---|---|
| `id` | `uuid` | `pk_court_schedule`, `gen_random_uuid()` |
| `court_id` | `uuid` | Court of the **courts** domain (`ftx-courts-db`). **No foreign key** (Annex J.3.4) |
| `day_of_week` | `text` | `chk_court_schedule_day_of_week`: `MON` … `SUN` (CHECK, never ENUM) |
| `opening_time` / `closing_time` | `time` | `chk_court_schedule_hours`: closes after it opens. `chk_court_schedule_whole_hours`: whole hours |
| `created_at` / `updated_at` | `timestamptz` | `updated_at` maintained by `trg_court_schedule_updated_at` |

Unique index `idx_court_schedule_court_id_day_of_week`: one schedule per court and day; it also
serves the availability lookup of HU-RES-001.

### Contract with ftx-courts-db

The seed uses these court ids. The courts seed in `ftx-courts-db` must insert the four courts
**with exactly these ids**:

| Court | id |
|---|---|
| 1 | `c0000000-0000-4000-8000-000000000001` |
| 2 | `c0000000-0000-4000-8000-000000000002` |
| 3 | `c0000000-0000-4000-8000-000000000003` |
| 4 | `c0000000-0000-4000-8000-000000000004` |

### Access (Annex J.7)

| Role | Kind | Can |
|---|---|---|
| `schedules_reader` | `NOLOGIN` | `SELECT` on `court_schedule` |
| `schedules_writer` | `NOLOGIN` | `SELECT, INSERT, UPDATE, DELETE` on `court_schedule`; never DDL |
| `schedules_app` | `LOGIN`, created by `ftx-infra-postgres` | receives `schedules_writer`; `ftx-schedules-api` connects with it |

`ftx-schedules-api` connects as `postgres://schedules_app:<secret>@postgres:5432/ftx` and never
with the administrator. No application role can read `flyway_schema_history`.

## How to run the migrations

From `ftx-infra-postgres`, with the repositories cloned as siblings:

```bash
docker network create platform                                          # once per machine
docker compose --env-file env/dev.env up -d --wait postgres             # the single instance
docker compose --env-file env/dev.env run --rm schedules-db-migrate     # apply what is pending
docker compose --env-file env/dev.env run --rm schedules-db-migrate     # again: "No migration necessary"
docker compose --env-file env/dev.env run --rm schedules-db-migrate info
docker compose --env-file env/dev.env run --rm schedules-db-migrate validate
```

`ftx-infra-postgres` must add `schedules_app` to its `postgres/init/01-instance.sh` and
`SCHEDULES_APP_PASSWORD` to its env files (Annex J.5.5).

## Rollback

Flyway Community does not revert. Each `V<n>` has its `U<n>` in `05_rollbacks/`, applied with
`psql` from the highest number to the lowest, after deleting `schedules.flyway_schema_history`
(Annex J.6). The CI does it on every Pull Request. In `qa` and `main` a mistake is fixed with a
**new** forward migration; the `U` scripts are used only in a recovery decided and recorded in
`04_tcl/01_manual_recoveries/`.

## Rules

- A migration that already ran in any environment is **never edited**: a fix is a new `V<n>`.
- The next migration takes the next number (`V009`), whatever its family.
- Every new `V<n>` comes with its `U<n>` and, if it adds a rule, a check in `tests/verify.sql`.
- In `qa` and `main`, never `docker compose down -v`: the volume is the history (Annex J.5.4).

## Branching

`develop`, `qa` and `main` accept no direct commits. Per user story:
`hu-<id>-dev → develop`, then `git cherry-pick -x` into `hu-<id>-qa → qa`, then into
`hu-<id>-release → release.2.x.x → main` with the instructor's approval and the tag `v2.x.x`.

## Credits

The table design, the court-id contract and the first checks come from the baseline branch
`chore/schedules-db-baseline` by Miguel Gómez. This version adapts it to Annex A (Flyway
families and rollbacks) and Annex J (single instance, own schema, own control table).
