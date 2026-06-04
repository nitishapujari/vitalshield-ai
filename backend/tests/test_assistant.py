import os
import sys
import datetime
import json

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.db import Base
from main import app, get_user_id_from_token, get_db
from database import models

# Setup test DB
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_assistant.db"
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

def test_assistant_behavior():
    # Set overrides inside test execution to avoid import conflicts
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_user_id_from_token] = lambda: 1

    client = TestClient(app)

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # Create test user and profile
        test_user = models.User(id=1, email="test@example.com", password_hash="pwd", name="Sarah")
        db.add(test_user)
        db.commit()
        
        test_profile = models.Profile(id="sarah_id", user_id=1, name="Sarah", gender="female", age_category="Adult")
        db.add(test_profile)
        db.commit()
        
        # Test greeting-only query (does not show wellness score)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "hello", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "Hello Sarah!" in reply
        assert "wellness companion" in reply
        assert "100" not in reply  # wellness score shouldn't be printed
        
        # Now create a prediction and checkin
        now = datetime.datetime.utcnow()
        prediction_data = {
            "overallWellnessScore": 82,
            "categories": [
                {
                    "categoryTitle": "Sleep Wellness",
                    "score": 85,
                    "trend": "stable",
                    "recommendation": "Maintain consistent sleep schedules."
                }
            ],
            "primaryInsight": "Your sleep is looking stable.",
            "is_ml_generated": True
        }
        
        new_pred = models.Prediction(
            profile_id="sarah_id",
            timestamp=now,
            overall_score=82,
            primary_category="Sleep Wellness",
            insight="Your sleep is looking stable.",
            prediction_json=json.dumps(prediction_data)
        )
        db.add(new_pred)
        
        new_checkin = models.CheckIn(
            profile_id="sarah_id",
            timestamp=now,
            sleep_hours=8.0,
            steps=5000,
            heart_rate=70,
            systolic=120,
            diastolic=80,
            glucose=90.0
        )
        db.add(new_checkin)
        db.commit()
        
        # Test greeting-only query again (with prediction data, shouldn't automatically report score)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "hello", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "Hello" in reply
        assert "82" not in reply # Greeting-only should not automatically display wellness score

        # Test multi-intent query (greeting + sleep query) -> should answer sleep query
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "hello How can I sleep better? What should I improve first?", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "sleep" in reply.lower()
        assert "Hello" not in reply  # Should not use greeting fallback reply

        # Test unified unsupported topic handling (weather query)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "how is the weather in Paris?", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "not quite sure how to help with that topic" in reply
        assert "As your wellness companion, I can help you understand" in reply

        # Test unified unsupported topic handling (movies query)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "what is the latest Marvel movie?", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "not quite sure how to help with that topic" in reply
        assert "As your wellness companion, I can help you understand" in reply

        # Test unified unsupported topic handling (sports query)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "who won the IPL match yesterday?", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "not quite sure how to help with that topic" in reply
        assert "As your wellness companion, I can help you understand" in reply

        # Test emergency crisis triage (Default/Unknown region)
        response = client.post("/assistant/message?profile_id=sarah_id", json={"message": "I'm having severe chest pain, help!", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "CRITICAL SAFETY NOTICE" in reply
        assert "local emergency services" in reply

        # Test new emergency patterns
        for msg in ["I collapsed", "I am bleeding heavily", "I want to hurt myself"]:
            response = client.post("/assistant/message?profile_id=sarah_id", json={"message": msg, "conversation_history": []})
            assert response.status_code == 200
            assert "CRITICAL SAFETY NOTICE" in response.json()["reply"]

        # Test fallback/neutral emergency crisis triage for unknown/malformed/empty/exception locales
        for fallback_locale in ["unknown", "", "invalid-locale-format", "xyz_ABC"]:
            response = client.post(f"/assistant/message?profile_id=sarah_id&locale={fallback_locale}", json={"message": "I want to end my life", "conversation_history": []})
            assert response.status_code == 200
            r_reply = response.json()["reply"]
            assert "CRITICAL SAFETY NOTICE" in r_reply
            assert "local emergency services" in r_reply
            assert "emergency medical provider" in r_reply
            assert "crisis hotline" in r_reply
            assert "trusted emergency contact" in r_reply
            for restricted in ["911", "988", "999", "112"]:
                assert restricted not in r_reply

        # Test emergency crisis triage (US region)
        response = client.post("/assistant/message?profile_id=sarah_id&locale=en_US", json={"message": "I want to commit suicide", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "CRITICAL SAFETY NOTICE" in reply
        assert "911" in reply
        assert "988" in reply

        # Test emergency crisis triage (IN region)
        response = client.post("/assistant/message?profile_id=sarah_id&locale=en_IN", json={"message": "kill myself", "conversation_history": []})
        assert response.status_code == 200
        reply = response.json()["reply"]
        assert "CRITICAL SAFETY NOTICE" in reply
        assert "112" in reply
        assert "14416" in reply

        print("Backend assistant behavioral tests passed!")
        
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        # Clean up database file
        if os.path.exists("./test_assistant.db"):
            try:
                os.remove("./test_assistant.db")
            except Exception:
                pass

if __name__ == "__main__":
    test_assistant_behavior()
