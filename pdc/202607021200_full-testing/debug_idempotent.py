"""
Minimal reproduction of the idempotency test failure.
"""
import sys
sys.stdout.reconfigure(encoding='utf-8')

from datetime import datetime
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

_TEST_DATABASE_URL = "postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_test"
engine = create_engine(_TEST_DATABASE_URL)

# First, check how _parse_event_time handles the compact format
event_time_str = "20260702T120000Z"
try:
    dt1 = datetime.fromisoformat(event_time_str.replace("Z", "+00:00"))
    print(f"fromisoformat result: {dt1}")
except ValueError as e:
    print(f"fromisoformat failed: {e}")
    dt1 = datetime.strptime(event_time_str, "%Y%m%dT%H%M%SZ")
    print(f"strptime result: {dt1}")

print(f"Final timestamp: {dt1}")

# Try duplicate inserts outside of transaction isolation
# Use two separate sessions to test UNIQUE constraint
conn1 = engine.connect()
session1 = Session(bind=conn1)

conn2 = engine.connect()
session2 = Session(bind=conn2)

device_id = "debug_test_dev_001"
ts = dt1

# Insert first record
from app.models.sensor import SensorSnapshot
app.models.sensor.Base.metadata.create_all(bind=engine)

try:
    s1 = SensorSnapshot(device_id=device_id, timestamp=ts, temperature=25.0)
    session1.add(s1)
    session1.commit()
    print(f"First insert OK: id={s1.id}")
except Exception as e:
    print(f"First insert FAILED: {e}")
    session1.rollback()

try:
    s2 = SensorSnapshot(device_id=device_id, timestamp=ts, temperature=30.0)
    session2.add(s2)
    session2.commit()
    print(f"Second insert OK: id={s2.id}")
except Exception as e:
    print(f"Second insert FAILED (expected): {e}")
    session2.rollback()

# Count
count = session1.query(SensorSnapshot).filter_by(device_id=device_id).count()
print(f"Total records for device: {count}")

session1.close()
session2.close()
conn1.close()
conn2.close()
engine.dispose()
