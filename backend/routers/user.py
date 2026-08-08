from fastapi import APIRouter, Depends, HTTPException, Request
from typing import List
from sqlalchemy.orm import Session
import uuid
import datetime

from database.db import get_db
from database import models
from schemas import schemas
from core.security import get_user_id_from_token

router = APIRouter(
    prefix="/me",
    tags=["User & Profile"]
)

@router.get("", response_model=schemas.UserMeResponse)
def get_me(user_id: int = Depends(get_user_id_from_token), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    
    active_goals = []
    if profile:
        active_goals = db.query(models.UserGoal).filter(
            models.UserGoal.profile_id == profile.id,
            models.UserGoal.status == "Active"
        ).all()
        
    settings = db.query(models.Settings).filter(models.Settings.user_id == user_id).first()
    
    return schemas.UserMeResponse(
        user=user,
        profile=profile,
        active_goals=active_goals,
        settings=settings
    )

@router.put("/profile", response_model=schemas.ProfileResponse)
def update_profile(
    profile_data: schemas.ProfileUpdateRequest,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    
    if not profile:
        # Create profile if it doesn't exist
        profile = models.Profile(
            id=str(uuid.uuid4()),
            user_id=user_id,
            name=profile_data.name or user.name,
            dob=profile_data.dob,
            gender=profile_data.gender or ""
        )
        db.add(profile)
    else:
        # Update existing profile
        if profile_data.name is not None:
            profile.name = profile_data.name
        if profile_data.dob is not None:
            profile.dob = profile_data.dob
        if profile_data.gender is not None:
            profile.gender = profile_data.gender
            
    db.commit()
    db.refresh(profile)
    return profile

@router.post("/goals", response_model=schemas.UserGoalResponse)
def create_goal(
    goal_data: schemas.UserGoalCreate,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=400, detail="Profile must be created before adding goals.")
        
    new_goal = models.UserGoal(
        profile_id=profile.id,
        goal_type=goal_data.goal_type,
        target_value=goal_data.target_value,
        status="Active"
    )
    db.add(new_goal)
    db.commit()
    db.refresh(new_goal)
    return new_goal

@router.put("/goals/{goal_id}", response_model=schemas.UserGoalResponse)
def update_goal(
    goal_id: int,
    goal_data: schemas.UserGoalUpdate,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=400, detail="Profile not found.")
        
    goal = db.query(models.UserGoal).filter(
        models.UserGoal.id == goal_id,
        models.UserGoal.profile_id == profile.id
    ).first()
    
    if not goal or goal.status == "Deleted":
        raise HTTPException(status_code=404, detail="Goal not found.")
        
    if goal_data.target_value is not None:
        goal.target_value = goal_data.target_value
    if goal_data.status is not None:
        goal.status = goal_data.status
        if goal_data.status == "Completed":
            goal.completed_at = datetime.datetime.utcnow()
            
    db.commit()
    db.refresh(goal)
    return goal

@router.put("/settings", response_model=schemas.SettingsResponse)
def update_settings(
    settings_data: schemas.SettingsUpdate,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    settings = db.query(models.Settings).filter(models.Settings.user_id == user_id).first()
    
    if not settings:
        settings = models.Settings(
            user_id=user_id,
            reminder_time=settings_data.reminder_time,
            push_notifications_enabled=settings_data.push_notifications_enabled if settings_data.push_notifications_enabled is not None else False
        )
        db.add(settings)
    else:
        if settings_data.reminder_time is not None:
            settings.reminder_time = settings_data.reminder_time
        if settings_data.push_notifications_enabled is not None:
            settings.push_notifications_enabled = settings_data.push_notifications_enabled
            
    db.commit()
    db.refresh(settings)
    return settings

@router.post("/consent", response_model=schemas.ConsentResponse)
def record_consent(
    consent_data: schemas.ConsentCreate,
    request: Request,
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    ip_address = request.client.host if request.client else None
    
    consent_log = models.ConsentLog(
        user_id=user_id,
        policy_version=consent_data.policy_version,
        consent_granted=consent_data.consent_granted,
        ip_address=ip_address
    )
    
    db.add(consent_log)
    db.commit()
    db.refresh(consent_log)
    return consent_log

@router.get("/consent", response_model=List[schemas.ConsentResponse])
def get_consent_history(
    user_id: int = Depends(get_user_id_from_token),
    db: Session = Depends(get_db)
):
    consents = db.query(models.ConsentLog).filter(
        models.ConsentLog.user_id == user_id
    ).order_by(models.ConsentLog.timestamp.desc()).all()
    
    return consents
