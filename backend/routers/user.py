from fastapi import APIRouter, Depends, HTTPException
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
