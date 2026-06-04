import sqlite3
import os

db_path = r"c:\Users\Nitisha Pujari\Documents\programming\dev\projects\vitalshield_ai\backend\vitalshield.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get profile named 'Sarah' or similar, or just dump the profiles table with names
cursor.execute("SELECT id, name, gender, age, age_category FROM profiles;")
print("Profiles:")
profiles = cursor.fetchall()
for p in profiles:
    print(p)

# Dump checkins for the last active profile (which has ID like profile_1779905593842)
print("\nCheckins for all profiles:")
cursor.execute("SELECT id, profile_id, timestamp, heart_rate, systolic, diastolic, glucose, sleep_hours, steps FROM checkins;")
for row in cursor.fetchall():
    print(f"ID={row[0]} Profile={row[1]} Timestamp={row[2]} HR={row[3]} BP={row[4]}/{row[5]} Glucose={row[6]} Sleep={row[7]} Steps={row[8]}")

conn.close()
