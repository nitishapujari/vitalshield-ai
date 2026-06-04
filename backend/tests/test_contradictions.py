import os
import sys

# Ensure backend package dir is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.predict_service import generate_wellness_prediction, resolve_recommendation_conflicts

def test_recommendation_priority_metadata():
    """Verify that recommendationPriority field is present and correctly populated."""
    metrics = {
        "sleep_hours": 8.0,
        "steps": 10000,
        "heart_rate": 72,
        "systolic": 120,
        "diastolic": 80,
        "glucose": 90.0
    }
    res = generate_wellness_prediction(metrics, gender="female")
    categories = res["categories"]
    
    assert len(categories) == 5
    for c in categories:
        assert "recommendationPriority" in c
        assert c["recommendationPriority"] in ["Critical", "Warning", "Info"]

def test_emergency_suppression_hypertensive_crisis():
    """Verify that BP crisis (Critical) suppresses other lower-priority recommendations."""
    metrics = {
        "sleep_hours": 5.0,  # Sleep Warning
        "steps": 1000,       # Activity Warning
        "heart_rate": 90,
        "systolic": 185,     # BP Crisis (Critical)
        "diastolic": 125,    # BP Crisis (Critical)
        "glucose": 90.0      # Glucose Info
    }
    res = generate_wellness_prediction(metrics, gender="female")
    categories = res["categories"]

    # Since BP Crisis is active, all other non-critical category recommendations must be suppressed (empty string)
    bp_cat = next(c for c in categories if c["categoryTitle"] == "Blood Pressure Wellness")
    sleep_cat = next(c for c in categories if c["categoryTitle"] == "Sleep Wellness")
    activity_cat = next(c for c in categories if c["categoryTitle"] == "Activity Wellness")

    assert bp_cat["recommendationPriority"] == "Critical"
    assert "emergency" in bp_cat["recommendation"].lower() or "crisis" in bp_cat["recommendation"].lower()
    
    assert sleep_cat["recommendation"] == ""
    assert activity_cat["recommendation"] == ""

def test_emergency_suppression_hypoglycemia():
    """Verify that severe hypoglycemia (Critical) suppresses other lower-priority recommendations."""
    metrics = {
        "sleep_hours": 5.0,  # Sleep Warning
        "steps": 1000,       # Activity Warning
        "heart_rate": 90,
        "systolic": 120,     # BP Info
        "diastolic": 80,     # BP Info
        "glucose": 45.0      # Severe Hypoglycemia (Critical)
    }
    res = generate_wellness_prediction(metrics, gender="female")
    categories = res["categories"]

    glucose_cat = next(c for c in categories if c["categoryTitle"] == "Glucose Wellness")
    sleep_cat = next(c for c in categories if c["categoryTitle"] == "Sleep Wellness")
    activity_cat = next(c for c in categories if c["categoryTitle"] == "Activity Wellness")

    assert glucose_cat["recommendationPriority"] == "Critical"
    assert "fast-acting carbohydrates" in glucose_cat["recommendation"]
    
    assert sleep_cat["recommendation"] == ""
    assert activity_cat["recommendation"] == ""

def test_mixed_emergency_ordering():
    """Verify deterministic critical ordering: 1. Hypoglycemia, 2. BP Crisis, 3. Hyperglycemia."""
    # Test Hypoglycemia + BP Crisis: Hypoglycemia must be first, BP Crisis second
    metrics_hypo_bp = {
        "sleep_hours": 8.0,
        "steps": 10000,
        "heart_rate": 72,
        "systolic": 185,     # BP Crisis (Critical)
        "diastolic": 125,    # BP Crisis (Critical)
        "glucose": 45.0      # Hypoglycemia (Critical)
    }
    res = generate_wellness_prediction(metrics_hypo_bp, gender="female")
    categories = res["categories"]
    
    # First should be Glucose, second should be Blood Pressure
    assert categories[0]["categoryTitle"] == "Glucose Wellness"
    assert categories[1]["categoryTitle"] == "Blood Pressure Wellness"
    assert categories[0]["recommendationPriority"] == "Critical"
    assert categories[1]["recommendationPriority"] == "Critical"
    # Others should be suppressed
    assert categories[2]["recommendation"] == ""

    # Test BP Crisis + Hyperglycemia: BP Crisis must be first, Hyperglycemia second
    metrics_bp_hyper = {
        "sleep_hours": 8.0,
        "steps": 10000,
        "heart_rate": 72,
        "systolic": 185,     # BP Crisis (Critical)
        "diastolic": 125,    # BP Crisis (Critical)
        "glucose": 350.0     # Hyperglycemia (Critical)
    }
    res = generate_wellness_prediction(metrics_bp_hyper, gender="female")
    categories = res["categories"]
    
    # First should be Blood Pressure, second should be Glucose (since crit_rank is 2 vs 1)
    assert categories[0]["categoryTitle"] == "Blood Pressure Wellness"
    assert categories[1]["categoryTitle"] == "Glucose Wellness"

    # Test Hypoglycemia + Hyperglycemia + BP Crisis (Physiologically impossible but verifies deterministic sort)
    # 1. Hypoglycemia (<55) and Hyperglycemia (>300) cannot occur together on same glucose value, but if they could:
    # Here, we test Hypoglycemia + BP Crisis, which sorts Hypoglycemia (Glucose) -> BP Crisis.
    # We test BP Crisis + Hyperglycemia, which sorts BP Crisis -> Hyperglycemia (Glucose).
    # This guarantees the full order: Hypoglycemia -> BP Crisis -> Hyperglycemia.

