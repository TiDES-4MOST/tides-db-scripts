-- TiDES + TOM merged schema for remote Postgres
-- Prereq: run Django/TOM migrations to create TOM tables (e.g., tom_targets_basetarget)

SET client_min_messages TO WARNING;
SET search_path = public;

BEGIN;

-- Drop legacy custom_code tables that duplicate functionality (optional)
-- Uncomment if you want to remove the older Django-managed tables:
-- DROP TABLE IF EXISTS custom_code_humantidesclasssubmission CASCADE;
-- DROP TABLE IF EXISTS custom_code_tidestarget CASCADE;

-- Classification master tables used by forms/views
DROP TABLE IF EXISTS tides_class_subclass CASCADE;
DROP TABLE IF EXISTS tides_class CASCADE;

CREATE TABLE tides_class (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tides_class_name ON tides_class(name);

CREATE TABLE tides_class_subclass (
  id SERIAL PRIMARY KEY,
  main_class_id INTEGER NOT NULL
    REFERENCES tides_class(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sub_class VARCHAR(100) NOT NULL,
  UNIQUE (main_class_id, sub_class)
);
CREATE INDEX IF NOT EXISTS idx_tides_class_sub_main ON tides_class_subclass(main_class_id);

-- Core TiDES target table mapped from models.TidesTarget (managed=False)
-- IMPORTANT: tides_id is INTEGER to FK tom_targets_basetarget(id)
DROP TABLE IF EXISTS tides_cand CASCADE;
CREATE TABLE tides_cand (
  tides_id INTEGER PRIMARY KEY
    REFERENCES tom_targets_basetarget(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  -- Optional TiDES columns used in your codebase
  lsst_sn_id BIGINT UNIQUE,
  lsst_host_id BIGINT,
  last_date TIMESTAMPTZ,
  classification VARCHAR(50),
  z_best DOUBLE PRECISION,
  z_sn DOUBLE PRECISION,
  z_gal DOUBLE PRECISION,
  z_source VARCHAR(50),
  confidence DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS idx_tides_cand_lsst_sn_id ON tides_cand(lsst_sn_id);

-- Human classifications (remote, used by views)
-- Matches: HumanClassification model (unmanaged)
DROP TABLE IF EXISTS human_classifications CASCADE;
CREATE TABLE human_classifications (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  obs_id INTEGER,
  person_id INTEGER,
  sn_type VARCHAR(50),
  sn_z DOUBLE PRECISION,
  sn_subtype VARCHAR(50),
  comments TEXT,
  created TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_human_cls_tides_id ON human_classifications(tides_id);
CREATE INDEX IF NOT EXISTS idx_human_cls_created ON human_classifications(created DESC);

-- Pipeline classifications (remote, used by views/properties)
-- Global “best” table
DROP TABLE IF EXISTS pipeline_classification_global CASCADE;
CREATE TABLE pipeline_classification_global (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20),
  notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_pclass_global_tides ON pipeline_classification_global(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_global_prob ON pipeline_classification_global(probability DESC);

-- Per-pipeline tables (present in your scripts and referenced in code)
DROP TABLE IF EXISTS pipeline_classification_ed CASCADE;
CREATE TABLE pipeline_classification_ed (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_pclass_ed_tides ON pipeline_classification_ed(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_ed_prob ON pipeline_classification_ed(probability DESC);

-- Optional: add other pipelines you use in code (superfit, snid, dash)
DROP TABLE IF EXISTS pipeline_classification_superfit CASCADE;
CREATE TABLE pipeline_classification_superfit (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_tides ON pipeline_classification_superfit(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_prob ON pipeline_classification_superfit(probability DESC);

DROP TABLE IF EXISTS pipeline_classification_snid CASCADE;
CREATE TABLE pipeline_classification_snid (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_pclass_snid_tides ON pipeline_classification_snid(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_snid_prob ON pipeline_classification_snid(probability DESC);

DROP TABLE IF EXISTS pipeline_classification_dash CASCADE;
CREATE TABLE pipeline_classification_dash (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_pclass_dash_tides ON pipeline_classification_dash(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_dash_prob ON pipeline_classification_dash(probability DESC);

-- Spectra table used by your code (TidesSpec)
DROP TABLE IF EXISTS tides_spec CASCADE;
CREATE TABLE tides_spec (
  qmost_id BIGINT PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sn_type VARCHAR(50),
  obs_date TIMESTAMPTZ,
  obs_mjd DOUBLE PRECISION,
  snr DOUBLE PRECISION,
  seeing DOUBLE PRECISION,
  sky_brightness DOUBLE PRECISION,
  filepath TEXT,
  version INTEGER,
  additional_info JSONB
);
CREATE INDEX IF NOT EXISTS idx_tides_spec_tides ON tides_spec(tides_id);
CREATE INDEX IF NOT EXISTS idx_tides_spec_obsdate ON tides_spec(obs_date DESC);

COMMIT;

-- Notes:
-- 1) tom_targets_basetarget is created by TOM migrations; do not create it here.
-- 2) tides_id type is INTEGER to match tom_targets_basetarget(id).
-- 3) If your existing tides_cand had BIGINT tides_id, migrate IDs or create a mapping.
-- 4) Populate tides_cand.tides_id with matching TOM target IDs for TidesTarget parent_link.