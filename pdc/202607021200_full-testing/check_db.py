"""
Check database indexes and advisory details for debugging test failures.
"""
import sys
sys.stdout.reconfigure(encoding='utf-8')

from sqlalchemy import create_engine, text

# Build test database URL
_DEFAULT_DB_NAME = "farmeye_db"
_TEST_DB_NAME = "farmeye_test"
_TEST_DATABASE_URL = f"postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/{_TEST_DB_NAME}"

engine = create_engine(_TEST_DATABASE_URL)
with engine.connect() as conn:
    # Check all indexes
    result = conn.execute(text(
        "SELECT tablename, indexname, indexdef FROM pg_indexes "
        "WHERE schemaname = 'public' ORDER BY tablename, indexname"
    ))
    print("=== INDEXES ===")
    for r in result:
        print(f"Table: {r[0]}, Index: {r[1]}")
        print(f"  Def: {r[2]}")

    # Check UNIQUE indexes specifically
    print("\n=== UNIQUE INDEXES ===")
    result = conn.execute(text(
        "SELECT tablename, indexname FROM pg_indexes i "
        "JOIN pg_class c ON c.relname = i.indexname "
        "JOIN pg_index idx ON idx.indexrelid = c.oid "
        "WHERE i.schemaname = 'public' AND idx.indisunique "
        "ORDER BY tablename"
    ))
    for r in result:
        print(f"Table: {r[0]}, Index: {r[1]} (UNIQUE)")

    # Check sensor_snapshot columns
    print("\n=== SENSOR_SNAPSHOT COLUMNS ===")
    result = conn.execute(text(
        "SELECT column_name, data_type, numeric_precision, numeric_scale "
        "FROM information_schema.columns "
        "WHERE table_name = 'sensor_snapshot' "
        "ORDER BY ordinal_position"
    ))
    for r in result:
        print(f"  {r[0]}: {r[1]} (precision={r[2]}, scale={r[3]})")

    # Check sensor_daily_aggregation columns
    print("\n=== SENSOR_DAILY_AGGREGATION COLUMNS ===")
    result = conn.execute(text(
        "SELECT column_name, data_type, numeric_precision, numeric_scale "
        "FROM information_schema.columns "
        "WHERE table_name = 'sensor_daily_aggregation' "
        "ORDER BY ordinal_position"
    ))
    for r in result:
        print(f"  {r[0]}: {r[1]} (precision={r[2]}, scale={r[3]})")

    # Check tables
    print("\n=== TABLES ===")
    result = conn.execute(text(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' ORDER BY table_name"
    ))
    for r in result:
        print(f"  {r[0]}")

engine.dispose()
print("\nDone.")
