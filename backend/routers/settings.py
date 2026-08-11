from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import datetime

from database.db import get_db
from database import models
from schemas import schemas
from core.security import get_active_user_id

router = APIRouter(prefix="", tags=["System (Settings & Notifications)"])

# --- SETTINGS ---
@router.get("/settings", response_model=schemas.SettingsResponse)
def get_settings(
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    settings = db.query(models.Settings).filter(models.Settings.user_id == user_id).first()
    if not settings:
        # Create default settings if none exist
        settings = models.Settings(
            user_id=user_id,
            reminder_time=None,
            push_notifications_enabled=False
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings

@router.put("/settings", response_model=schemas.SettingsResponse)
def update_settings(
    req: schemas.SettingsUpdate,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    settings = db.query(models.Settings).filter(models.Settings.user_id == user_id).first()
    if not settings:
        settings = models.Settings(user_id=user_id)
        db.add(settings)
        db.flush()

    if req.reminder_time is not None:
        settings.reminder_time = req.reminder_time
    if req.push_notifications_enabled is not None:
        settings.push_notifications_enabled = req.push_notifications_enabled

    db.commit()
    db.refresh(settings)
    return settings

# --- NOTIFICATIONS ---
@router.get("/notifications", response_model=List[schemas.NotificationResponse])
def get_notifications(
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    notifications = db.query(models.Notification).filter(
        models.Notification.user_id == user_id
    ).order_by(models.Notification.created_at.desc()).all()
    return notifications

@router.put("/notifications/{notification_id}/read", response_model=schemas.NotificationResponse)
def mark_notification_read(
    notification_id: int,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    notification = db.query(models.Notification).filter(
        models.Notification.id == notification_id,
        models.Notification.user_id == user_id
    ).first()

    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found.")

    notification.status = "Read"

    db.commit()
    db.refresh(notification)
    return notification
