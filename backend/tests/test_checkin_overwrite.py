import os
import sys
import datetime

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.db import Base
from main import app, get_user_id_from_token, get_db
from database import models

# Setup test DB
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_checkins.db"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

def test_checkin_overwrite():
    # Set overrides inside test execution to avoid import conflicts
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_user_id_from_token] = lambda: 1
    
    client = TestClient(app)
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    try:
        # Create test user and profile
        test_user = models.User(id=1, email="test@example.com", password_hash="pwd", name="Test User")
        db.add(test_user)
        db.commit()
        
        test_profile = models.Profile(id="sarah_id", user_id=1, name="Sarah", gender="female")
        db.add(test_profile)
        db.commit()
        
        now = datetime.datetime.utcnow()
        
        # 1. Post a checkin
        payload1 = {
            "sleep_hours": 7.5,
            "steps": 7200,
            "heart_rate": 72,
            "systolic": 118,
            "diastolic": 78,
            "glucose": 88.5,
            "timestamp": now.isoformat()
        }
        
        response1 = client.post("/checkins/create?profile_id=sarah_id", json=payload1)
        assert response1.status_code == 200
        
        # Verify it created a record in DB
        checkins = db.query(models.CheckIn).filter(models.CheckIn.profile_id == "sarah_id").all()
        assert len(checkins) == 1
        assert checkins[0].sleep_hours == 7.5
        assert checkins[0].steps == 7200
        
        # 2. Post another checkin on the same day (modified values)
        payload2 = {
            "sleep_hours": 8.0,
            "steps": 10000,
            "heart_rate": 68,
            "systolic": 115,
            "diastolic": 75,
            "glucose": 85.0,
            "timestamp": now.isoformat()
        }
        
        response2 = client.post("/checkins/create?profile_id=sarah_id", json=payload2)
        assert response2.status_code == 200
        
        # Expire session cache to reload from DB
        db.expire_all()
        
        # Verify it updated the existing record instead of appending (since it is same day)
        checkins = db.query(models.CheckIn).filter(models.CheckIn.profile_id == "sarah_id").all()
        assert len(checkins) == 1
        assert checkins[0].sleep_hours == 8.0
        assert checkins[0].steps == 10000
        assert checkins[0].heart_rate == 68
        
        # 3. Post a checkin on a different day
        tomorrow = now + datetime.timedelta(days=1)
        payload3 = {
            "sleep_hours": 6.5,
            "steps": 5000,
            "heart_rate": 75,
            "systolic": 120,
            "diastolic": 80,
            "glucose": 90.0,
            "timestamp": tomorrow.isoformat()
        }
        
        response3 = client.post("/checkins/create?profile_id=sarah_id", json=payload3)
        assert response3.status_code == 200
        
        db.expire_all()
        
        # Verify it appended a new record since it is a different day
        checkins = db.query(models.CheckIn).filter(models.CheckIn.profile_id == "sarah_id").all()
        assert len(checkins) == 2
        
        print("Backend check-in same-day overwrite tests passed!")
        
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        app.dependency_overrides.clear()
        # Clean up database file
        if os.path.exists("./test_checkins.db"):
            try:
                os.remove("./test_checkins.db")
            except Exception:
                pass

if __name__ == "__main__":
    test_checkin_overwrite()
