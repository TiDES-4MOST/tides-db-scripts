# TiDES Schema Migration: qmost_id → tides_specid

## Overview

This migration replaces the `qmost_id` (hash-based identifier) with `tides_specid` (actual SPECUID from MEC FIBMETATAB) as the PRIMARY KEY in the `tides_spec` table.

## What Changes

**Before:**
- `qmost_id` (BIGINT, PRIMARY KEY) - hash of `tides_id + filename`
- `tides_id` (BIGINT) - reference to tides_cand

**After:**
- `tides_specid` (BIGINT, PRIMARY KEY) - actual SPECUID from MEC or generated for stacked spectra
- `tides_id` (BIGINT, FOREIGN KEY) - references `tides_cand(tides_id)`

## Prerequisites

1. **Backup your database** before running this migration
2. Ensure all recent spectra have `TIDES_SPECID` in their `additional_info` JSON
3. Have PostgreSQL client tools installed (`psql`)

## How to Run

### Option 1: Direct psql (Recommended for Dev/Test)

```bash
# From the tides-db-scripts directory
cd /Users/pwise/4MOST/tides/tides-db-scripts

# Run against your database
psql -h <hostname> -U <username> -d <database> -f alters_tides_specid.sql

# Example for local development:
psql -h localhost -U tidestom_user -d tidestom -f alters_tides_specid.sql

# Example for tides database:
psql -h localhost -U tides_user -d tides -f alters_tides_specid.sql
```

### Option 2: Via Docker (if using containerized DB)

```bash
# Copy script into container
docker cp alters_tides_specid.sql <container_name>:/tmp/

# Execute inside container
docker exec -it <container_name> psql -U <username> -d <database> -f /tmp/alters_tides_specid.sql

# Example:
docker cp alters_tides_specid.sql tidestom_db:/tmp/
docker exec -it tidestom_db psql -U tidestom_user -d tidestom -f /tmp/alters_tides_specid.sql
```

### Option 3: Django Management Command (Future)

```bash
# If you create a Django migration wrapper
python manage.py migrate_to_tides_specid
```

## Migration Steps (What the Script Does)

1. **Adds `tides_specid` column** to `tides_spec` (if not exists)
2. **Backfills `tides_specid`** from `additional_info->>'TIDES_SPECID'` for existing rows
3. **Drops old PRIMARY KEY** constraint on `qmost_id`
4. **Removes `qmost_id` column** (CASCADE drops related indexes)
5. **Adds PRIMARY KEY** on `tides_specid` (with safety checks)
6. **Adds FOREIGN KEY** from `tides_id` to `tides_cand(tides_id)`
7. **Updates pipeline tables** to include `tides_specid` columns
8. **Adds missing columns** (phase, z, zerr) for classifiers
9. **Adds FOREIGN KEY constraints** from pipeline tables to `tides_spec(tides_specid)`

## Safety Features

- ✅ **Idempotent**: Can be run multiple times safely
- ✅ **NULL checks**: Won't add PRIMARY KEY if NULL values exist
- ✅ **Duplicate checks**: Won't add PRIMARY KEY if duplicates exist
- ✅ **Conditional drops**: Only drops constraints/columns if they exist
- ✅ **DEFERRABLE constraints**: Foreign keys deferred to end of transaction

## Post-Migration Verification

```sql
-- Check PRIMARY KEY is on tides_specid
SELECT conname, contype, conkey 
FROM pg_constraint 
WHERE conrelid = 'tides_spec'::regclass AND contype = 'p';
-- Expected: PRIMARY KEY on column tides_specid

-- Check FOREIGN KEY to tides_cand exists
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'tides_spec'::regclass 
  AND conname = 'fk_tides_spec_tides_id';
-- Expected: 1 row

-- Check for NULL tides_specid values (should be 0)
SELECT count(*) FROM tides_spec WHERE tides_specid IS NULL;
-- Expected: 0

-- Check for duplicate tides_specid values (should be 0)
SELECT tides_specid, count(*) 
FROM tides_spec 
GROUP BY tides_specid 
HAVING count(*) > 1;
-- Expected: 0 rows

-- Verify pipeline tables have tides_specid column
\d pipeline_classification_snid
-- Should show tides_specid column with index and FK constraint
```

## Rollback (If Needed)

If you need to rollback (before committing transaction):

```sql
ROLLBACK;
```

If already committed, you'll need to:
1. Restore from backup
2. Or manually recreate `qmost_id` column and recompute values

## Troubleshooting

### Issue: "NULL tides_specid values found"

**Solution**: Backfill missing values:
```sql
UPDATE tides_spec 
SET tides_specid = (additional_info->>'TIDES_SPECID')::bigint
WHERE tides_specid IS NULL 
  AND additional_info->>'TIDES_SPECID' IS NOT NULL;

-- For truly missing values, you may need to reprocess those spectra
```

### Issue: "Duplicate tides_specid values"

**Solution**: Identify and resolve duplicates:
```sql
-- Find duplicates
SELECT tides_specid, count(*), array_agg(tides_id) 
FROM tides_spec 
GROUP BY tides_specid 
HAVING count(*) > 1;

-- Decide which to keep, then delete duplicates
-- (This requires manual intervention based on your data)
```

### Issue: "FOREIGN KEY constraint fails"

**Solution**: Ensure all `tides_id` values exist in `tides_cand`:
```sql
-- Find orphaned tides_id values
SELECT DISTINCT tides_id 
FROM tides_spec 
WHERE tides_id NOT IN (SELECT tides_id FROM tides_cand);

-- Add missing entries to tides_cand
INSERT INTO tides_cand (tides_id) 
SELECT DISTINCT tides_id 
FROM tides_spec 
WHERE tides_id NOT IN (SELECT tides_id FROM tides_cand)
ON CONFLICT (tides_id) DO NOTHING;
```

## After Migration

1. Update any queries/views that reference `qmost_id` to use `tides_specid`
2. Restart the ingestion pipeline to use new schema
3. Test classification pipeline with new `tides_specid` FK relationships
4. Monitor logs for any migration-related issues

## Questions?

Contact the TiDES pipeline team or check the project documentation.
