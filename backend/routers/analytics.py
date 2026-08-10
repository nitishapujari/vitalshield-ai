from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
import json
import datetime

from database import models
from database.db import get_db
from schemas import schemas
from core.security import get_user_id_from_token
from services import predict_service

router = APIRouter(prefix="/me", tags=["Analytics & Forecasting"])

def get_profile(db: Session, user_id: int):
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return profile

@router.get("/predictions", response_model=List[schemas.PredictionSnapshotResponse])
def get_prediction_history(
    skip: int = Query(0, ge=0, description="Pagination skip"),
    limit: int = Query(100, ge=1, le=1000, description="Pagination limit"),
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = get_profile(db, user_id)

    predictions = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile.id
    ).order_by(models.Prediction.timestamp.desc()).offset(skip).limit(limit).all()

    # We must convert the JSON strings stored in the DB back to dicts for the schema
    response_list = []
    for p in predictions:
        # Reconstruct PredictionSnapshotResponse
        categories = json.loads(p.category_scores) if p.category_scores else []

        # Need to parse prediction_json to get extra details
        pred_data = json.loads(p.prediction_json) if p.prediction_json else {}

        # For historical records before certain fields were added, we safely get them
        highest = pred_data.get("highestImpactOpportunity")
        secondary = pred_data.get("secondaryOpportunity")
        stable = pred_data.get("stableMetrics", [])

        # We need to grab metrics from the associated CheckIn if we can,
        # but the schema allows them to be None. The prediction_json doesn't necessarily have raw metrics.
        # But wait, PredictionSnapshotResponse schema takes those directly. We can fetch CheckIn.
        checkin = db.query(models.CheckIn).filter(models.CheckIn.id == p.checkin_id).first()

        response_list.append(schemas.PredictionSnapshotResponse(
            id=str(p.id),
            timestamp=p.timestamp,
            overallWellnessScore=p.overall_score,
            categories=categories,
            primaryInsight=p.insight,
            is_ml_generated=pred_data.get("is_ml_generated", False),
            predictionHash=p.prediction_hash,
            sleepHours=checkin.sleep_hours if checkin else None,
            steps=checkin.steps if checkin else None,
            heartRate=checkin.heart_rate if checkin else None,
            systolic=checkin.systolic if checkin else None,
            diastolic=checkin.diastolic if checkin else None,
            glucose=checkin.glucose if checkin else None,
            highestImpactOpportunity=highest,
            secondaryOpportunity=secondary,
            stableMetrics=stable
        ))

    return response_list

@router.post("/simulations", response_model=schemas.SimulationResponse)
def run_simulation(
    req: schemas.SimulationRequest,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = get_profile(db, user_id)

    # Fetch the authenticated user's latest CheckIn as the baseline
    latest_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile.id
    ).order_by(models.CheckIn.timestamp.desc()).first()

    if not latest_checkin:
        raise HTTPException(status_code=400, detail="No baseline CheckIn found. Please log your vitals first.")

    baseline_metrics = {
        "sleep_hours": latest_checkin.sleep_hours,
        "steps": latest_checkin.steps,
        "heart_rate": latest_checkin.heart_rate,
        "systolic": latest_checkin.systolic,
        "diastolic": latest_checkin.diastolic,
        "glucose": latest_checkin.glucose
    }

    age_category = "Adult"
    if profile.dob:
        age = (datetime.datetime.utcnow().date() - profile.dob.date()).days / 365.25
        if age < 30:
            age_category = "Young Adult"
        elif age < 60:
            age_category = "Adult"
        else:
            age_category = "Senior"

    # 2. Get baseline prediction
    baseline_pred = predict_service.generate_wellness_prediction(
        metrics=baseline_metrics,
        age_category=age_category,
        gender=profile.gender
    )

    # 3. Apply target modification statelessly
    simulated_metrics = baseline_metrics.copy()
    if req.target_metric in simulated_metrics:
        simulated_metrics[req.target_metric] = req.target_value
    else:
        raise HTTPException(status_code=400, detail=f"Invalid target metric: {req.target_metric}")

    # 4. Get simulated prediction
    simulated_pred = predict_service.generate_wellness_prediction(
        metrics=simulated_metrics,
        age_category=age_category,
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

    response = schemas.SimulationResponse(
        original_score=orig_score,
        simulated_score=sim_score,
        score_difference=diff,
        primary_category_original=baseline_pred["primary_category"],
        primary_category_simulated=simulated_pred["primary_category"],
        impact_description=desc
    )

    return response
