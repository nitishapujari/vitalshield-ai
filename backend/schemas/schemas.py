from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

# --- AUTH SCHEMAS ---
class UserSignup(BaseModel):
    email: str
    password: str
    name: str

class UserLogin(BaseModel):
    email: str
    password: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: int
    email: str
    name: str

class RefreshRequest(BaseModel):
    refresh_token: str

# --- PROFILE SCHEMAS ---
class ProfileCreate(BaseModel):
    name: str
    dob: Optional[datetime] = None
    gender: str = ""

class ProfileUpdateRequest(BaseModel):
    name: Optional[str] = None
    dob: Optional[datetime] = None
    gender: Optional[str] = None

class ProfileResponse(BaseModel):
    id: str
    user_id: int
    name: str
    dob: Optional[datetime] = None
    gender: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class UserGoalCreate(BaseModel):
    goal_type: str
    target_value: Optional[float] = None

class UserGoalUpdate(BaseModel):
    target_value: Optional[float] = None
    status: Optional[str] = None

class UserGoalResponse(BaseModel):
    id: int
    goal_type: str
    target_value: Optional[float] = None
    status: str
    
    class Config:
        from_attributes = True

class SettingsUpdate(BaseModel):
    reminder_time: Optional[str] = None
    push_notifications_enabled: Optional[bool] = None

class SettingsResponse(BaseModel):
    id: int
    reminder_time: Optional[str] = None
    push_notifications_enabled: bool
    
    class Config:
        from_attributes = True

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    account_status: str
    
    class Config:
        from_attributes = True

class UserMeResponse(BaseModel):
    user: UserResponse
    profile: Optional[ProfileResponse] = None
    active_goals: List[UserGoalResponse] = []
    settings: Optional[SettingsResponse] = None

# --- CHECK-IN SCHEMAS ---
class CheckInCreate(BaseModel):
    sleep_hours: float
    steps: int
    heart_rate: int
    systolic: int
    diastolic: int
    glucose: float
    timestamp: Optional[datetime] = None

class CheckInResponse(BaseModel):
    id: int
    profile_id: str
    timestamp: datetime
    sleep_hours: float
    steps: int
    heart_rate: int
    systolic: int
    diastolic: int
    glucose: float

    class Config:
        from_attributes = True

# --- PREDICTION SCHEMAS ---
class MetricsInput(BaseModel):
    sleep_hours: float
    steps: int
    heart_rate: int
    systolic: int
    diastolic: int
    glucose: float

class PredictionGenerate(BaseModel):
    metrics: MetricsInput
    age: Optional[int] = None
    age_category: Optional[str] = None
    gender: Optional[str] = None
    cycle_phase: Optional[str] = None

class ContributingFactorSchema(BaseModel):
    label: str
    impact: str
    contributionPercent: float
    description: str

class PredictionExplanationSchema(BaseModel):
    factors: List[ContributingFactorSchema]

class PredictionCategorySchema(BaseModel):
    categoryTitle: str
    score: int
    status: str
    trendDirection: str
    insight: str
    recommendation: str
    severity: Optional[str] = "Info"
    recommendationPriority: Optional[str] = "Info"
    impactLevel: Optional[str] = "Low"
    scoreImprovementEstimate: Optional[float] = 0.0
    explanation: Optional[PredictionExplanationSchema] = None

class OpportunitySchema(BaseModel):
    categoryTitle: str
    insight: str
    recommendation: str
    recommendationPriority: str
    impactLevel: str
    scoreImprovementEstimate: float

class PredictionSnapshotResponse(BaseModel):
    id: str
    timestamp: datetime
    overallWellnessScore: int
    categories: List[PredictionCategorySchema]
    primaryInsight: str
    is_ml_generated: bool
    predictionHash: Optional[str] = None
    sleepHours: Optional[float] = None
    steps: Optional[int] = None
    heartRate: Optional[int] = None
    systolic: Optional[int] = None
    diastolic: Optional[int] = None
    glucose: Optional[float] = None
    highestImpactOpportunity: Optional[OpportunitySchema] = None
    secondaryOpportunity: Optional[OpportunitySchema] = None
    stableMetrics: List[str] = []

class PredictionSyncItem(BaseModel):
    id: str
    timestamp: datetime
    overallWellnessScore: int
    categories: List[PredictionCategorySchema]
    primaryInsight: str
    is_ml_generated: bool
    predictionHash: str
    sleepHours: Optional[float] = None
    steps: Optional[int] = None
    heartRate: Optional[int] = None
    systolic: Optional[int] = None
    diastolic: Optional[int] = None
    glucose: Optional[float] = None
    highestImpactOpportunity: Optional[OpportunitySchema] = None
    secondaryOpportunity: Optional[OpportunitySchema] = None
    stableMetrics: List[str] = []

# --- SIMULATION SCHEMAS ---
class SimulationRunRequest(BaseModel):
    # Base baseline checkin
    sleep_hours: float
    steps: int
    heart_rate: int
    systolic: int
    diastolic: int
    glucose: float
    
    # What to modify
    target_metric: str # e.g. 'sleep_hours', 'steps'
    target_value: float

class SimulationRunResponse(BaseModel):
    original_score: int
    simulated_score: int
    score_difference: int
    primary_category_original: str
    primary_category_simulated: str
    impact_description: str

# --- ASSISTANT SCHEMAS ---
class AssistantMessageRequest(BaseModel):
    message: str
    conversation_history: List[Dict[str, str]] = [] # list of {"role": "user"/"assistant", "content": "..."}

class AssistantResponse(BaseModel):
    reply: str

# --- PREFERENCE SCHEMAS ---
class ReminderPreferenceSave(BaseModel):
    settings_json: str

class CycleCarePreferenceSave(BaseModel):
    settings_json: str

# --- HABIT SIMULATION SCHEMAS ---
class HabitSimulationRequest(BaseModel):
    sleep_hours: float
    steps: int
    consistency_level: float
    routine_quality: float
    is_senior: bool

class HabitSimulationResponse(BaseModel):
    projected_score: int

