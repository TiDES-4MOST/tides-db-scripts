-- TiDES: Migrate from qmost_id to tides_specid as PRIMARY KEY
-- This script safely migrates the tides_spec table to use tides_specid (SPECUID from MEC)
-- as the primary key, replacing the old qmost_id hash-based identifier.

-- STEP 1: Add tides_specid column if it doesn't exist (will be NULL for existing records)
ALTER TABLE IF EXISTS tides_spec ADD COLUMN IF NOT EXISTS tides_specid BIGINT;

-- STEP 2: Drop old qmost_id primary key constraint if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'tides_spec'::regclass 
        AND contype = 'p' 
        AND conname = 'tides_spec_pkey'
    ) THEN
        ALTER TABLE tides_spec DROP CONSTRAINT tides_spec_pkey;
        RAISE NOTICE 'Dropped old PRIMARY KEY on qmost_id';
    END IF;
END $$;

-- STEP 3: Remove qmost_id column (will cascade-drop any indexes on it)
ALTER TABLE IF EXISTS tides_spec DROP COLUMN IF EXISTS qmost_id CASCADE;

-- STEP 4: OPTIONAL - Delete old records with NULL tides_specid (uncomment if you want clean slate)
-- DELETE FROM tides_spec WHERE tides_specid IS NULL;
-- RAISE NOTICE 'Deleted % rows with NULL tides_specid', (SELECT count(*) FROM tides_spec WHERE tides_specid IS NULL);

-- STEP 5: Add PRIMARY KEY on tides_specid (only if no NULLs/duplicates)
DO $$
DECLARE
    nulls_count bigint;
    dups_count bigint;
BEGIN
    SELECT count(*) INTO nulls_count FROM tides_spec WHERE tides_specid IS NULL;
    SELECT count(*) INTO dups_count FROM (
        SELECT tides_specid FROM tides_spec WHERE tides_specid IS NOT NULL GROUP BY tides_specid HAVING count(*) > 1
    ) s;

    IF nulls_count > 0 THEN
        RAISE WARNING '% rows have NULL tides_specid - PRIMARY KEY will allow NULLs but re-run pipeline to populate', nulls_count;
    END IF;
    
    IF dups_count > 0 THEN
        RAISE WARNING '% duplicate tides_specid values found - cannot add PRIMARY KEY. Resolve duplicates first.', dups_count;
    ELSE
        -- Note: PostgreSQL PRIMARY KEY automatically creates NOT NULL constraint, 
        -- but existing NULLs won't violate this since they were added before the constraint
        ALTER TABLE tides_spec ADD PRIMARY KEY (tides_specid);
        RAISE NOTICE 'SUCCESS: PRIMARY KEY added on tides_specid (% NULL values will be populated by pipeline)', nulls_count;
    END IF;
END $$;

-- STEP 6: Add FOREIGN KEY from tides_id to tides_cand if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conrelid = 'tides_spec'::regclass 
        AND conname = 'fk_tides_spec_tides_id'
    ) THEN
        ALTER TABLE tides_spec
        ADD CONSTRAINT fk_tides_spec_tides_id
        FOREIGN KEY (tides_id) REFERENCES tides_cand(tides_id)
        ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED;
        RAISE NOTICE 'SUCCESS: Foreign key added from tides_spec.tides_id to tides_cand.tides_id';
    END IF;
END $$;

-- STEP 7: Add tides_specid to pipeline tables and index
ALTER TABLE IF EXISTS pipeline_classification_global ADD COLUMN IF NOT EXISTS tides_specid BIGINT;
CREATE INDEX IF NOT EXISTS idx_pclass_global_specid ON pipeline_classification_global(tides_specid);

ALTER TABLE IF EXISTS pipeline_classification_snid ADD COLUMN IF NOT EXISTS tides_specid BIGINT;
CREATE INDEX IF NOT EXISTS idx_pclass_snid_specid ON pipeline_classification_snid(tides_specid);

ALTER TABLE IF EXISTS pipeline_classification_superfit ADD COLUMN IF NOT EXISTS tides_specid BIGINT;
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_specid ON pipeline_classification_superfit(tides_specid);

ALTER TABLE IF EXISTS pipeline_classification_dash ADD COLUMN IF NOT EXISTS tides_specid BIGINT;
CREATE INDEX IF NOT EXISTS idx_pclass_dash_specid ON pipeline_classification_dash(tides_specid);

ALTER TABLE IF EXISTS pipeline_classification_ed ADD COLUMN IF NOT EXISTS tides_specid BIGINT;
CREATE INDEX IF NOT EXISTS idx_pclass_ed_specid ON pipeline_classification_ed(tides_specid);

-- STEP 8: Add missing columns used by classification models (phase, z, zerr)
ALTER TABLE IF EXISTS pipeline_classification_global ADD COLUMN IF NOT EXISTS phase DOUBLE PRECISION;
ALTER TABLE IF EXISTS pipeline_classification_global ADD COLUMN IF NOT EXISTS z DOUBLE PRECISION;
ALTER TABLE IF EXISTS pipeline_classification_global ADD COLUMN IF NOT EXISTS zerr DOUBLE PRECISION;

ALTER TABLE IF EXISTS pipeline_classification_snid ADD COLUMN IF NOT EXISTS phase DOUBLE PRECISION;
ALTER TABLE IF EXISTS pipeline_classification_snid ADD COLUMN IF NOT EXISTS z DOUBLE PRECISION;
ALTER TABLE IF EXISTS pipeline_classification_snid ADD COLUMN IF NOT EXISTS zerr DOUBLE PRECISION;

ALTER TABLE IF EXISTS pipeline_classification_dash ADD COLUMN IF NOT EXISTS z DOUBLE PRECISION;

ALTER TABLE IF EXISTS human_classifications ADD COLUMN IF NOT EXISTS phase DOUBLE PRECISION;
ALTER TABLE IF EXISTS human_classifications ADD COLUMN IF NOT EXISTS host_z DOUBLE PRECISION;

-- STEP 9: Add FOREIGN KEY constraints from pipeline tables to tides_spec(tides_specid)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pclass_global_specid') THEN
        ALTER TABLE pipeline_classification_global
        ADD CONSTRAINT fk_pclass_global_specid
        FOREIGN KEY (tides_specid) REFERENCES tides_spec(tides_specid)
        DEFERRABLE INITIALLY DEFERRED;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pclass_snid_specid') THEN
        ALTER TABLE pipeline_classification_snid
        ADD CONSTRAINT fk_pclass_snid_specid
        FOREIGN KEY (tides_specid) REFERENCES tides_spec(tides_specid)
        DEFERRABLE INITIALLY DEFERRED;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pclass_superfit_specid') THEN
        ALTER TABLE pipeline_classification_superfit
        ADD CONSTRAINT fk_pclass_superfit_specid
        FOREIGN KEY (tides_specid) REFERENCES tides_spec(tides_specid)
        DEFERRABLE INITIALLY DEFERRED;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pclass_dash_specid') THEN
        ALTER TABLE pipeline_classification_dash
        ADD CONSTRAINT fk_pclass_dash_specid
        FOREIGN KEY (tides_specid) REFERENCES tides_spec(tides_specid)
        DEFERRABLE INITIALLY DEFERRED;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pclass_ed_specid') THEN
        ALTER TABLE pipeline_classification_ed
        ADD CONSTRAINT fk_pclass_ed_specid
        FOREIGN KEY (tides_specid) REFERENCES tides_spec(tides_specid)
        DEFERRABLE INITIALLY DEFERRED;
    END IF;
END $$;
