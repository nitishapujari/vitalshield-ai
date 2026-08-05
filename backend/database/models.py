from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
import datetime
from .db import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    name = Column(String, nullable=False)
    account_status = Column(String, default="active")
    last_login = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
    deleted_at = Column(DateTime, nullable=True)

    profiles = relationship("Profile", back_populates="user", cascade="all, delete-orphan")
    settings = relationship("Settings", back_populates="user", uselist=False, cascade="all, delete-orphan")
    data_source_integrations = relationship("DataSourceIntegration", back_populates="user", cascade="all, delete-orphan")
    consent_logs = relationship("ConsentLog", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    revoked_at = Column(DateTime, nullable=True)
    
    user = relationship("User", back_populates="refresh_tokens")


class Profile(Base):
    __tablename__ = "profiles"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    dob = Column(DateTime, nullable=True)
    gender = Column(String, nullable=False, default="")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    deleted_at = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="profiles")
    checkins = relationship("CheckIn", back_populates="profile", cascade="all, delete-orphan")
    predictions = relationship("Prediction", back_populates="profile", cascade="all, delete-orphan")
    user_goals = relationship("UserGoal", back_populates="profile", cascade="all, delete-orphan")
    assistant_sessions = relationship("AssistantSession", back_populates="profile", cascade="all, delete-orphan")
    
    # Keeping these for backwards compatibility with existing APIs
    analytics_snapshots = relationship("AnalyticsSnapshot", back_populates="profile", cascade="all, delete-orphan")
    simulations = relationship("Simulation", back_populates="profile", cascade="all, delete-orphan")


class UserGoal(Base):
    __tablename__ = "user_goals"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    goal_type = Column(String, nullable=False)
    target_value = Column(Float, nullable=True)
    status = Column(String, nullable=False, default="Active")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    
    profile = relationship("Profile", back_populates="user_goals")


class Settings(Base):
    __tablename__ = "settings"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reminder_time = Column(String, nullable=True)
    push_notifications_enabled = Column(Boolean, default=False)
    
    user = relationship("User", back_populates="settings")


class DataSourceIntegration(Base):
    __tablename__ = "data_source_integrations"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    provider = Column(String, nullable=False)
    access_token = Column(String, nullable=False)
    refresh_token = Column(String, nullable=True)
    last_sync_timestamp = Column(DateTime, nullable=True)
    status = Column(String, nullable=False, default="Active")
    
    user = relationship("User", back_populates="data_source_integrations")


class ConsentLog(Base):
    __tablename__ = "consent_logs"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    policy_version = Column(String, nullable=False)
    consent_granted = Column(Boolean, nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    ip_address = Column(String, nullable=True)
    
    user = relationship("User", back_populates="consent_logs")


class CheckIn(Base):
    __tablename__ = "checkins"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    data_source = Column(String, nullable=False, default="Manual")
    client_timezone_offset = Column(Integer, nullable=True, default=0) # Minutes offset from UTC
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    
    # Nullable metrics
    sleep_hours = Column(Float, nullable=True)
    steps = Column(Integer, nullable=True)
    heart_rate = Column(Integer, nullable=True)
    systolic = Column(Integer, nullable=True)
    diastolic = Column(Integer, nullable=True)
    glucose = Column(Float, nullable=True)
    
    extended_metrics = Column(Text, nullable=True) # JSON

    profile = relationship("Profile", back_populates="checkins")
    predictions = relationship("Prediction", back_populates="checkin", cascade="all, delete-orphan")


class Prediction(Base):
    __tablename__ = "predictions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    checkin_id = Column(Integer, ForeignKey("checkins.id", ondelete="CASCADE"), nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    overall_score = Column(Integer, nullable=False)
    primary_category = Column(String, nullable=False)
    insight = Column(String, nullable=False)
    
    category_scores = Column(Text, nullable=True) # JSON
    critical_alert_triggered = Column(Boolean, default=False)
    model_version = Column(String, nullable=True)
    
    # Legacy field to avoid breaking current schema/business logic entirely
    prediction_json = Column(Text, nullable=False) 
    prediction_hash = Column(String, index=True, nullable=True)

    profile = relationship("Profile", back_populates="predictions")
    checkin = relationship("CheckIn", back_populates="predictions")


class AssistantSession(Base):
    __tablename__ = "assistant_sessions"
    
    id = Column(String, primary_key=True, index=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    title = Column(String, nullable=True)
    status = Column(String, nullable=False, default="Active")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    profile = relationship("Profile", back_populates="assistant_sessions")
    messages = relationship("AssistantMessage", back_populates="session", cascade="all, delete-orphan")


class AssistantMessage(Base):
    __tablename__ = "assistant_messages"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(String, ForeignKey("assistant_sessions.id", ondelete="CASCADE"), nullable=False)
    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    
    session = relationship("AssistantSession", back_populates="messages")


class Notification(Base):
    __tablename__ = "notifications"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    scheduled_for = Column(DateTime, nullable=True)
    status = Column(String, nullable=False, default="Pending")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    user = relationship("User", back_populates="notifications")


# Keeping these existing tables that were requested to be deleted but might be needed by the untouched API
class AnalyticsSnapshot(Base):
    __tablename__ = "analytics_snapshots"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    analytics_json = Column(Text, nullable=False)
    profile = relationship("Profile", back_populates="analytics_snapshots")

class Simulation(Base):
    __tablename__ = "simulations"
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    input_json = Column(Text, nullable=False)
    output_json = Column(Text, nullable=False)
    profile = relationship("Profile", back_populates="simulations")
