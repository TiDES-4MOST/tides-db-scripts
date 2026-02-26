import psycopg2
import random
from datetime import datetime, timedelta

def connect_to_db():
    """
    Connects to the PostgreSQL database.
    """
    try:
        conn = psycopg2.connect(
            dbname="tides_db",
            user="pwise",
            password="",
            host="localhost",
            port="5432"
        )
        return conn
    except Exception as e:
        print(f"Failed to connect to the database: {e}")
        return None

def generate_random_data():
    """
    Generates semi-realistic data for a single object.
    """
    lsst_sn_id = random.randint(1000000000, 9999999999)
    lsst_host_id = random.randint(1000000000, 9999999999)
    last_date = datetime.now() - timedelta(days=random.randint(1, 7))  # Random date in the last week
    classification = "pending"
    z_best = round(random.uniform(0.01, 1.0), 4)
    z_sn = round(random.uniform(0.01, 1.0), 4)
    z_gal = round(random.uniform(0.01, 1.0), 4)
    z_source = random.choice(["LSST", "4MOST", "External"])
    confidence = round(random.uniform(0.5, 1.0), 2)
    
    return (
        lsst_sn_id,
        lsst_host_id,
        last_date,
        classification,
        z_best,
        z_sn,
        z_gal,
        z_source,
        confidence
    )

def insert_data(conn, data):
    """
    Inserts generated data into the tides_cand table.
    """
    try:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO tides_cand (
                lsst_sn_id, lsst_host_id, last_date, classification, z_best, z_sn, z_gal, z_source, confidence
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, data)
        conn.commit()
    except Exception as e:
        print(f"Failed to insert data: {e}")
        conn.rollback()

def main():
    conn = connect_to_db()
    if not conn:
        return

    print("Generating and inserting data into tides_cand...")
    for _ in range(1000):  # Generate data for 1000 objects
        data = generate_random_data()
        insert_data(conn, data)

    print("Data insertion complete.")
    conn.close()

if __name__ == "__main__":
    main()