import os
import sys
import json

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.predict_service import generate_wellness_prediction
from services.insight_builder import InsightBuilder
from fastapi.testclient import TestClient
from main import app, get_user_id_from_token, get_db
from database.db import Base
from database import models
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Setup test DB
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_consistency.db"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

def test_centralized_insight_consistency():
    """Verify that Dashboard primary insight, predictions categories, analytics trend text,
    and assistant coaching responses are completely consistent with InsightBuilder outputs."""
    metrics = {
        "sleep_hours": 5.5,  # Sleep Warning
        "steps": 3000,       # Activity Warning
        "heart_rate": 72,
        "systolic": 120,     # BP Optimal
        "diastolic": 80,     # BP Optimal
        "glucose": 90.0      # Glucose Optimal
    }
    
    # 1. Run backend prediction generation
    res = generate_wellness_prediction(metrics, age_category="Adult", gender="female")
    
    # 2. Check schema outputs
    assert "primaryInsight" in res
    assert "categories" in res
    assert "highestImpactOpportunity" in res
    assert "secondaryOpportunity" in res
    assert "stableMetrics" in res
    
    categories = res["categories"]
    highest = res["highestImpactOpportunity"]
    secondary = res["secondaryOpportunity"]
    stable = res["stableMetrics"]
    
    # Verify opportunities are parsed correctly
    assert highest is not None
    assert highest["categoryTitle"] == "Sleep_Wellness" or highest["categoryTitle"] == "Sleep Wellness"
    assert secondary is not None
    assert secondary["categoryTitle"] == "Activity_Wellness" or secondary["categoryTitle"] == "Activity Wellness"
    
    # 3. Verify Dashboard primaryInsight is consistent with the highest impact opportunity
    assert res["primaryInsight"] == highest["insight"]
    
    # 4. Verify stable metrics are correctly identified
    assert "Blood Pressure Wellness" in stable
    assert "Glucose Wellness" in stable
    assert "Heart Wellness" in stable
    
    # 5. Verify Analytics Insight text matches InsightBuilder
    analytics_text = InsightBuilder._generate_analytics_insight(
        sleep_average=5.5,
        sleep_consistency=100,
        activity_average=3000,
        activity_consistency=100,
        is_senior=False
    )
    assert "below the target baseline of 7.0" in analytics_text
    
    # 6. Verify assistant response consistency
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_user_id_from_token] = lambda: 1
    
    client = TestClient(app)
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    
    try:
        # Create mock user/profile
        test_user = models.User(id=1, email="test_const@example.com", password_hash="pwd", name="Sarah")
        db.add(test_user)
        db.commit()
        
        test_profile = models.Profile(id="sarah_const", user_id=1, name="Sarah", gender="female", age_category="Adult")
        db.add(test_profile)
        db.commit()
        
        # Save prediction
        import datetime
        now = datetime.datetime.utcnow()
        new_pred = models.Prediction(
            profile_id="sarah_const",
            timestamp=now,
            overall_score=res["overallWellnessScore"],
            primary_category=res["primary_category"],
            insight=res["primaryInsight"],
            prediction_json=json.dumps(res)
        )
        db.add(new_pred)
        
        new_checkin = models.CheckIn(
            profile_id="sarah_const",
            timestamp=now,
            sleep_hours=5.5,
            steps=3000,
            heart_rate=72,
            systolic=120,
            diastolic=80,
            glucose=90.0
        )
        db.add(new_checkin)
        db.commit()
        
        # Call assistant for improvement advice
        response = client.post("/assistant/message?profile_id=sarah_const", json={"message": "how can I improve?", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        
        # Verify assistant output contains clean names and matches exact text of the opportunities
        assert "sleep" in reply.lower()
        assert "physical activity" in reply.lower()
        assert highest["insight"] in reply
        assert highest["recommendation"] in reply
        assert secondary["insight"] in reply
        assert secondary["recommendation"] in reply
        assert "Blood pressure" in reply
        assert "Fasting glucose" in reply
        
        # Call assistant for sleep category advice
        response_sleep = client.post("/assistant/message?profile_id=sarah_const", json={"message": "tell me about my sleep", "conversation_history": []})
        assert response_sleep.status_code == 200
        reply_sleep = response_sleep.json()["reply"]
        
        # Sleep Wellness categories info
        sleep_cat_data = next(c for c in categories if c["categoryTitle"] == "Sleep Wellness")
        assert sleep_cat_data["insight"] in reply_sleep
        assert sleep_cat_data["recommendation"] in reply_sleep
        
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        if os.path.exists("./test_consistency.db"):
            try:
                os.remove("./test_consistency.db")
            except Exception:
                pass
