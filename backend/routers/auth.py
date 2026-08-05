from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
import secrets

from database.db import get_db
from database import models
from schemas import schemas
from core import security

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)

@router.post("/register", response_model=schemas.AuthResponse)
def register(user_data: schemas.UserSignup, db: Session = Depends(get_db)):
    # Check if user exists
    existing_user = db.query(models.User).filter(models.User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
        
    # Create new user
    hashed_password = security.get_password_hash(user_data.password)
    new_user = models.User(
        email=user_data.email,
        password_hash=hashed_password,
        name=user_data.name
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Generate tokens
    access_token = security.create_access_token({"sub": str(new_user.id)})
    refresh_token_str = security.create_refresh_token({"sub": str(new_user.id)})
    
    # Persist refresh token
    decoded_refresh = security.decode_token(refresh_token_str)
    expires_at = datetime.fromtimestamp(decoded_refresh["exp"])
    
    rt_model = models.RefreshToken(
        user_id=new_user.id,
        token=refresh_token_str,
        expires_at=expires_at
    )
    db.add(rt_model)
    db.commit()
    
    return schemas.AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        user_id=new_user.id,
        email=new_user.email,
        name=new_user.name
    )

@router.post("/login", response_model=schemas.AuthResponse)
def login(login_data: schemas.UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == login_data.email).first()
    if not user or not security.verify_password(login_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
        
    # Generate tokens
    access_token = security.create_access_token({"sub": str(user.id)})
    refresh_token_str = security.create_refresh_token({"sub": str(user.id)})
    
    # Persist refresh token
    decoded_refresh = security.decode_token(refresh_token_str)
    expires_at = datetime.fromtimestamp(decoded_refresh["exp"])
    
    rt_model = models.RefreshToken(
        user_id=user.id,
        token=refresh_token_str,
        expires_at=expires_at
    )
    db.add(rt_model)
    
    # Update last login
    user.last_login = datetime.utcnow()
    db.commit()
    
    return schemas.AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        user_id=user.id,
        email=user.email,
        name=user.name
    )

@router.post("/refresh", response_model=schemas.AuthResponse)
def refresh(request: schemas.RefreshRequest, db: Session = Depends(get_db)):
    token = request.refresh_token
    payload = security.decode_token(token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
        
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(status_code=401, detail="Invalid token payload")
        
    user_id = int(user_id_str)
    
    # Check if token exists and is not revoked
    rt_model = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == token,
        models.RefreshToken.user_id == user_id
    ).first()
    
    if not rt_model or rt_model.revoked_at is not None:
        raise HTTPException(status_code=401, detail="Token has been revoked or is invalid")
        
    if rt_model.expires_at < datetime.utcnow():
        raise HTTPException(status_code=401, detail="Token has expired")
        
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Revoke old refresh token (Token Rotation)
    rt_model.revoked_at = datetime.utcnow()
    
    # Issue new tokens
    new_access_token = security.create_access_token({"sub": str(user.id)})
    new_refresh_token_str = security.create_refresh_token({"sub": str(user.id)})
    
    new_decoded = security.decode_token(new_refresh_token_str)
    new_expires_at = datetime.fromtimestamp(new_decoded["exp"])
    
    new_rt_model = models.RefreshToken(
        user_id=user.id,
        token=new_refresh_token_str,
        expires_at=new_expires_at
    )
    db.add(new_rt_model)
    db.commit()
    
    return schemas.AuthResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token_str,
        user_id=user.id,
        email=user.email,
        name=user.name
    )

@router.post("/logout")
def logout(request: schemas.RefreshRequest, db: Session = Depends(get_db)):
    token = request.refresh_token
    rt_model = db.query(models.RefreshToken).filter(models.RefreshToken.token == token).first()
    
    if rt_model:
        rt_model.revoked_at = datetime.utcnow()
        db.commit()
        
    return {"message": "Successfully logged out"}
