import os
import argparse
import yaml
from astropy.io import fits
import psycopg2

INT32_MAX = 2_147_483_647

def _db_connect(db_creds: dict):
    conn = psycopg2.connect(
        dbname=db_creds.get("name") or db_creds.get("database") or "tides_db",
        user=db_creds.get("user"),
        password=db_creds.get("password") or "",
        host=db_creds.get("host", "localhost"),
        port=str(db_creds.get("port", 5432)),
    )
    conn.autocommit = True
    return conn

def _get_table_columns(conn, schema: str, table: str):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT column_name, is_nullable, data_type, column_default
            FROM information_schema.columns
            WHERE table_schema=%s AND table_name=%s
        """, (schema, table))
        return {r[0]: {"nullable": (r[1] == "YES"), "type": r[2], "default": r[3]} for r in cur.fetchall()}

def _get_column_type(conn, schema: str, table: str, column: str) -> str | None:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT data_type
            FROM information_schema.columns
            WHERE table_schema=%s AND table_name=%s AND column_name=%s
        """, (schema, table, column))
        row = cur.fetchone()
        return row[0] if row else None

def _default_for_type(typ: str):
    t = typ.lower()
    if "timestamp" in t:
        return ("NOW()", None)
    if t in ("date",):
        return ("CURRENT_DATE", None)
    if any(k in t for k in ("int", "numeric", "double", "real", "decimal")):
        return (0, "%s")
    if any(k in t for k in ("char", "text")):
        return ("", "%s")
    if "boolean" in t:
        return (False, "%s")
    return (0, "%s")

def _ensure_basetarget(conn, target_id: int, name: str, ra: float | None, dec: float | None):
    """
    Ensure tom_targets_basetarget has a row with id=target_id.
    Fills NOT NULL columns without defaults with sensible values.
    """
    cols = _get_table_columns(conn, "public", "tom_targets_basetarget")

    values = {
        "id": target_id,
        "name": str(name),
        "type": "SIDEREAL",
        "ra": float(ra) if ra is not None else 0.0,
        "dec": float(dec) if dec is not None else 0.0,
        "epoch": 2000.0,
    }
    for ts_col in ("created", "modified"):
        if ts_col in cols:
            values[ts_col] = ("NOW()", None)
    if "scheme" in cols:
        values["scheme"] = 0

    for col, meta in cols.items():
        if col in values:
            continue
        if meta["nullable"] is False and meta["default"] is None:
            dv, placeholder = _default_for_type(meta["type"])
            values[col] = (dv, placeholder)

    col_names, placeholders, params = [], [], []
    for col, val in values.items():
        if isinstance(val, tuple) and val[1] is None:
            col_names.append(col)
            placeholders.append(val[0])
        else:
            col_names.append(col)
            placeholders.append("%s")
            params.append(val if not isinstance(val, tuple) else val[0])

    sql = f"""
        INSERT INTO public.tom_targets_basetarget ({", ".join(col_names)})
        VALUES ({", ".join(placeholders)})
        ON CONFLICT (id) DO NOTHING
    """
    with conn.cursor() as cur:
        cur.execute(sql, params)

def _ensure_in_tides_cand(conn, tides_id: int):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO public.tides_cand (tides_id) VALUES (%s) ON CONFLICT (tides_id) DO NOTHING",
            (tides_id,),
        )

def _obj_nme_to_int(val) -> int:
    if val is None:
        raise ValueError("OBJ_NME is None")
    if isinstance(val, bytes):
        val = val.decode("ascii", errors="ignore")
    s = str(val).strip()
    if s == "":
        raise ValueError("Empty OBJ_NME")
    try:
        return int(s)
    except ValueError:
        return int(float(s))

def _fibmeta_colmap(hdu):
    return {n.upper(): n for n in (hdu.columns.names or [])}

def _fibmeta_get_num(row, colmap, candidates):
    for cand in candidates:
        key = colmap.get(cand.upper())
        if key is not None:
            try:
                v = row[key]
                return float(v)
            except Exception:
                pass
    return None

def _to_int32(n: int) -> int:
    x = n % INT32_MAX
    return x if x != 0 else 1

def seed_from_mec(mec_file: str, db_creds: dict):
    conn = _db_connect(db_creds)
    try:
        # Detect tides_cand.tides_id type to decide 32-bit vs 64-bit
        tid_type = _get_column_type(conn, "public", "tides_cand", "tides_id") or "integer"
        use_int32 = tid_type.lower() == "integer"

        with fits.open(mec_file, memmap=False) as hdul:
            fibmeta_hdu = hdul["FIBMETATAB"]
            fibmeta = fibmeta_hdu.data
            colmap = _fibmeta_colmap(fibmeta_hdu)

            count = 0
            for i in range(len(fibmeta)):
                try:
                    row = fibmeta[i]
                    raw_id = _obj_nme_to_int(row["OBJ_NME"])
                    tides_id = _to_int32(raw_id) if use_int32 else int(raw_id)

                    ra = _fibmeta_get_num(row, colmap, ["RA", "ALPHA_J2000", "RA_DEG"])
                    dec = _fibmeta_get_num(row, colmap, ["DEC", "DELTA_J2000", "DEC_DEG"])

                    _ensure_basetarget(conn, tides_id, str(tides_id), ra, dec)
                    _ensure_in_tides_cand(conn, tides_id)

                    count += 1
                except Exception as e:
                    print(f"WARNING: Skipped row {i}: {e}")

            print(f"Seeded {count} targets from {os.path.basename(mec_file)} into tom_targets_basetarget and tides_cand.")
    finally:
        try:
            conn.close()
        except Exception:
            pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed a local tides_db (tom_targets_basetarget, tides_cand) from a MEC FITS with transient spectra.")
    parser.add_argument("--mec", required=True, help="Path to MEC FITS file with transient spectra (OBJ_NME holds tides_id)")
    parser.add_argument("--config", required=True, help="Path to YAML config with db_creds {host, port, user, password, [name|database]}")
    args = parser.parse_args()

    if not os.path.exists(args.config):
        raise SystemExit(f"Config file not found: {args.config}")
    with open(args.config, "r") as f:
        cfg = yaml.safe_load(f) or {}
    db_creds = cfg.get("db_creds") or {}
    if not db_creds:
        raise SystemExit("db_creds missing in config YAML")

    if not os.path.exists(args.mec):
        raise SystemExit(f"MEC file not found: {args.mec}")

    seed_from_mec(args.mec, db_creds)