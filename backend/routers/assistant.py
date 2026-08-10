from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Dict, Any
import datetime
import uuid
import json

from database.db import get_db
from database import models
from schemas import schemas
from core.security import get_active_user_id
from services.assistant_service import is_emergency_query, get_regional_crisis_response, generate_assistant_response

router = APIRouter(prefix="/me/assistant/chats", tags=["Assistant"])

def get_current_profile(user_id: int, db: Session) -> models.Profile:
    profile = db.query(models.Profile).filter(models.Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found.")
    return profile

def get_session_or_404(session_id: str, profile_id: str, db: Session) -> models.AssistantSession:
    session = db.query(models.AssistantSession).filter(
        models.AssistantSession.id == session_id,
        models.AssistantSession.profile_id == profile_id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Chat session not found.")
    return session

@router.get("", response_model=List[schemas.AssistantSessionResponse])
def get_chats(
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_current_profile(user_id, db)
    sessions = db.query(models.AssistantSession).filter(
        models.AssistantSession.profile_id == profile.id
    ).order_by(desc(models.AssistantSession.created_at)).all()
    return sessions

@router.post("", response_model=schemas.AssistantSessionResponse)
def create_chat(
    req: schemas.ChatCreateRequest,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_current_profile(user_id, db)

    title = req.title.strip() if req.title and req.title.strip() else "New Chat"

    new_session = models.AssistantSession(
        id=str(uuid.uuid4()),
        profile_id=profile.id,
        title=title,
        status="Active",
        created_at=datetime.datetime.utcnow()
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    return new_session

@router.get("/{session_id}", response_model=schemas.ChatDetailResponse)
def get_chat_details(
    session_id: str,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_current_profile(user_id, db)
    session = get_session_or_404(session_id, profile.id, db)

    messages = db.query(models.AssistantMessage).filter(
        models.AssistantMessage.session_id == session.id
    ).order_by(models.AssistantMessage.timestamp.asc()).all()

    return schemas.ChatDetailResponse(
        session=session,
        messages=messages
    )

@router.post("/{session_id}/messages", response_model=schemas.AssistantMessageResponse)
def create_message(
    session_id: str,
    req: schemas.MessageCreateRequest,
    user_id: int = Depends(get_active_user_id),
    db: Session = Depends(get_db)
):
    profile = get_current_profile(user_id, db)
    session = get_session_or_404(session_id, profile.id, db)

    message_text = req.message.strip()
    if not message_text:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")
    if len(message_text) > 1000:
        raise HTTPException(status_code=400, detail="Message exceeds maximum length of 1000 characters.")

    # Fetch History BEFORE adding the new user message
    history_db = db.query(models.AssistantMessage).filter(
        models.AssistantMessage.session_id == session.id
    ).order_by(desc(models.AssistantMessage.timestamp)).limit(10).all()
    history_db.reverse()
    history_list = [{"role": msg.role, "content": msg.content} for msg in history_db]

    # Save user message
    user_msg = models.AssistantMessage(
        session_id=session.id,
        role="user",
        content=message_text,
        timestamp=datetime.datetime.utcnow()
    )
    db.add(user_msg)

    # 1. Check Crisis
    if is_emergency_query(message_text):
        crisis_reply = get_regional_crisis_response(locale=None) # Or read from user context if available
        ai_msg = models.AssistantMessage(
            session_id=session.id,
            role="assistant",
            content=crisis_reply,
            timestamp=datetime.datetime.utcnow()
        )
        db.add(ai_msg)
        db.commit()
        db.refresh(ai_msg)
        return ai_msg

    # 2. Build Context
    start_of_created_day = datetime.datetime.combine(profile.created_at.date(), datetime.time.min)

    # 2a. Latest Prediction
    latest_pred = db.query(models.Prediction).filter(
        models.Prediction.profile_id == profile.id,
        models.Prediction.timestamp >= start_of_created_day
    ).order_by(desc(models.Prediction.timestamp)).first()

    pred_data = {}
    if latest_pred:
        try:
            pred_data = json.loads(latest_pred.prediction_json)
        except Exception:
            pass

    # 2b. Latest CheckIn
    latest_checkin = db.query(models.CheckIn).filter(
        models.CheckIn.profile_id == profile.id,
        models.CheckIn.timestamp >= start_of_created_day
    ).order_by(desc(models.CheckIn.timestamp)).first()

    checkin_data = {}
    if latest_checkin:
        checkin_data = {
            "sleep_hours": latest_checkin.sleep_hours,
            "steps": latest_checkin.steps,
            "heart_rate": latest_checkin.heart_rate,
            "systolic": latest_checkin.systolic,
            "diastolic": latest_checkin.diastolic,
            "glucose": latest_checkin.glucose,
            "timestamp": latest_checkin.timestamp.isoformat()
        }

    # 2c. Active User Goals
    active_goals = db.query(models.UserGoal).filter(
        models.UserGoal.profile_id == profile.id,
        models.UserGoal.status == "Active"
    ).all()
    goals_data = [{"goal_type": g.goal_type, "target_value": g.target_value} for g in active_goals]

    age_category = "Adult"
    if profile.dob:
        age = (datetime.datetime.utcnow().date() - profile.dob.date()).days / 365.25
        if age < 30:
            age_category = "Young Adult"
        elif age < 60:
            age_category = "Adult"
        else:
            age_category = "Senior"

    context = {
        "profile_name": profile.name,
        "age_category": age_category,
        "gender": profile.gender,
        "prediction": pred_data,
        "latest_checkin": checkin_data,
        "active_goals": goals_data
    }

    # 3. History is already built (history_list)

    # 4. Generate LLM Mock Response
    try:
        reply_text = generate_assistant_response(message_text, context, history_list)
    except Exception as e:
        # LLM generation failed, commit the user message but return 503
        db.commit()
        print(f"Assistant generation failed: {e}")
        raise HTTPException(status_code=503, detail="Service Unavailable: Assistant failed to generate a response.")

    # Save Assistant Response
    ai_msg = models.AssistantMessage(
        session_id=session.id,
        role="assistant",
        content=reply_text,
        timestamp=datetime.datetime.utcnow()
    )
    db.add(ai_msg)
    db.commit()
    db.refresh(ai_msg)

    return ai_msg
