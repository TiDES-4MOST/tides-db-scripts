-- tides_unmanaged_tables.sql
-- Creates all tables that Django does NOT manage (managed = False in models.py).
-- Must be run AFTER Django migrate so that tom_targets_basetarget exists.
--
-- Tables created here:
--   tides_class, tides_class_subclass, tides_cand,
--   human_classifications,
--   pipeline_classification_global, pipeline_classification_superfit,
--   pipeline_classification_snid, pipeline_classification_dash,
--   pipeline_classification_ed,
--   tides_spec

SET client_min_messages TO WARNING;
SET search_path = public;

BEGIN;

-- ============================================================
-- Classification lookup tables
-- ============================================================
CREATE TABLE IF NOT EXISTS tides_class (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tides_class_name ON tides_class(name);

CREATE TABLE IF NOT EXISTS tides_class_subclass (
  id SERIAL PRIMARY KEY,
  main_class_id INTEGER NOT NULL
    REFERENCES tides_class(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  sub_class VARCHAR(100) NOT NULL,
  UNIQUE (main_class_id, sub_class)
);
CREATE INDEX IF NOT EXISTS idx_tides_class_sub_main ON tides_class_subclass(main_class_id);

-- ============================================================
-- Core TiDES target table  (models.TidesTarget, managed=False)
-- tides_id is INTEGER FK to tom_targets_basetarget(id)
-- ============================================================
CREATE TABLE IF NOT EXISTS tides_cand (
  tides_id INTEGER PRIMARY KEY
    REFERENCES tom_targets_basetarget(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  lsst_sn_id BIGINT UNIQUE,
  lsst_host_id BIGINT,
  last_date TIMESTAMPTZ,
  classification VARCHAR(50),
  z_best DOUBLE PRECISION,
  z_sn DOUBLE PRECISION,
  z_gal DOUBLE PRECISION,
  z_source VARCHAR(50),
  confidence DOUBLE PRECISION,
  released BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_tides_cand_lsst_sn_id ON tides_cand(lsst_sn_id);

-- ============================================================
-- Human classifications  (models.HumanClassification, managed=False)
-- ============================================================
CREATE TABLE IF NOT EXISTS human_classifications (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  obs_id INTEGER,
  person_id INTEGER
    REFERENCES auth_user(id)
    ON DELETE SET NULL,
  sn_type VARCHAR(50) NOT NULL,
  sn_z DOUBLE PRECISION,
  phase DOUBLE PRECISION,
  host_z DOUBLE PRECISION,
  sn_subtype VARCHAR(50),
  comments TEXT,
  created TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_human_cls_tides_id ON human_classifications(tides_id);
CREATE INDEX IF NOT EXISTS idx_human_cls_created ON human_classifications(created DESC);

-- ============================================================
-- Pipeline classifications  (all managed=False)
-- ============================================================

-- Global
CREATE TABLE IF NOT EXISTS pipeline_classification_global (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  tides_specid BIGINT UNIQUE,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20),
  notes TEXT,
  phase DOUBLE PRECISION,
  z DOUBLE PRECISION,
  zerr DOUBLE PRECISION
);
CREATE INDEX IF NOT EXISTS idx_pclass_global_tides ON pipeline_classification_global(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_global_prob ON pipeline_classification_global(probability DESC);
CREATE INDEX IF NOT EXISTS idx_pclass_global_specid ON pipeline_classification_global(tides_specid);

-- Superfit
CREATE TABLE IF NOT EXISTS pipeline_classification_superfit (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  tides_specid BIGINT,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20),
  z DOUBLE PRECISION
);
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_tides ON pipeline_classification_superfit(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_prob ON pipeline_classification_superfit(probability DESC);
CREATE INDEX IF NOT EXISTS idx_pclass_superfit_specid ON pipeline_classification_superfit(tides_specid);

-- SNID
CREATE TABLE IF NOT EXISTS pipeline_classification_snid (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  tides_specid BIGINT,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20),
  phase DOUBLE PRECISION,
  z DOUBLE PRECISION,
  zerr DOUBLE PRECISION,
  results_file TEXT
);
CREATE INDEX IF NOT EXISTS idx_pclass_snid_tides ON pipeline_classification_snid(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_snid_prob ON pipeline_classification_snid(probability DESC);
CREATE INDEX IF NOT EXISTS idx_pclass_snid_specid ON pipeline_classification_snid(tides_specid);

-- DASH
CREATE TABLE IF NOT EXISTS pipeline_classification_dash (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  tides_specid BIGINT,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20),
  z DOUBLE PRECISION
);
CREATE INDEX IF NOT EXISTS idx_pclass_dash_tides ON pipeline_classification_dash(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_dash_prob ON pipeline_classification_dash(probability DESC);
CREATE INDEX IF NOT EXISTS idx_pclass_dash_specid ON pipeline_classification_dash(tides_specid);

-- Ed
CREATE TABLE IF NOT EXISTS pipeline_classification_ed (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER NOT NULL
    REFERENCES tides_cand(tides_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  tides_specid BIGINT,
  sn_type VARCHAR(50),
  probability DOUBLE PRECISION,
  version VARCHAR(20)
);
CREATE INDEX IF NOT EXISTS idx_pclass_ed_tides ON pipeline_classification_ed(tides_id);
CREATE INDEX IF NOT EXISTS idx_pclass_ed_prob ON pipeline_classification_ed(probability DESC);
CREATE INDEX IF NOT EXISTS idx_pclass_ed_specid ON pipeline_classification_ed(tides_specid);

-- ============================================================
-- Spectra  (models.TidesSpec, managed=False)
-- tides_specid is the PRIMARY KEY (replaces old qmost_id)
-- ============================================================
CREATE TABLE IF NOT EXISTS tides_spec (
  tides_specid BIGINT PRIMARY KEY,
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
