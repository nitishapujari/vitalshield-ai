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

@app.get("/health", status_code=status.HTTP_200_OK)
def health_check():
    return {"status": "ok"}

from core import security
from routers import auth
from routers import user

# Register routers
app.include_router(auth.router)
app.include_router(user.router)

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


# --- CHECK-INS ---
@app.post("/checkins/create", response_model=schemas.CheckInResponse)
def create_checkin(
    checkin: schemas.CheckInCreate,
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

    timestamp = checkin.timestamp or datetime.datetime.utcnow()

    # One check-in per calendar day: Check if a check-in already exists on this day.
    start_of_day = datetime.datetime(timestamp.year, timestamp.month, timestamp.day, 0, 0, 0)
    end_of_day = datetime.datetime(timestamp.year, timestamp.month, timestamp.day, 23, 59, 59, 999999)
    
    existing_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile_id,
        models.CheckIn.timestamp >= start_of_day,
        models.CheckIn.timestamp <= end_of_day
    ).first()

    if existing_checkin:
        # Overwrite/update existing check-in
        existing_checkin.sleep_hours = checkin.sleep_hours
        existing_checkin.steps = checkin.steps
        existing_checkin.heart_rate = checkin.heart_rate
        existing_checkin.systolic = checkin.systolic
        existing_checkin.diastolic = checkin.diastolic
        existing_checkin.glucose = checkin.glucose
        existing_checkin.timestamp = timestamp
        db.commit()
        db.refresh(existing_checkin)
        return existing_checkin

    new_checkin = models.CheckIn(
        profile_id=profile_id,
        timestamp=timestamp,
        sleep_hours=checkin.sleep_hours,
        steps=checkin.steps,
        heart_rate=checkin.heart_rate,
        systolic=checkin.systolic,
        diastolic=checkin.diastolic,
        glucose=checkin.glucose
    )
    db.add(new_checkin)
    db.commit()
    db.refresh(new_checkin)
    return new_checkin

@app.get("/checkins/history", response_model=List[schemas.CheckInResponse])
def get_checkin_history(
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

    profile_created_date = profile.created_at.date()
    start_of_created_day = datetime.datetime.combine(profile_created_date, datetime.time.min)

    checkins = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile_id,
        models.CheckIn.timestamp >= start_of_created_day
    ).order_by(models.CheckIn.timestamp.desc()).all()
    return checkins

# --- PREDICTIONS & ML PIPELINE ---
@app.post("/predictions/generate", response_model=schemas.PredictionSnapshotResponse)
def generate_prediction_endpoint(
    input_data: schemas.PredictionGenerate,
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

    metrics_dict = input_data.metrics.dict()
    
    # Run the ML Prediction Pipeline
    pred_res = predict_service.generate_wellness_prediction(
        metrics=metrics_dict,
        age_category=input_data.age_category,
        gender=input_data.gender,
        cycle_phase=input_data.cycle_phase
    )

    # Save to Prediction Table with same-day deduplication
    snapshot_id = str(int(datetime.datetime.utcnow().timestamp() * 1000))
    timestamp = datetime.datetime.utcnow().replace(microsecond=0)
    timestamp_str = format_utc_timestamp(timestamp)

    # Calculate the prediction hash from raw health inputs
    prediction_hash = generate_prediction_hash(
        profile_id=profile_id,
        timestamp=timestamp_str,
        sleep=input_data.metrics.sleep_hours,
        steps=input_data.metrics.steps,
        heart_rate=input_data.metrics.heart_rate,
        systolic=input_data.metrics.systolic,
        diastolic=input_data.metrics.diastolic,
        glucose=input_data.metrics.glucose,
    )

    # Build standard Response Object matching PredictionSnapshotModel schema
    snapshot = schemas.PredictionSnapshotResponse(
        id=snapshot_id,
        timestamp=timestamp,
        overallWellnessScore=pred_res["overallWellnessScore"],
        categories=pred_res["categories"],
        primaryInsight=pred_res["primaryInsight"],
        is_ml_generated=pred_res["is_ml_generated"],
        predictionHash=prediction_hash,
        sleepHours=input_data.metrics.sleep_hours,
        steps=input_data.metrics.steps,
        heartRate=input_data.metrics.heart_rate,
        systolic=input_data.metrics.systolic,
        diastolic=input_data.metrics.diastolic,
        glucose=input_data.metrics.glucose
    )

    existing_by_hash = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile_id,
        models.Prediction.prediction_hash == prediction_hash
    ).first()

    if existing_by_hash:
        try:
            data = json.loads(existing_by_hash.prediction_json)
            # Ensure predictionHash and metrics are present in return object
            data["predictionHash"] = prediction_hash
            data["sleepHours"] = input_data.metrics.sleep_hours
            data["steps"] = input_data.metrics.steps
            data["heartRate"] = input_data.metrics.heart_rate
            data["systolic"] = input_data.metrics.systolic
            data["diastolic"] = input_data.metrics.diastolic
            data["glucose"] = input_data.metrics.glucose
            return schemas.PredictionSnapshotResponse(**data)
        except Exception:
            return snapshot

    # Conflict check: Different hash, same day
    pred_date = timestamp.date()
    start_of_day = datetime.datetime.combine(pred_date, datetime.time.min)
    end_of_day = datetime.datetime.combine(pred_date, datetime.time.max)
    
    same_day_pred = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile_id,
        models.Prediction.timestamp >= start_of_day,
        models.Prediction.timestamp <= end_of_day
    ).first()

    if same_day_pred:
        same_day_pred.overall_score = snapshot.overallWellnessScore
        same_day_pred.primary_category = pred_res["primary_category"]
        same_day_pred.insight = snapshot.primaryInsight
        same_day_pred.prediction_json = json.dumps(snapshot.dict(), default=str)
        same_day_pred.timestamp = timestamp
        same_day_pred.prediction_hash = prediction_hash
        db.commit()
    else:
        new_pred = models.Prediction(
            profile_id=profile_id,
            timestamp=timestamp,
            overall_score=snapshot.overallWellnessScore,
            primary_category=pred_res["primary_category"],
            insight=snapshot.primaryInsight,
            prediction_json=json.dumps(snapshot.dict(), default=str),
            prediction_hash=prediction_hash
        )
        db.add(new_pred)
        db.commit()

    return snapshot


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