def test_warning_level_suppression_low_bp():
    """Verify low BP warning suppresses Activity suggestions to prevent dizziness/fall risk."""
    metrics = {
        "sleep_hours": 8.0,
        "steps": 1000,       # Activity Warning (under target)
        "heart_rate": 72,
        "systolic": 85,      # Low BP Warning
        "diastolic": 55,     # Low BP Warning
        "glucose": 90.0
    }
    res = generate_wellness_prediction(metrics, gender="female")
    categories = res["categories"]
    
    activity_cat = next(c for c in categories if c["categoryTitle"] == "Activity Wellness")
    bp_cat = next(c for c in categories if c["categoryTitle"] == "Blood Pressure Wellness")
    
    assert bp_cat["recommendationPriority"] == "Warning"
    # Activity suggestion must be suppressed
    assert activity_cat["recommendation"] == ""

def test_deduplication_merging():
    """Verify deduplication merging rules for similar recommendations."""
    # 1. Sleep + low HR Warnings:
    categories = [
        {"categoryTitle": "Sleep Wellness", "score": 50, "severity": "Warning", "recommendation": "Try to rest for 7-9 hours to improve energy and recovery."},
        {"categoryTitle": "Heart Wellness", "score": 60, "severity": "Warning", "recommendation": "Your resting heart rate is lower than typical. If you are an active athlete, this may be normal. Otherwise, ensure you are well-rested."},
        {"categoryTitle": "Blood Pressure Wellness", "score": 88, "severity": "Info", "recommendation": "Maintain your balanced lifestyle to support vascular wellness."}
    ]
    resolved = resolve_recommendation_conflicts(categories, {"heart_rate": 45})
    
    heart_cat = next(c for c in resolved if c["categoryTitle"] == "Heart Wellness")
    sleep_cat = next(c for c in resolved if c["categoryTitle"] == "Sleep Wellness")
    assert "resting heart rate" in heart_cat["recommendation"]
    assert "sleep" in heart_cat["recommendation"]
    assert sleep_cat["recommendation"] == ""

    # 2. Activity + high HR Warnings:
    categories2 = [
        {"categoryTitle": "Activity Wellness", "score": 55, "severity": "Warning", "recommendation": "Try incorporating a 15-minute walk to support comfortable circulation and recovery."},
        {"categoryTitle": "Heart Wellness", "score": 60, "severity": "Warning", "recommendation": "Focus on cardiovascular balance and light activity."},
    ]
    resolved2 = resolve_recommendation_conflicts(categories2, {"heart_rate": 105})
    
    heart_cat = next(c for c in resolved2 if c["categoryTitle"] == "Heart Wellness")
    activity_cat = next(c for c in resolved2 if c["categoryTitle"] == "Activity Wellness")
    assert "cardiovascular balance" in heart_cat["recommendation"]
    assert "15-minute walk" in heart_cat["recommendation"]
    assert activity_cat["recommendation"] == ""

    # 3. BP Variation + Activity Info:
    categories3 = [
        {"categoryTitle": "Blood Pressure Wellness", "score": 65, "severity": "Warning", "recommendation": "Consider moderating sodium intake and exploring relaxation routines."},
        {"categoryTitle": "Activity Wellness", "score": 85, "severity": "Info", "recommendation": "Incorporate brief movement intervals throughout the day."}
    ]
    resolved3 = resolve_recommendation_conflicts(categories3, {})
    
    bp_cat = next(c for c in resolved3 if c["categoryTitle"] == "Blood Pressure Wellness")
    activity_cat = next(c for c in resolved3 if c["categoryTitle"] == "Activity Wellness")
    assert "sodium" in bp_cat["recommendation"]
    assert "standing breaks" in bp_cat["recommendation"]
    assert activity_cat["recommendation"] == ""
