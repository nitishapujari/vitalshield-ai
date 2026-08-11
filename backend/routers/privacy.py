from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, status
from sqlalchemy.orm import Session
import datetime
import json
import logging

from database.db import get_db
from database import models
from schemas import schemas
from core.security import get_active_user_id

router = APIRouter(prefix="/privacy", tags=["System (Privacy)"])
logger = logging.getLogger(__name__)

# --- PRIVACY CONSENT ---
@router.post("/consent", response_model=schemas.ConsentResponse)
def log_privacy_consent(
    req: schemas.ConsentCreate,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    consent = models.ConsentLog(
        user_id=user_id,
        policy_version=req.policy_version,
        consent_granted=req.consent_granted,
        ip_address=None # Would capture from request in real app
    )
    db.add(consent)
    db.commit()
    db.refresh(consent)
    return consent

# --- PRIVACY EXPORT ---
def background_data_export(user_id: int):
    # Dummy worker to represent the background task
    logger.info(f"Starting background data export for user {user_id}")
    import time
    time.sleep(2) # Simulate work
    logger.info(f"Background data export for user {user_id} completed.")

@router.post("/export", response_model=schemas.PrivacyExportResponse)
def request_data_export(
    background_tasks: BackgroundTasks,
    user_id: int = Depends(get_active_user_id)
):
    background_tasks.add_task(background_data_export, user_id)
    return schemas.PrivacyExportResponse(status="Processing, email will be sent")

# --- ACCOUNT DELETION ---
@router.delete("/account", response_model=schemas.AccountDeletionResponse)
def request_account_deletion(
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    # Soft delete the User
    user.account_status = "deleted"
    if not user.deleted_at:
        user.deleted_at = datetime.datetime.utcnow()

    # Soft delete associated Profile(s)
    profiles = db.query(models.Profile).filter(models.Profile.user_id == user_id).all()
    for profile in profiles:
        if not profile.deleted_at:
            profile.deleted_at = datetime.datetime.utcnow()

    db.commit()
    return schemas.AccountDeletionResponse(status="Account scheduled for deletion.")