# --- ANALYTICS ---
@app.get("/analytics/report")
def get_analytics_report_endpoint(
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

    # Get check-ins
    checkins_db = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile_id,
        models.CheckIn.timestamp >= start_of_created_day
    ).order_by(models.CheckIn.timestamp.asc()).all()

    # Get predictions
    predictions_db = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile_id,
        models.Prediction.timestamp >= start_of_created_day
    ).order_by(models.Prediction.timestamp.asc()).all()

    checkins = [
        {
            "timestamp": c.timestamp,
            "sleep_hours": c.sleep_hours,
            "steps": c.steps,
            "heart_rate": c.heart_rate,
            "systolic": c.systolic,
            "diastolic": c.diastolic,
            "glucose": c.glucose
        }
        for c in checkins_db
    ]

    predictions = [
        {
            "timestamp": p.timestamp,
            "overall_score": p.overall_score,
            "primary_category": p.primary_category
        }
        for p in predictions_db
    ]

    # Generate analytics report
    report = analytics_service.generate_analytics_report(
        checkins=checkins,
        predictions=predictions,
        age_category=profile.age_category,
        gender=profile.gender
    )

    # Save to DB as history snapshot if successful
    if report["hasEnoughData"]:
        new_snap = models.AnalyticsSnapshot(
            profile_id=profile_id,
            timestamp=datetime.datetime.utcnow(),
            analytics_json=json.dumps(report["report"])
        )
        db.add(new_snap)
        db.commit()

    return report

# --- SIMULATION ---
@app.post("/simulate", response_model=schemas.HabitSimulationResponse)
def simulate_habits(req: schemas.HabitSimulationRequest):
    is_senior = req.is_senior
    sleep_hours = req.sleep_hours
    steps = req.steps
    consistency_level = req.consistency_level
    routine_quality = req.routine_quality

    # 1. Sleep score component (max 100)
    sleep_score = 50.0
    sleep_threshold = 6.5 if is_senior else 7.0
    if sleep_hours >= sleep_threshold and sleep_hours <= 9.0:
        sleep_score = 90.0 + (sleep_hours - sleep_threshold) * 5
    elif sleep_hours > 9.0:
        sleep_score = 85.0 - (sleep_hours - 9.0) * 10
    else:
        sleep_score = 40.0 + (sleep_hours / sleep_threshold) * 20
    
    sleep_score = max(0.0, min(100.0, sleep_score))

    # 2. Activity/Steps component (max 100)
    activity_score = 50.0
    step_threshold = 4000 if is_senior else 5000
    if steps >= step_threshold:
        activity_score = 85.0 + ((steps - step_threshold) / (15000 - step_threshold) * 15)
    else:
        activity_score = 40.0 + (steps / step_threshold * 25)
    
    activity_score = max(0.0, min(100.0, activity_score))

    # 3. Consistency and Routine components (direct inputs)
    consistency_score = max(0.0, min(100.0, consistency_level))
    routine_score = max(0.0, min(100.0, routine_quality))

    # Calculate final projected score
    base_score = (sleep_score * 0.3) + \
                 (activity_score * 0.25) + \
                 (consistency_score * 0.25) + \
                 (routine_score * 0.20)
                 
    projected_score = int(round(base_score))
    projected_score = max(0, min(100, projected_score))

    return schemas.HabitSimulationResponse(projected_score=projected_score)

