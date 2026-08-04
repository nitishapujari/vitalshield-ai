import os
import sys
import datetime
import json
from sqlalchemy.orm import Session

# Import models from backend
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database.db import SessionLocal
from database import models
from services.predict_service import generate_wellness_prediction
from schemas.schemas import PredictionSnapshotResponse

def seed_demo_data():
    db = SessionLocal()
    
    # Get the user and profile
    profile = db.query(models.Profile).first()
    if not profile:
        print("No profile found. Please create a profile in the app first.")
        db.close()
        return

    profile_id = profile.id
    
    # Clear existing checkins and predictions to give a clean slate
    db.query(models.CheckIn).filter(models.CheckIn.profile_id == profile_id).delete()
    db.query(models.Prediction).filter(models.Prediction.profile_id == profile_id).delete()
    db.query(models.AnalyticsSnapshot).filter(models.AnalyticsSnapshot.profile_id == profile_id).delete()
    db.commit()

    # Generate 7 days of historical data, ending today
    # Let's create an "improving" trend so the graph looks great for the presentation
    history = [
        {"days_ago": 6, "sleep": 5.0, "steps": 3000, "sys": 130, "dia": 85, "hr": 85, "glu": 110},
        {"days_ago": 5, "sleep": 5.5, "steps": 4000, "sys": 128, "dia": 82, "hr": 82, "glu": 105},
        {"days_ago": 4, "sleep": 6.0, "steps": 5500, "sys": 125, "dia": 80, "hr": 80, "glu": 100},
        {"days_ago": 3, "sleep": 6.5, "steps": 7000, "sys": 120, "dia": 78, "hr": 78, "glu": 95},
        {"days_ago": 2, "sleep": 7.0, "steps": 8500, "sys": 118, "dia": 75, "hr": 75, "glu": 90},
        {"days_ago": 1, "sleep": 7.5, "steps": 9500, "sys": 115, "dia": 72, "hr": 72, "glu": 88},
        {"days_ago": 0, "sleep": 8.0, "steps": 10500, "sys": 112, "dia": 70, "hr": 68, "glu": 85}, # Today (Optimal!)
    ]

    now = datetime.datetime.utcnow()

    for h in history:
        record_date = now - datetime.timedelta(days=h["days_ago"])
        
        # 1. Create CheckIn
        checkin = models.CheckIn(
            profile_id=profile_id,
            timestamp=record_date,
            sleep_hours=h["sleep"],
            steps=h["steps"],
            heart_rate=h["hr"],
            systolic=h["sys"],
            diastolic=h["dia"],
            glucose=h["glu"]
        )
        db.add(checkin)
        db.commit()
        db.refresh(checkin)

        # 2. Generate and save Prediction for this CheckIn
        metrics = {
            "sleep_hours": h["sleep"],
            "steps": h["steps"],
            "heart_rate": h["hr"],
            "systolic": h["sys"],
            "diastolic": h["dia"],
            "glucose": h["glu"]
        }
        pred_res = generate_wellness_prediction(
            metrics=metrics,
            age_category=profile.age_category,
            gender=profile.gender
        )
        
        snapshot = PredictionSnapshotResponse(
            id=str(int(record_date.timestamp() * 1000)),
            timestamp=record_date,
            overallWellnessScore=pred_res["overallWellnessScore"],
            categories=pred_res["categories"],
            primaryInsight=pred_res["primaryInsight"],
            is_ml_generated=pred_res["is_ml_generated"]
        )

        prediction = models.Prediction(
            profile_id=profile_id,
            timestamp=record_date,
            overall_score=snapshot.overallWellnessScore,
            primary_category=pred_res["primary_category"],
            insight=snapshot.primaryInsight,
            prediction_json=json.dumps(snapshot.dict(), default=str)
        )
        db.add(prediction)
        
    db.commit()
    print("Successfully seeded 7 days of historical demo data with a beautiful upward trend!")
    db.close()

if __name__ == "__main__":
    seed_demo_data()
