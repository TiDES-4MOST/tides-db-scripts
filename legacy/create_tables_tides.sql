-- PostgreSQL script: create_tables_tides.sql
-- Database schema definition for TiDES tables

-- Enable UUID Extension (optional but recommended for unique IDs if desired)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- TABLE: TiDES_Cand
CREATE TABLE tides_cand (
  tides_id SERIAL PRIMARY KEY,
  lsst_sn_id BIGINT UNIQUE,
  lsst_host_id BIGINT,
  last_date TIMESTAMP,
  classification VARCHAR(50),
  z_best FLOAT,
  z_sn FLOAT,
  z_gal FLOAT,
  z_source VARCHAR(50),
  confidence FLOAT
);

-- TABLE: TiDES_Spec
CREATE TABLE tides_spec (
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  qmost_id BIGINT PRIMARY KEY,
  sn_type VARCHAR(50),
  obs_date TIMESTAMP,
  obs_mjd FLOAT,
  snr FLOAT,
  seeing FLOAT,
  sky_brightness FLOAT,
  filepath TEXT,
  version INTEGER,
  additional_info JSONB                 -- Optional: store flexible additional info
);

-- TABLE: 4MOST_Measurements
CREATE TABLE qmost_measurements (
  qmost_id BIGINT REFERENCES tides_spec(qmost_id),
  z FLOAT,
  z_err FLOAT,
  z_flag INTEGER,
  z_type VARCHAR(50),
  PRIMARY KEY(qmost_id)
);

-- TABLES: TiDES Ancillary (multiple tables)

-- Gal_ID (from DESC)
CREATE TABLE ancillary_gal_id (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  gal_id BIGINT,
  z FLOAT,
  z_err FLOAT,
  d_dlr FLOAT,
  is_4most_target BOOLEAN
);

-- 4MOST_SPEC (from WAVES)
CREATE TABLE ancillary_4most_spec (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  gal_id BIGINT,
  z FLOAT,
  z_err FLOAT,
  z_flag INTEGER,
  survey VARCHAR(100)
);

-- External_Gal_Spec (from DESC)
CREATE TABLE ancillary_external_gal_spec (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  gal_id BIGINT,
  z FLOAT,
  z_err FLOAT,
  catalog VARCHAR(100)
);

-- External_SN_Spec (automated TNS)
CREATE TABLE ancillary_external_sn_spec (
  id SERIAL PRIMARY KEY,
  sn_type VARCHAR(50),
  z FLOAT,
  z_err FLOAT,
  iau_name VARCHAR(100)
);

-- Gal_Phot (from DESC)
CREATE TABLE ancillary_gal_phot (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  gal_id BIGINT,
  ra FLOAT,
  dec FLOAT,
  mag_g FLOAT,
  aper_mag_r FLOAT
);

-- LC (Light Curve)
CREATE TABLE ancillary_lc (
  id SERIAL PRIMARY KEY,
  peak_mjd FLOAT,
  t_disc FLOAT,
  source VARCHAR(100),
  last_update TIMESTAMP,
  peak_mag FLOAT
);

-- TABLES: Pipeline Classifications (separate tables for each pipeline)

-- Example for Superfit classification
CREATE TABLE pipeline_classification_superfit (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  sn_type VARCHAR(50),
  probability FLOAT,
  version VARCHAR(20),
  z FLOAT,
  z_err FLOAT,
  phase FLOAT
);

-- Example for SNID classification
CREATE TABLE pipeline_classification_snid (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  sn_type VARCHAR(50),
  probability FLOAT,
  version VARCHAR(20),
  z FLOAT,
  z_err FLOAT,
  phase FLOAT
);

-- Example for DASH classification
CREATE TABLE pipeline_classification_dash (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  sn_type VARCHAR(50),
  probability FLOAT,
  version VARCHAR(20)
);

-- Example for Ed classification
CREATE TABLE pipeline_classification_ed (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  sn_type VARCHAR(50),
  probability FLOAT,
  version VARCHAR(20)
);

-- Global classification
CREATE TABLE pipeline_classification_global (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  sn_type VARCHAR(50),
  probability FLOAT,
  version VARCHAR(20),
  notes TEXT,
  z FLOAT,
  z_err FLOAT,
  phase FLOAT
);

-- TABLE: Human_Classifications (Marshall)
CREATE TABLE human_classifications (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  obs_id INTEGER,
  person_id INTEGER,
  sn_type VARCHAR(50),
  sn_z FLOAT,
  sn_subtype VARCHAR(50),
  comments TEXT,
  created TIMESTAMP DEFAULT NOW()
);

-- TABLE: Marshall_tags
CREATE TABLE marshall_tags (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  tag VARCHAR(50),
  description TEXT,
  tag_date TIMESTAMP DEFAULT NOW()
);

-- TABLE: TiDES Follow-up (external observations, possibly including TNS)

-- Spec_Follow
CREATE TABLE spec_follow (
  id SERIAL PRIMARY KEY,
  tides_id BIGINT REFERENCES tides_cand(tides_id),
  telescope VARCHAR(100),
  instrument VARCHAR(100),
  filter VARCHAR(50),
  obs_date TIMESTAMP,
  flux FLOAT,
  flux_err FLOAT,
  flux_system VARCHAR(50)
);

-- Phot_Follow
CREATE TABLE phot_follow (
  id SERIAL PRIMARY KEY,
  tides_id INTEGER REFERENCES tides_cand(tides_id),
  telescope VARCHAR(100),
  instrument VARCHAR(100),
  obs_date TIMESTAMP,
  classification VARCHAR(50),
  redshift FLOAT,
  redshift_err FLOAT,
  flux FLOAT,
  flux_err FLOAT,
  notes TEXT
);

-- Optional indexing for performance optimization
-- Indexes Example
CREATE INDEX idx_tides_cand_lsst_sn_id ON tides_cand(lsst_sn_id);
CREATE INDEX idx_tides_spec_tides_id ON tides_spec(tides_id);
CREATE INDEX idx_human_classifications_tides_id ON human_classifications(tides_id);
CREATE INDEX idx_spec_follow_tides_id ON spec_follow(tides_id);
CREATE INDEX idx_phot_follow_tides_id ON phot_follow(tides_id);

-- Grants example (adjust accordingly)
-- GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO tides_user;
