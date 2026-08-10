from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
import datetime
import json
from typing import List, Dict, Any

from database.db import get_db
from database import models
from schemas import schemas
from core.security import get_active_user_id
from services import predict_service

router = APIRouter(prefix="/vitals", tags=["Vitals"])
dashboard_router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

def get_profile(db: Session, user_id: int):
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=400, detail="User profile not found. Please complete onboarding.")
    return profile

def get_day_boundaries(offset_minutes: int) -> tuple[datetime.datetime, datetime.datetime]:
    # offset_minutes is client offset from UTC in minutes (e.g., UTC-5 is -300)
    # Actually, Javascript getTimezoneOffset() returns minutes *behind* UTC (e.g. UTC-5 is 300).
    # But usually APIs receive actual offset (e.g., -300). Let's assume standard ISO offset in minutes.
    # We want to find the client's current date.
    now_utc = datetime.datetime.utcnow()
    client_now = now_utc + datetime.timedelta(minutes=offset_minutes)
    client_date = client_now.date()

    # Start and end of the client's day in client's time
    client_start_of_day = datetime.datetime.combine(client_date, datetime.time.min)
    client_end_of_day = datetime.datetime.combine(client_date, datetime.time.max)

    # Convert back to UTC for database querying
    utc_start_of_day = client_start_of_day - datetime.timedelta(minutes=offset_minutes)
    utc_end_of_day = client_end_of_day - datetime.timedelta(minutes=offset_minutes)

    return utc_start_of_day, utc_end_of_day

def calculate_imputed_metrics(db: Session, profile_id: str, new_vitals: schemas.VitalsCreate, end_time_utc: datetime.datetime) -> Dict[str, Any]:
    # 7-day rolling window for missing metrics
    start_time_utc = end_time_utc - datetime.timedelta(days=7)

    recent_checkins = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile_id,
        models.CheckIn.timestamp >= start_time_utc,
        models.CheckIn.timestamp < end_time_utc
    ).all()

    metrics = {
        "sleep_hours": new_vitals.sleep_hours,
        "steps": new_vitals.steps,
        "heart_rate": new_vitals.heart_rate,
        "systolic": new_vitals.systolic,
        "diastolic": new_vitals.diastolic,
        "glucose": new_vitals.glucose
    }

    # Fallback to sensible defaults if no history exists for missing fields
    defaults = {
        "sleep_hours": 7.0,
        "steps": 5000,
        "heart_rate": 72,
        "systolic": 120,
        "diastolic": 80,
        "glucose": 90.0
    }

    for key, value in metrics.items():
        if value is None:
            # Impute from history
            historical_values = [getattr(c, key) for c in recent_checkins if getattr(c, key) is not None]
            if historical_values:
                metrics[key] = sum(historical_values) / len(historical_values)
            else:
                metrics[key] = defaults[key]

    return metrics

