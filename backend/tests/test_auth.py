import os
import sys

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.db import Base
from main import app, get_user_id_from_token, get_db
from database import models

# Setup test DB
SQLALCHEMY_DATABASE_URL = "sqlite:///./test_auth_endpoints.db"
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

def test_auth_signup_validation():
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_user_id_from_token] = lambda: 1

    client = TestClient(app)

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # 1. Test weak passwords (should be rejected)
        weak_passwords = [
            ("a", "Password must be at least 8 characters long."),
            ("1234", "Password must be at least 8 characters long."),
            ("password", "Password must contain at least one uppercase letter."),
            ("qwerty", "Password must be at least 8 characters long."),
            ("abc123", "Password must be at least 8 characters long."),
            ("Password", "Password must contain at least one number."),
            ("password123", "Password must contain at least one uppercase letter."),
        ]

        for pwd, expected_err in weak_passwords:
            response = client.post("/auth/signup", json={
                "email": "test@example.com",
                "password": pwd,
                "name": "Sarah"
            })
            assert response.status_code == 400, f"Expected 400 for password '{pwd}', got {response.status_code}"
            assert response.json()["detail"] == expected_err

        # 2. Test valid password (should be accepted)
        response = client.post("/auth/signup", json={
            "email": "test@example.com",
            "password": "Password123",
            "name": "Sarah"
        })
        assert response.status_code == 200
        data = response.json()
        assert "token" in data
        assert data["email"] == "test@example.com"
        assert data["name"] == "Sarah"

        # 3. Test duplicate email registration (should be rejected)
        response = client.post("/auth/signup", json={
            "email": "test@example.com",
            "password": "Password123",
            "name": "Another Name"
        })
        assert response.status_code == 400
        assert response.json()["detail"] == "Email already registered."

    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)
        if os.path.exists("./test_auth_endpoints.db"):
            try:
                os.remove("./test_auth_endpoints.db")
            except Exception:
                pass