@app.post("/simulation/run", response_model=schemas.SimulationRunResponse)

def run_simulation_endpoint(
    req: schemas.SimulationRunRequest,
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

    # 1. Base checkin metrics
    baseline_metrics = {
        "sleep_hours": req.sleep_hours,
        "steps": req.steps,
        "heart_rate": req.heart_rate,
        "systolic": req.systolic,
        "diastolic": req.diastolic,
        "glucose": req.glucose
    }
    
    # 2. Get baseline prediction
    baseline_pred = predict_service.generate_wellness_prediction(
        metrics=baseline_metrics,
        age_category=profile.age_category,
        gender=profile.gender
    )

    # 3. Apply target modification
    simulated_metrics = baseline_metrics.copy()
    if req.target_metric in simulated_metrics:
        simulated_metrics[req.target_metric] = req.target_value
    else:
        raise HTTPException(status_code=400, detail=f"Invalid target metric: {req.target_metric}")

    # 4. Get simulated prediction
    simulated_pred = predict_service.generate_wellness_prediction(
        metrics=simulated_metrics,
        age_category=profile.age_category,
        gender=profile.gender
    )

    orig_score = baseline_pred["overallWellnessScore"]
    sim_score = simulated_pred["overallWellnessScore"]
    diff = sim_score - orig_score

    # Construct descriptive helper text
    metric_label = predict_service.FEATURE_LABELS.get(req.target_metric, req.target_metric)
    if diff > 0:
        desc = f"Mindful adjustment of {metric_label} to {req.target_value} shows a positive wellness score improvement of +{diff} points."
    elif diff < 0:
        desc = f"Simulating {metric_label} at {req.target_value} results in a score reduction of {diff} points. Maintaining closer targets is recommended."
    else:
        desc = f"Simulating {metric_label} at {req.target_value} maintains your baseline wellness balance."

    response = schemas.SimulationRunResponse(
        original_score=orig_score,
        simulated_score=sim_score,
        score_difference=diff,
        primary_category_original=baseline_pred["primary_category"],
        primary_category_simulated=simulated_pred["primary_category"],
        impact_description=desc
    )

    # Save to Simulation history
    new_sim = models.Simulation(
        profile_id=profile_id,
        timestamp=datetime.datetime.utcnow(),
        input_json=json.dumps(req.dict()),
        output_json=json.dumps(response.dict())
    )
    db.add(new_sim)
    db.commit()

    return response

# --- ASSISTANT ---
def is_emergency_query(message: str) -> bool:
    import re
    # Patterns covering chest pain, breathing difficulties, stroke symptoms, suicide, self harm, and medical emergency.
    emergency_patterns = [
        r'\bsuicid(e|al)\b', r'\bkill\s+myself\b', r'\bself[\s-]*harm\b', r'\bend\s+my\s+life\b',
        r'\bwant\s+to\s+die\b', r'\bbetter\s+off\s+dead\b',
        r'\bchest\s+pain\b', r'\bheart\s+attack\b', r'\bpain\s+in\s+chest\b', r'\bchest\s+pressure\b',
        r'\bleft\s+arm\s+pain\b',
        r"can't\s+breathe", r"cant\s+breathe", r'\bdifficulty\s+breathing\b',
        r'\bshort(ness)?\s+of\s+breath\b', r'\bsuffocat(ing|e)?\b', r'\bgasping\s+for\s+air\b',
        r'\bstroke\b', r'\bface\s+droop(ing)?\b', r'\barm\s+weakness\b', r'\bspeech\s+slur(red)?\b',
        r'\bslur(red)?\s+speech\b',
        r'\bmedical\s+emergency\b', r'\bcall\s+(an\s+)?ambulance\b', r'\bcall\s+911\b',
        r'\bpoisoned\b', r'\bsevere\s+allergic\s+reaction\b', r'\banaphylaxis\b',
        r'\blost\s+consciousness\b', r'\bpassed\s+out\b',
        r'\bcollaps(e|ed)\b', r'\bbleed(ing)?\b', r'\b(hurt|harm)\s+my(self|\s+self)\b'
    ]
    return any(re.search(pattern, message.lower()) for pattern in emergency_patterns)

def get_regional_crisis_response(locale: Optional[str]) -> str:
    country = "UNKNOWN"
    if locale:
        parts = locale.replace("-", "_").split("_")
        if len(parts) > 1:
            country = parts[1].upper()
        else:
            country = parts[0].upper()
            
    if country == "US":
        emergency_number = "911"
        crisis_number = "\n• Call or text the Suicide & Crisis Lifeline at **988** (available 24/7, free, and confidential)."
    elif country == "CA":
        emergency_number = "911"
        crisis_number = "\n• Call or text the Suicide Crisis Helpline at **988** (available 24/7, free, and confidential)."
    elif country in ["GB", "UK"]:
        emergency_number = "999"
        crisis_number = "\n• Call the Samaritans at **116 123** or call NHS **111** for mental health support."
    elif country == "IN":
        emergency_number = "112"
        crisis_number = "\n• Call the Tele-MANAS mental health helpline at **14416** or **1800 891 4416** (available 24/7, free, and confidential)."
    elif country == "AU":
        emergency_number = "000"
        crisis_number = "\n• Call Lifeline at **13 11 14** for mental health and crisis support."
    else:
        return (
            "🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
            "If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
            "thoughts of self-harm, or any other life-threatening medical emergency, "
            "**please seek immediate medical assistance.**\n\n"
            "• **Contact your local emergency services, emergency medical provider, crisis hotline, or trusted emergency contact immediately.**\n"
            "• Go to the nearest Emergency Room (ER) or hospital.\n\n"
            "VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**"
        )
        
    return (
        f"🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
        f"If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
        f"thoughts of self-harm, or any other life-threatening medical emergency, "
        f"**please seek immediate medical assistance.**\n\n"
        f"• **Call {emergency_number}** immediately.\n"
        f"• Go to the nearest Emergency Room (ER) or hospital.{crisis_number}\n\n"
        f"VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**"
    )

@app.post("/assistant/message", response_model=schemas.AssistantResponse)
def get_assistant_message(
    req: schemas.AssistantMessageRequest,
    profile_id: str,
    locale: Optional[str] = None,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(
        models.Profile.id == profile_id,
        models.Profile.user_id == user_id
    ).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found or access denied.")

    message_trimmed = req.message.strip()
    if is_emergency_query(message_trimmed):
        return schemas.AssistantResponse(reply=get_regional_crisis_response(locale))

    message = message_trimmed.lower()

    # Context variables
    is_senior = profile.age_category in ["Senior", "Senior Citizen"]
    is_female = profile.gender.lower() == "female"

    profile_created_date = profile.created_at.date()
    start_of_created_day = datetime.datetime.combine(profile_created_date, datetime.time.min)

    # Fetch latest checkin for dynamic context
    latest_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile_id,
        models.CheckIn.timestamp >= start_of_created_day
    ).order_by(models.CheckIn.timestamp.desc()).first()

    # Fetch latest prediction for dynamic context
    latest_pred = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile_id,
        models.Prediction.timestamp >= start_of_created_day
    ).order_by(models.Prediction.timestamp.desc()).first()

    # Check for active Critical emergency
    has_critical_emergency = False
    if latest_checkin:
        sys_val = latest_checkin.systolic
        dia_val = latest_checkin.diastolic
        glu_val = latest_checkin.glucose
        if (sys_val is not None and sys_val >= 180) or (dia_val is not None and dia_val >= 120):
            has_critical_emergency = True
        elif glu_val is not None and (glu_val < 55.0 or glu_val > 300.0):
            has_critical_emergency = True

    if not has_critical_emergency and latest_pred:
        try:
            pred_data = json.loads(latest_pred.prediction_json)
            for c in pred_data.get('categories', []):
                if c.get('severity') == 'Critical' or c.get('recommendationPriority') == 'Critical':
                    has_critical_emergency = True
                    break
        except Exception:
            pass

    if has_critical_emergency:
        def is_wellness_optimization_query(msg: str) -> bool:
            import re
            wellness_keywords = [
                r'\bexercise\b',
                r'\bworkout(s)?\b',
                r'\brun(ning)?\b',
                r'\btrain(ing)?\b',
                r'\bsleep\s+optimiz(e|ation)\b',
                r'\bnutrition\s+optimiz(e|ation)\b',
                r'\boptimize\s+(sleep|nutrition|diet)\b'
            ]
            return any(re.search(pattern, msg) for pattern in wellness_keywords)

        if is_wellness_optimization_query(message):
            reply = (
                "🚨 **SAFETY INTERCEPTION** 🚨\n\n"
                "I noticed that your latest vital readings indicate a potential health crisis. "
                "Before focusing on daily wellness routines, workouts, or optimization activities, "
                "please seek medical attention or consult your doctor immediately."
            )
            # Log/Save assistant chat history
            db_history = db.query(models.AssistantConversation).filter(
                models.AssistantConversation.profile_id == profile_id
            ).first()
            new_chat_history = req.conversation_history + [
                {"role": "user", "content": req.message},
                {"role": "assistant", "content": reply}
            ]
            if db_history:
                db_history.messages_json = json.dumps(new_chat_history)
                db_history.updated_at = datetime.datetime.utcnow()
            else:
                db_history = models.AssistantConversation(
                    profile_id=profile_id,
                    messages_json=json.dumps(new_chat_history)
                )
                db.add(db_history)
            db.commit()
            return schemas.AssistantResponse(reply=reply)

    pred_score = None
    pred_insight = None
    categories_scores = {}

    if latest_pred:
        try:
            pred_data = json.loads(latest_pred.prediction_json)
            pred_score = pred_data.get('overallWellnessScore')
            pred_insight = pred_data.get('primaryInsight')
            categories = pred_data.get('categories', [])
            for cat in categories:
                title = cat.get('categoryTitle')
                score = cat.get('score')
                categories_scores[title] = score
        except Exception as e:
            print(f"Error loading prediction in assistant: {e}")

    is_active_session = len(req.conversation_history) > 0

    import re
    def match_word_keywords(msg: str, keywords: list) -> bool:
        return any(re.search(r'\b' + re.escape(k) + r'\b', msg) for k in keywords)

    # Intent Detection flags
    improvement_keywords = ["improve", "recommend", "advice", "better", "help", "fix", "weakest", "attention", "focus"]
    is_improvement = match_word_keywords(message, improvement_keywords) or "what should i do" in message

    comparison_keywords = ["compare", "comparison", "difference", "versus", "vs", "check-in", "checkin", "history", "change", "compared"]
    is_comparison = match_word_keywords(message, comparison_keywords)

    greeting_keywords = ["hello", "hi", "hey", "hiii", "hii", "hiiii", "yo", "greetings", "how are you"]
    is_greeting = match_word_keywords(message, greeting_keywords)

    pred_data = {}
    if latest_pred:
        try:
            pred_data = json.loads(latest_pred.prediction_json)
        except Exception as e:
            print(f"Error parsing prediction json: {e}")

    categories = pred_data.get("categories", [])
    highest_opt = pred_data.get("highestImpactOpportunity")
    secondary_opt = pred_data.get("secondaryOpportunity")
    stable_metrics = pred_data.get("stableMetrics", [])

    def find_cat(title):
        for c in categories:
            if c.get("categoryTitle") == title:
                return c
        return None

    # Empty prompt check
    if not message_trimmed:
        if is_active_session:
            reply = "How else can I help you support your wellness journey today?"
        else:
            reply = f"Hello {profile.name}. I am here to support your wellness journey in an emotionally safe, encouraging space. How can I help you understand your resting patterns, movement, or daily vitals today?"

    elif match_word_keywords(message, ["sleep", "rest", "night"]):
        cat = find_cat("Sleep Wellness")
        if cat:
            reply = f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            reply = "Complete a daily check-in with your sleep hours to unlock personalized sleep insights."

    elif match_word_keywords(message, ["step", "steps", "active", "activity", "movement", "exercise", "walk"]):
        cat = find_cat("Activity Wellness")
        if cat:
            reply = f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            reply = "Complete a daily check-in with your step count to unlock activity insights."

    elif match_word_keywords(message, ["stress", "calm", "anxious"]):
        reply = "When stress rises, taking a few deep, slow breaths can help settle your nervous system. Inhaling for four counts and exhaling for six counts is a gentle way to find your center. How is your stress feeling today?"

    elif match_word_keywords(message, ["glucose", "sugar", "blood sugar"]):
        cat = find_cat("Glucose Wellness")
        if cat:
            reply = f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            reply = "Complete a daily check-in with your glucose readings to unlock glucose insights."

    elif match_word_keywords(message, ["bp", "pressure", "blood pressure", "systolic", "diastolic"]):
        cat = find_cat("Blood Pressure Wellness")
        if cat:
            reply = f"Based on your latest wellness snapshot, {cat.get('insight', '')}\n\nTo optimize this: {cat.get('recommendation', '')}"
        else:
            reply = "Complete a daily check-in with your blood pressure to unlock vascular insights."

    elif match_word_keywords(message, ["diet", "nutrition", "food", "eat"]):
        glu_cat = find_cat("Glucose Wellness")
        bp_cat = find_cat("Blood Pressure Wellness")
        diet_advices = []
        if glu_cat and glu_cat.get("recommendation"):
            diet_advices.append(f"Glucose: {glu_cat['recommendation']}")
        if bp_cat and bp_cat.get("recommendation"):
            diet_advices.append(f"Circulation: {bp_cat['recommendation']}")
        
        if diet_advices:
            reply = "Based on your latest wellness snapshot, here is your nutrition guidance:\n\n" + "\n\n".join(diet_advices)
        else:
            reply = "Nourishing your body with a balanced diet filled with protein, calcium, fiber, and complex carbohydrates is wonderful for supporting steady energy. Complete a daily check-in to see personalized dietary guidance."

    elif is_improvement:
        if not latest_pred:
            reply = "I don't have enough wellness data to make specific recommendations yet. Complete a few daily check-ins so we can identify areas to improve first!"
        elif not highest_opt:
            reply = "Your wellness categories are all in the optimal range (Score 85+)! You are doing fantastic. Maintain your current sleep, movement, and nutrition habits to sustain this balance."
        else:
            def map_category_title(title: str) -> str:
                t = title.lower()
                if "sleep" in t:
                    return "sleep"
                if "activity" in t:
                    return "Physical activity"
                if "pressure" in t:
                    return "Blood pressure"
                if "heart" in t:
                    return "Heart rate"
                if "glucose" in t:
                    return "Fasting glucose"
                return title

            lines = []
            highest_title = map_category_title(highest_opt['categoryTitle'])
            lines.append(f"Looking at your recent check-in, I suggest prioritizing your **{highest_title}** first (Impact: {highest_opt['impactLevel']}, Estimate: +{highest_opt['scoreImprovementEstimate']:.1f} points).\n{highest_opt['insight']}\nTo support this: {highest_opt['recommendation']}")
            
            sec_title = secondary_opt['categoryTitle'] if secondary_opt else None
            if secondary_opt:
                secondary_title = map_category_title(secondary_opt['categoryTitle'])
                lines.append(f"\nSecondary opportunity to optimize: **{secondary_title}** (Impact: {secondary_opt['impactLevel']}, Estimate: +{secondary_opt['scoreImprovementEstimate']:.1f} points).\n{secondary_opt['insight']}\nTo support this: {secondary_opt['recommendation']}")
            
            all_cats = pred_data.get("categories", [])
            for c in all_cats:
                prio = c.get("recommendationPriority") or c.get("severity") or c.get("trend") or ""
                if prio in ["Critical", "Warning", "needsAttention"]:
                    c_title = c.get("categoryTitle") or c.get("title") or ""
                    if c_title not in [highest_opt['categoryTitle'], sec_title]:
                        other_title = map_category_title(c_title)
                        lines.append(f"\nOther area to monitor: **{other_title}** (Impact: {c.get('impactLevel', 'Low')}, Estimate: +{c.get('scoreImprovementEstimate', 0.0):.1f} points).\n{c.get('insight')}\nTo support this: {c.get('recommendation')}")

            if stable_metrics:
                stable_clean = [map_category_title(s) for s in stable_metrics]
                lines.append(f"\nStable metrics currently in optimal ranges: " + ", ".join(stable_clean))
            reply = "\n".join(lines)

    elif is_comparison:
        # Load all check-ins chronologically
        profile_created_date = profile.created_at.date()
        start_of_created_day = datetime.datetime.combine(profile_created_date, datetime.time.min)
        checkins = db.query(models.CheckIn).filter(
            models.CheckIn.profile_id == profile_id,
            models.CheckIn.timestamp >= start_of_created_day
        ).order_by(models.CheckIn.timestamp.asc()).all()
        
        if len(checkins) < 2:
            reply = "You need at least two daily check-ins to perform a comparison. Complete another check-in tomorrow so we can track changes over time!"
        else:
            # Search check-ins by formatted dates in message
            matched_checkins = []
            for c in checkins:
                formatted_d1 = c.timestamp.strftime("%B %d").lower()
                formatted_d2 = c.timestamp.strftime("%b %d").lower()
                day = str(c.timestamp.day)
                month_long = c.timestamp.strftime("%B").lower()
                month_short = c.timestamp.strftime("%b").lower()
                
                pattern1 = f"{month_long} {day}"
                pattern2 = f"{month_short} {day}"
                
                if pattern1 in message or pattern2 in message or formatted_d1 in message or formatted_d2 in message:
                    matched_checkins.append(c)
            
            if len(matched_checkins) >= 2:
                c1 = matched_checkins[-2]
                c2 = matched_checkins[-1]
            else:
                c1 = checkins[-2]
                c2 = checkins[-1]
                
            d1_str = c1.timestamp.strftime("%B %d")
            d2_str = c2.timestamp.strftime("%B %d")
            
            p1_score = "N/A"
            p2_score = "N/A"
            
            def get_score_for_day(dt):
                start = datetime.datetime(dt.year, dt.month, dt.day, 0, 0, 0)
                end = datetime.datetime(dt.year, dt.month, dt.day, 23, 59, 59, 999999)
                pred = db.query(models.Prediction).filter(
                    models.Prediction.profile_id == profile_id,
                    models.Prediction.timestamp >= start,
                    models.Prediction.timestamp <= end
                ).first()
                return pred.overall_score if pred else None
                
            s1 = get_score_for_day(c1.timestamp)
            s2 = get_score_for_day(c2.timestamp)
            if s1 is not None: p1_score = str(s1)
            if s2 is not None: p2_score = str(s2)
            
            # Differences and indicators
            sleep_diff = c2.sleep_hours - c1.sleep_hours
            sleep_ind = "↑" if sleep_diff > 0 else ("↓" if sleep_diff < 0 else "stable")
            sleep_diff_str = f" ({'+' if sleep_diff >= 0 else ''}{sleep_diff:.1f}h)" if sleep_diff != 0 else " (no change)"
            
            steps_diff = c2.steps - c1.steps
            steps_ind = "↑" if steps_diff > 0 else ("↓" if steps_diff < 0 else "stable")
            steps_diff_str = f" ({'+' if steps_diff >= 0 else ''}{steps_diff})" if steps_diff != 0 else " (no change)"
            
            hr_diff = c2.heart_rate - c1.heart_rate
            hr_ind = "↑" if hr_diff > 0 else ("↓" if hr_diff < 0 else "stable")
            hr_diff_str = f" ({'+' if hr_diff >= 0 else ''}{hr_diff} BPM)" if hr_diff != 0 else " (no change)"
            
            bp1_str = f"{c1.systolic}/{c1.diastolic}"
            bp2_str = f"{c2.systolic}/{c2.diastolic}"
            sys_diff = c2.systolic - c1.systolic
            dia_diff = c2.diastolic - c1.diastolic
            bp_diff_str = f" (Systolic: {'+' if sys_diff >= 0 else ''}{sys_diff}, Diastolic: {'+' if dia_diff >= 0 else ''}{dia_diff})"
            bp_ind = "changed" if (sys_diff != 0 or dia_diff != 0) else "stable"
            
            gluc_diff = c2.glucose - c1.glucose
            gluc_ind = "↑" if gluc_diff > 0 else ("↓" if gluc_diff < 0 else "stable")
            gluc_diff_str = f" ({'+' if gluc_diff >= 0 else ''}{gluc_diff:.1f} mg/dL)" if gluc_diff != 0 else " (no change)"
            
            score_diff_str = ""
            score_ind = ""
            if s1 is not None and s2 is not None:
                sdiff = s2 - s1
                score_ind = "↑" if sdiff > 0 else ("↓" if sdiff < 0 else "stable")
                score_diff_str = f" ({'+' if sdiff >= 0 else ''}{sdiff})"
            
            # Most significant change
            changes = []
            if c1.sleep_hours > 0:
                changes.append(("Sleep Duration", abs(sleep_diff) / c1.sleep_hours, sleep_diff, f"{abs(sleep_diff):.1f} hours", sleep_diff > 0))
            if c1.steps > 0:
                changes.append(("Physical Activity", abs(steps_diff) / c1.steps, steps_diff, f"{abs(steps_diff)} steps", steps_diff > 0))
            if c1.heart_rate > 0:
                changes.append(("Resting Heart Rate", abs(hr_diff) / c1.heart_rate, hr_diff, f"{abs(hr_diff)} BPM", hr_diff < 0))
            if c1.glucose > 0:
                changes.append(("Fasting Glucose", abs(gluc_diff) / c1.glucose, gluc_diff, f"{abs(gluc_diff):.1f} mg/dL", abs(c2.glucose-85) < abs(c1.glucose-85)))
            
            changes_sorted = sorted(changes, key=lambda x: x[1], reverse=True)
            
            sig_change_summary = ""
            if s1 is not None and s2 is not None and s1 != s2:
                score_change_text = "improved" if s2 > s1 else "declined"
                sig_change_summary = f"The most notable trend is that your overall Wellness Score {score_change_text} by {abs(s2 - s1)} points (from {s1} to {s2})."
            elif changes_sorted:
                metric_name, rel, raw_diff, diff_label, is_improvement_bool = changes_sorted[0]
                trend_direction = "increase" if raw_diff > 0 else "decrease"
                impact_text = "positive development" if is_improvement_bool else "change that needs attention"
                sig_change_summary = f"The most significant metric change is in **{metric_name}**, which showed a {trend_direction} of {diff_label} (a {rel*100:.1f}% shift), representing a {impact_text}."
            else:
                sig_change_summary = "There are no significant metric changes between these check-ins."
            
            reply = (
                f"Comparing check-ins from **{d1_str}** and **{d2_str}**:\n\n"
                f"• **Wellness Score**: {p1_score} vs {p2_score} {score_ind}{score_diff_str}\n"
                f"• **Sleep**: {c1.sleep_hours:.1f}h vs {c2.sleep_hours:.1f}h {sleep_ind}{sleep_diff_str}\n"
                f"• **Steps**: {c1.steps} vs {c2.steps} {steps_ind}{steps_diff_str}\n"
                f"• **Blood Pressure**: {bp1_str} vs {bp2_str} {bp_ind}{bp_diff_str}\n"
                f"• **Fasting Glucose**: {c1.glucose:.1f} vs {c2.glucose:.1f} mg/dL {gluc_ind}{gluc_diff_str}\n"
                f"• **Heart Rate**: {c1.heart_rate} vs {c2.heart_rate} BPM {hr_ind}{hr_diff_str}\n\n"
                f"{sig_change_summary}"
            )

    elif "vitals" in message or "how am i doing" in message or "wellness score" in message or "status" in message or "insight" in message or "trend" in message or "prediction" in message or "summary" in message:
        if pred_score is not None:
            reply = f"Your overall wellness score is {pred_score}/100, which reflects your recent daily habits. The primary observation is that {pred_insight} "
            if latest_checkin:
                reply += f"In your latest check-in, we recorded {latest_checkin.sleep_hours} hours of rest, {latest_checkin.steps} steps, a heart rate of {latest_checkin.heart_rate} BPM, blood pressure at {latest_checkin.systolic}/{latest_checkin.diastolic} mmHg, and fasting glucose of {latest_checkin.glucose} mg/dL. These metrics give us a great foundation to track your trends over time."
            else:
                reply += "Once you log a daily check-in, I can share more personalized details with you."
        else:
            reply = "I'm monitoring your wellness based on your daily entries. Consistent tracking helps build a clearer picture of your health. Try logging your check-in today so we can look at your patterns together."

    elif is_greeting:
        if is_active_session:
            reply = "Hello! How can I help you support your wellness journey today?"
        else:
            reply = f"Hello {profile.name}! I'm your wellness companion. How can I help you support your wellness journey today?"

    else:
        reply = (
            "I want to make sure I give you the best support possible, but I'm not quite sure how to help with that topic. "
            "As your wellness companion, I can help you understand your sleep, steps, heart rate, blood pressure, fasting glucose, or cycle rhythms, and even compare check-ins. "
            "Is there one of those areas you'd like to check on today?"
        )

    # Log/Save assistant chat history
    db_history = db.query(models.AssistantConversation).filter(
        models.AssistantConversation.profile_id == profile_id
    ).first()

    # Append message
    new_chat_history = req.conversation_history + [
        {"role": "user", "content": req.message},
        {"role": "assistant", "content": reply}
    ]

    if db_history:
        db_history.messages_json = json.dumps(new_chat_history)
        db_history.updated_at = datetime.datetime.utcnow()
    else:
        db_history = models.AssistantConversation(
            profile_id=profile_id,
            messages_json=json.dumps(new_chat_history)
        )
        db.add(db_history)
        
    db.commit()

    return schemas.AssistantResponse(reply=reply)

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
