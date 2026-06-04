import os
import sys
import datetime
import json

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.db import Base
from main import app, get_user_id_from_token, get_db, format_utc_timestamp, generate_prediction_hash
from database import models

# Setup test DB
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_predictions.db"
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

def test_prediction_deduplication():
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
        
        # 1. Post a generate prediction request
        payload = {
            "metrics": {
                "sleep_hours": 7.5,
                "steps": 7200,
                "heart_rate": 72,
                "systolic": 118,
                "diastolic": 78,
                "glucose": 88.5
            },
            "age_category": "Adult",
            "gender": "female"
        }
        
        response1 = client.post("/predictions/generate?profile_id=sarah_id", json=payload)
        assert response1.status_code == 200
        
        # Verify it created a record in DB
        preds = db.query(models.Prediction).filter(models.Prediction.profile_id == "sarah_id").all()
        assert len(preds) == 1
        first_pred_id = preds[0].id
        first_score = preds[0].overall_score
        first_insight = preds[0].insight
        
        # 2. Post identical generate prediction request
        response2 = client.post("/predictions/generate?profile_id=sarah_id", json=payload)
        assert response2.status_code == 200
        
        # Verify it did NOT create a duplicate record
        preds = db.query(models.Prediction).filter(models.Prediction.profile_id == "sarah_id").all()
        assert len(preds) == 1
        assert preds[0].id == first_pred_id
        
        # 3. Post a modified generate prediction request (different metrics/score/insight)
        payload_modified = {
            "metrics": {
                "sleep_hours": 3.0, # Needs attention, will change score/insight
                "steps": 1000,
                "heart_rate": 100,
                "systolic": 140,
                "diastolic": 95,
                "glucose": 130.0
            },
            "age_category": "Adult",
            "gender": "female"
        }
        
        response3 = client.post("/predictions/generate?profile_id=sarah_id", json=payload_modified)
        assert response3.status_code == 200
        
        # Expire session cache to reload from DB
        db.expire_all()
        
        # Verify it UPDATED the existing record instead of appending (since it is same day)
        preds = db.query(models.Prediction).filter(models.Prediction.profile_id == "sarah_id").all()
        assert len(preds) == 1
        assert preds[0].id == first_pred_id
        assert preds[0].overall_score != first_score
        assert preds[0].insight != first_insight

        # --- TEST SYNC ENDPOINT ---
        # 1. Sync prediction for a new day
        sync_timestamp = (datetime.datetime.utcnow() + datetime.timedelta(days=1)).replace(microsecond=0)
        sync_timestamp_str = format_utc_timestamp(sync_timestamp)
        sync_hash = generate_prediction_hash("sarah_id", sync_timestamp_str, 8.0, 10000, 70, 120, 80, 90.0)
        
        sync_payload = [
            {
                "id": "sync_id_1",
                "timestamp": sync_timestamp_str,
                "overallWellnessScore": 90,
                "categories": [
                    {
                        "categoryTitle": "Sleep Wellness",
                        "score": 90,
                        "status": "Optimal",
                        "trendDirection": "stable",
                        "insight": "Great sleep",
                        "recommendation": "Keep it up"
                    }
                ],
                "primaryInsight": "Great sleep",
                "is_ml_generated": False,
                "predictionHash": sync_hash,
                "sleepHours": 8.0,
                "steps": 10000,
                "heartRate": 70,
                "systolic": 120,
                "diastolic": 80,
                "glucose": 90.0
            }
        ]
        
        # Check initial check-in count
        initial_checkins_count = db.query(models.CheckIn).count()
        
        response_sync1 = client.post("/predictions/sync?profile_id=sarah_id", json=sync_payload)
        assert response_sync1.status_code == 200
        sync_res = response_sync1.json()
        assert sync_res["status"] == "success"
        assert sync_hash in sync_res["synced"]
        
        # Verify it inserted a prediction
        db.expire_all()
        sync_preds = db.query(models.Prediction).filter(models.Prediction.prediction_hash == sync_hash).all()
        assert len(sync_preds) == 1
        assert sync_preds[0].overall_score == 90
        
        # Verify no check-in record was created (Decoupled check-in sync)
        assert db.query(models.CheckIn).count() == initial_checkins_count
        
        # 2. Sync identical (same hash) -> skip duplicate
        response_sync2 = client.post("/predictions/sync?profile_id=sarah_id", json=sync_payload)
        assert response_sync2.status_code == 200
        sync_res2 = response_sync2.json()
        assert sync_hash in sync_res2["synced"]
        
        # Verify prediction count did not increase
        assert db.query(models.Prediction).filter(models.Prediction.prediction_hash == sync_hash).count() == 1
        
        # 3. Sync same day, different hash -> update prediction only
        sync_hash_modified = generate_prediction_hash("sarah_id", sync_timestamp_str, 5.0, 2000, 80, 130, 90, 110.0)
        sync_payload_modified = [
            {
                "id": "sync_id_1_mod",
                "timestamp": sync_timestamp_str,
                "overallWellnessScore": 60,
                "categories": [
                    {
                        "categoryTitle": "Sleep Wellness",
                        "score": 60,
                        "status": "Needs Attention",
                        "trendDirection": "needsAttention",
                        "insight": "Poor sleep",
                        "recommendation": "Get more sleep"
                    }
                ],
                "primaryInsight": "Poor sleep",
                "is_ml_generated": False,
                "predictionHash": sync_hash_modified,
                "sleepHours": 5.0,
                "steps": 2000,
                "heartRate": 80,
                "systolic": 130,
                "diastolic": 90,
                "glucose": 110.0
            }
        ]
        
        response_sync3 = client.post("/predictions/sync?profile_id=sarah_id", json=sync_payload_modified)
        assert response_sync3.status_code == 200
        sync_res3 = response_sync3.json()
        assert sync_hash_modified in sync_res3["synced"]
        
        # Verify the record for that day was updated with the new hash and fields
        db.expire_all()
        day_preds = db.query(models.Prediction).filter(
            models.Prediction.profile_id == "sarah_id",
            models.Prediction.prediction_hash == sync_hash_modified
        ).all()
        assert len(day_preds) == 1
        assert day_preds[0].overall_score == 60
        assert day_preds[0].insight == "Poor sleep"
        
        # Verify the old hash pred is gone or updated (since it is same day conflict)
        assert db.query(models.Prediction).filter(models.Prediction.prediction_hash == sync_hash).count() == 0
        
        # Verify check-ins are still unmodified
        assert db.query(models.CheckIn).count() == initial_checkins_count
        
        print("Backend prediction deduplication and sync tests passed!")
        
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        app.dependency_overrides.clear()
        # Clean up database file
        if os.path.exists("./test_predictions.db"):
            try:
                os.remove("./test_predictions.db")
            except Exception:
                pass

if __name__ == "__main__":
    test_prediction_deduplication()