def format_utc_timestamp(dt) -> str:
    if isinstance(dt, str):
        dt = datetime.datetime.fromisoformat(dt.replace("Z", "+00:00"))
    if dt.tzinfo is not None:
        dt = dt.astimezone(datetime.timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")

@router.post("", response_model=schemas.VitalsMergedResponse)
def log_vitals(
    vitals: schemas.VitalsCreate,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_profile(db, user_id)
    offset = vitals.client_timezone_offset or 0

    utc_start, utc_end = get_day_boundaries(offset)

    # Check if a CheckIn already exists for this calendar day
    existing_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile.id,
        models.CheckIn.timestamp >= utc_start,
        models.CheckIn.timestamp <= utc_end
    ).first()

    timestamp = vitals.timestamp or datetime.datetime.utcnow()

    if existing_checkin:
        # Update existing checkin (do not overwrite existing values with None unless explicitly clearing,
        # but in our schema, omitted = None. We will only update if the new value is provided,
        # or we accept the partial payload as an overwrite?
        # "do not accidentally replace an existing metric with NULL merely because a subsequent partial request omitted that metric"
        update_data = vitals.model_dump(exclude_unset=True)
        if "sleep_hours" in update_data: existing_checkin.sleep_hours = update_data["sleep_hours"]
        if "steps" in update_data: existing_checkin.steps = update_data["steps"]
        if "heart_rate" in update_data: existing_checkin.heart_rate = update_data["heart_rate"]
        if "systolic" in update_data: existing_checkin.systolic = update_data["systolic"]
        if "diastolic" in update_data: existing_checkin.diastolic = update_data["diastolic"]
        if "glucose" in update_data: existing_checkin.glucose = update_data["glucose"]
        if "extended_metrics" in update_data: existing_checkin.extended_metrics = update_data["extended_metrics"]

        existing_checkin.data_source = vitals.data_source or existing_checkin.data_source
        existing_checkin.client_timezone_offset = offset
        existing_checkin.timestamp = timestamp

        checkin_record = existing_checkin
    else:
        # Create new checkin
        new_checkin = models.CheckIn(
            profile_id=profile.id,
            timestamp=timestamp,
            client_timezone_offset=offset,
            data_source=vitals.data_source or "Manual",
            sleep_hours=vitals.sleep_hours,
            steps=vitals.steps,
            heart_rate=vitals.heart_rate,
            systolic=vitals.systolic,
            diastolic=vitals.diastolic,
            glucose=vitals.glucose,
            extended_metrics=vitals.extended_metrics
        )
        db.add(new_checkin)
        checkin_record = new_checkin

    db.commit()
    db.refresh(checkin_record)

    # Imputation for Prediction
    # We must construct a complete VitalsCreate-like object for imputation, representing the merged state of the checkin record
    merged_vitals = schemas.VitalsCreate(
        sleep_hours=checkin_record.sleep_hours,
        steps=checkin_record.steps,
        heart_rate=checkin_record.heart_rate,
        systolic=checkin_record.systolic,
        diastolic=checkin_record.diastolic,
        glucose=checkin_record.glucose
    )

    imputed_metrics = calculate_imputed_metrics(db, profile.id, merged_vitals, timestamp)

    # Generate Prediction
    # The actual profile might not have age/gender mapped simply. The original code in main.py had age_category, gender from input.
    # In v2, profile contains dob instead of age.
    gender = profile.gender
    age_category = None
    if profile.dob:
        age = (datetime.datetime.utcnow().date() - profile.dob.date()).days // 365
        if age < 30: age_category = "Young Adult"
        elif age < 60: age_category = "Adult"
        else: age_category = "Senior"

    pred_res = predict_service.generate_wellness_prediction(
        metrics=imputed_metrics,
        age_category=age_category,
        gender=gender,
        cycle_phase=None  # not currently available in profile easily
    )

    # Handle Prediction Association (avoid accumulation)
    existing_prediction = db.query(models.Prediction).filter(
        models.Prediction.checkin_id == checkin_record.id
    ).first()

    snapshot_id = str(int(datetime.datetime.utcnow().timestamp() * 1000))
    timestamp_str = format_utc_timestamp(timestamp)

    import hashlib
    # Generate hash for legacy field matching exact legacy format
    sleep_h = imputed_metrics['sleep_hours']
    gluc = imputed_metrics['glucose']
    hash_str = (
        f"{profile.id}|"
        f"{timestamp_str}|"
        f"{sleep_h:.2f}|"
        f"{int(imputed_metrics['steps'])}|"
        f"{int(imputed_metrics['heart_rate'])}|"
        f"{int(imputed_metrics['systolic'])}|"
        f"{int(imputed_metrics['diastolic'])}|"
        f"{gluc:.2f}"
    )
    prediction_hash = hashlib.sha256(hash_str.encode("utf-8")).hexdigest()

    if existing_prediction:
        existing_prediction.overall_score = pred_res["overallWellnessScore"]
        existing_prediction.primary_category = pred_res["primary_category"]
        existing_prediction.insight = pred_res["primaryInsight"]
        existing_prediction.category_scores = json.dumps(pred_res["categories"])
        existing_prediction.critical_alert_triggered = any(c.get("recommendationPriority") == "Critical" for c in pred_res["categories"])
        existing_prediction.prediction_json = json.dumps(pred_res)
        existing_prediction.prediction_hash = prediction_hash
        prediction_record = existing_prediction
    else:
        new_prediction = models.Prediction(
            profile_id=profile.id,
            checkin_id=checkin_record.id,
            timestamp=timestamp,
            overall_score=pred_res["overallWellnessScore"],
            primary_category=pred_res["primary_category"],
            insight=pred_res["primaryInsight"],
            category_scores=json.dumps(pred_res["categories"]),
            critical_alert_triggered=any(c.get("recommendationPriority") == "Critical" for c in pred_res["categories"]),
            prediction_json=json.dumps(pred_res),
            prediction_hash=prediction_hash
        )
        db.add(new_prediction)
        prediction_record = new_prediction

    db.commit()

    # Construct response
    prediction_response = schemas.PredictionSnapshotResponse(
        id=snapshot_id,
        timestamp=timestamp,
        overallWellnessScore=pred_res["overallWellnessScore"],
        categories=pred_res["categories"],
        primaryInsight=pred_res["primaryInsight"],
        is_ml_generated=pred_res["is_ml_generated"],
        predictionHash=prediction_hash,
        sleepHours=imputed_metrics["sleep_hours"],
        steps=int(imputed_metrics["steps"]),
        heartRate=int(imputed_metrics["heart_rate"]),
        systolic=int(imputed_metrics["systolic"]),
        diastolic=int(imputed_metrics["diastolic"]),
        glucose=imputed_metrics["glucose"],
        highestImpactOpportunity=pred_res.get("highestImpactOpportunity"),
        secondaryOpportunity=pred_res.get("secondaryOpportunity"),
        stableMetrics=pred_res.get("stableMetrics", [])
    )

    return schemas.VitalsMergedResponse(
        vitals=checkin_record,
        prediction=prediction_response
    )

@router.get("/history", response_model=List[schemas.VitalsResponse])
def get_vitals_history(
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_profile(db, user_id)

    checkins = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile.id
    ).order_by(models.CheckIn.timestamp.desc()).all()

    return checkins

@dashboard_router.get("/today", response_model=schemas.DashboardTodayResponse)
def get_dashboard_today(
    timezone_offset: int = Query(0, description="Client timezone offset from UTC in minutes"),
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_profile(db, user_id)
    utc_start, utc_end = get_day_boundaries(timezone_offset)

    checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile.id,
        models.CheckIn.timestamp >= utc_start,
        models.CheckIn.timestamp <= utc_end
    ).first()

    if not checkin:
        return schemas.DashboardTodayResponse(
            has_logged_vitals_today=False,
            wellness_score=None,
            primary_insight=None
        )

    prediction = db.query(models.Prediction).filter(
        models.Prediction.checkin_id == checkin.id
    ).order_by(models.Prediction.timestamp.desc()).first()

    return schemas.DashboardTodayResponse(
        has_logged_vitals_today=True,
        wellness_score=prediction.overall_score if prediction else None,
        primary_insight=prediction.insight if prediction else None
    )
