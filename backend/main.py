import os
import datetime
import hashlib
from fastapi import FastAPI, Depends, HTTPException, Header, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
import json

from database.db import engine, get_db, Base
from database import models
from schemas import schemas
from services import predict_service, analytics_service

# Create database tables if they do not exist
Base.metadata.create_all(bind=engine)

app = FastAPI(title="VitalShield AI - Wellness Intelligence Backend")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for Flutter web & mobile emulator testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from core import security
from routers import auth, user, vitals, assistant, analytics

# Register routers
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(vitals.router)
app.include_router(vitals.dashboard_router)
app.include_router(assistant.router)
app.include_router(analytics.router)

def format_utc_timestamp(dt) -> str:
    if isinstance(dt, str):
        # Parse timezone-aware ISO string, handling 'Z' suffix
        dt = datetime.datetime.fromisoformat(dt.replace("Z", "+00:00"))
    if dt.tzinfo is not None:
        dt = dt.astimezone(datetime.timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

def generate_prediction_hash(
    profile_id: str,
    timestamp: str,
    sleep: float,
    steps: int,
    heart_rate: int,
    systolic: int,
    diastolic: int,
    glucose: float,
) -> str:
    input_str = (
        f"{profile_id}|"
        f"{timestamp}|"
        f"{sleep:.2f}|"
        f"{steps}|"
        f"{heart_rate}|"
        f"{systolic}|"
        f"{diastolic}|"
        f"{glucose:.2f}"
    )
    return hashlib.sha256(input_str.encode("utf-8")).hexdigest()


# Seed default Google mock user with ID 1 if it does not exist
from database.db import SessionLocal
db = SessionLocal()
try:
    google_user = db.query(models.User).filter(models.User.id == 1).first()
    if not google_user:
        google_user_email = db.query(models.User).filter(models.User.email == "google_user@vitalshield.ai").first()
        if not google_user_email:
            hashed_pwd = security.get_password_hash("mockgooglepassword")
            google_user = models.User(
                id=1,
                email="google_user@vitalshield.ai",
                password_hash=hashed_pwd,
                name="Google User"
            )
            db.add(google_user)
            db.commit()
            print("Seeded default Google mock user with ID 1.")
        else:
            print("Google mock email already exists, skipping seed.")
except Exception as e:
    print(f"Error seeding Google mock user: {e}")
    db.rollback()
finally:
    db.close()

from core.security import get_user_id_from_token

# --- HEALTH CHECK ---
@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        # Verify db is responsive
        db.execute(models.Base.metadata.tables["users"].select()).first()
        db_ok = True
    except Exception as e:
        db_ok = False
        print(f"Health check db error: {e}")
        
    return {
        "status": "healthy",
        "database": "connected" if db_ok else "unreachable",
        "ml_models_loaded": predict_service.score_model is not None and predict_service.cat_model is not None
    }


# --- LEGACY PREDICTION SYNC (RETAINED) ---
@app.post("/predictions/sync")
def sync_predictions_endpoint(
    predictions: List[schemas.PredictionSyncItem],
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    # Verify profile belongs to user
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    synced_hashes = []
    for pred in predictions:
        # 1. Check if prediction_hash already exists in the database
        existing = db.query(models.Prediction).filter(
            models.Prediction.profile_id == profile_id,
            models.Prediction.prediction_hash == pred.predictionHash
        ).first()
        
        if existing:
            # Same hash -> skip duplicate
            synced_hashes.append(pred.predictionHash)
            continue
            
        # 2. Check if there is already a prediction on the same calendar day (Prediction ONLY)
        pred_date = pred.timestamp.date()
        start_of_day = datetime.datetime.combine(pred_date, datetime.time.min)
        end_of_day = datetime.datetime.combine(pred_date, datetime.time.max)
        
        same_day_pred = db.query(models.Prediction).filter(
            models.Prediction.profile_id == profile_id,
            models.Prediction.timestamp >= start_of_day,
            models.Prediction.timestamp <= end_of_day
        ).first()
        
        # Determine primary category
        primary_cat = "Overall"
        if pred.categories:
            needs_attention = [c for c in pred.categories if c.trendDirection == "needsAttention"]
            if needs_attention:
                primary_cat = needs_attention[0].categoryTitle
            else:
                primary_cat = pred.categories[0].categoryTitle

        # Prepare JSON representation
        pred_dict = pred.dict()
        pred_dict["timestamp"] = pred.timestamp.isoformat()
        
        if same_day_pred:
            # Different hash, same day -> update prediction only
            same_day_pred.overall_score = pred.overallWellnessScore
            same_day_pred.primary_category = primary_cat
            same_day_pred.insight = pred.primaryInsight
            same_day_pred.prediction_json = json.dumps(pred_dict, default=str)
            same_day_pred.timestamp = pred.timestamp
            same_day_pred.prediction_hash = pred.predictionHash
        else:
            # Different hash, different day -> insert prediction only
            new_pred = models.Prediction(
                profile_id=profile_id,
                timestamp=pred.timestamp,
                overall_score=pred.overallWellnessScore,
                primary_category=primary_cat,
                insight=pred.primaryInsight,
                prediction_json=json.dumps(pred_dict, default=str),
                prediction_hash=pred.predictionHash
            )
            db.add(new_pred)
            
        synced_hashes.append(pred.predictionHash)
        
    db.commit()
    return {"status": "success", "synced": synced_hashes}


@app.get("/predictions/latest", response_model=Optional[schemas.PredictionSnapshotResponse])
def get_latest_prediction(
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    # Verify profile
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    profile_created_date = profile.created_at.date()
    start_of_created_day = datetime.datetime.combine(profile_created_date, datetime.time.min)

    latest_pred = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile_id,
        models.Prediction.timestamp >= start_of_created_day
    ).order_by(models.Prediction.timestamp.desc()).first()

    if not latest_pred:
        return None

    try:
        data = json.loads(latest_pred.prediction_json)
        return data
    except Exception as e:
        print(f"Error parsing saved prediction json: {e}")
        # Return DB columns mapped if parsing fails
        return schemas.PredictionSnapshotResponse(
            id=str(latest_pred.id),
            timestamp=latest_pred.timestamp,
            overallWellnessScore=latest_pred.overall_score,
            categories=[],
            primaryInsight=latest_pred.insight,
            is_ml_generated=True
        )




# --- PREFERENCES PERSISTENCE ---
@app.post("/preferences/reminders")
def save_reminder_preferences(
    pref: schemas.ReminderPreferenceSave,
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    db_pref = db.query(models.ReminderPreference).filter(
        models.ReminderPreference.profile_id == profile_id
    ).first()

    if db_pref:
        db_pref.settings_json = pref.settings_json
    else:
        db_pref = models.ReminderPreference(
            profile_id=profile_id,
            settings_json=pref.settings_json
        )
        db.add(db_pref)
        
    db.commit()
    return {"status": "success"}

@app.get("/preferences/reminders")
def get_reminder_preferences(
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    db_pref = db.query(models.ReminderPreference).filter(
        models.ReminderPreference.profile_id == profile_id
    ).first()

    if not db_pref:
        return {"settings_json": "{}"}
    return {"settings_json": db_pref.settings_json}

@app.post("/preferences/cycle")
def save_cycle_preferences(
    pref: schemas.CycleCarePreferenceSave,
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    db_pref = db.query(models.CycleCarePreference).filter(
        models.CycleCarePreference.profile_id == profile_id
    ).first()

    if db_pref:
        db_pref.settings_json = pref.settings_json
    else:
        db_pref = models.CycleCarePreference(
            profile_id=profile_id,
            settings_json=pref.settings_json
        )
        db.add(db_pref)
        
    db.commit()
    return {"status": "success"}

@app.get("/preferences/cycle")
def get_cycle_preferences(
    profile_id: str,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    db_pref = db.query(models.CycleCarePreference).filter(
        models.CycleCarePreference.profile_id == profile_id
    ).first()

    if not db_pref:
        return {"settings_json": "{}"}
    return {"settings_json": db_pref.settings_json}
