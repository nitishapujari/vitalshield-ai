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
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    profiles = relationship("Profile", back_populates="user", cascade="all, delete-orphan")

class Profile(Base):
    __tablename__ = "profiles"

    # We use String for ID because Flutter profiles have client-generated IDs (e.g. profile_1779264719167)
    id = Column(String, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    dob = Column(DateTime, nullable=True)
    gender = Column(String, nullable=False, default="")
    height = Column(Float, nullable=True)
    weight = Column(Float, nullable=True)
    bmi = Column(Float, nullable=True)
    activity_level = Column(String, nullable=True)
    height_unit = Column(String, nullable=False, default="cm")
    wellness_tracking_enabled = Column(Boolean, default=False)
    age = Column(Integer, nullable=True)
    age_category = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="profiles")
    checkins = relationship("CheckIn", back_populates="profile", cascade="all, delete-orphan")
    predictions = relationship("Prediction", back_populates="profile", cascade="all, delete-orphan")
    analytics_snapshots = relationship("AnalyticsSnapshot", back_populates="profile", cascade="all, delete-orphan")
    simulations = relationship("Simulation", back_populates="profile", cascade="all, delete-orphan")
    reminder_preference = relationship("ReminderPreference", back_populates="profile", uselist=False, cascade="all, delete-orphan")
    cycle_preference = relationship("CycleCarePreference", back_populates="profile", uselist=False, cascade="all, delete-orphan")
    conversations = relationship("AssistantConversation", back_populates="profile", cascade="all, delete-orphan")

class CheckIn(Base):
    __tablename__ = "checkins"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    sleep_hours = Column(Float, nullable=False)
    steps = Column(Integer, nullable=False)
    heart_rate = Column(Integer, nullable=False)
    systolic = Column(Integer, nullable=False)
    diastolic = Column(Integer, nullable=False)
    glucose = Column(Float, nullable=False)

    profile = relationship("Profile", back_populates="checkins")

class Prediction(Base):
    __tablename__ = "predictions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    overall_score = Column(Integer, nullable=False)
    primary_category = Column(String, nullable=False)
    insight = Column(String, nullable=False)
    prediction_json = Column(Text, nullable=False) # Stores the complete PredictionModel fields (including metrics, explainability)
    prediction_hash = Column(String, index=True, nullable=True)

    profile = relationship("Profile", back_populates="predictions")

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

class ReminderPreference(Base):
    __tablename__ = "reminder_preferences"

    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True)
    settings_json = Column(Text, nullable=False)

    profile = relationship("Profile", back_populates="reminder_preference")

class CycleCarePreference(Base):
    __tablename__ = "cycle_preferences"

    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True)
    settings_json = Column(Text, nullable=False)

    profile = relationship("Profile", back_populates="cycle_preference")

class AssistantConversation(Base):
    __tablename__ = "assistant_conversations"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    messages_json = Column(Text, nullable=False) # JSON array of the message history
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    profile = relationship("Profile", back_populates="conversations")
