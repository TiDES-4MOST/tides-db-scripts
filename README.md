# tides-db-scripts
Initialisation scripts for the TiDES Postgres database.

## Scripts

### Active

- **`tides_unmanaged_tables.sql`** — The single consolidated script that creates all
  tables Django does **not** manage (`managed = False` in `models.py`). Must be run
  **after** `python manage.py migrate` so that `tom_targets_basetarget` already exists.
  Uses `CREATE TABLE IF NOT EXISTS` so it is safe to re-run.

### Deprecated (kept for reference)

- `tidestom_schema.sql` — Old full `pg_dump` including Django/TOM/auth tables. **Do not
  use** — these tables are now created by Django migrations.
- `tides_merged_schema.sql` — Predecessor of `tides_unmanaged_tables.sql`. Uses
  `DROP TABLE` which is destructive.
- `create_tables_tides.sql` — Original standalone TiDES schema (different column types,
  extra ancillary tables). Superseded.

## Fresh-build order (docker-compose-local)

1. Postgres starts (`database` service).
2. `migrate` service runs `python manage.py migrate` → creates all Django/TOM-managed
   tables plus custom_code managed tables (tags, tag proposals, etc.).
3. `init-gatekeeper` service runs `tides_unmanaged_tables.sql` → creates the
   TiDES-specific tables that interact with tides-master.
4. `web` service starts.
