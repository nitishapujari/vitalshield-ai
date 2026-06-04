import os
import pickle
import numpy as np
from typing import List, Dict, Any, Tuple

# Path to models
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_DIR = os.path.join(BASE_DIR, "models")
SCORE_MODEL_PATH = os.path.join(MODEL_DIR, "score_model.pkl")
CAT_MODEL_PATH = os.path.join(MODEL_DIR, "cat_model.pkl")

# Load models globally
score_model = None
cat_model = None

def load_ml_models():
    global score_model, cat_model
    if os.path.exists(SCORE_MODEL_PATH) and os.path.exists(CAT_MODEL_PATH):
        try:
            with open(SCORE_MODEL_PATH, "rb") as f:
                score_model = pickle.load(f)
            with open(CAT_MODEL_PATH, "rb") as f:
                cat_model = pickle.load(f)
            print("ML Models loaded successfully in PredictService.")
        except Exception as e:
            print(f"Error loading ML models: {e}")
    else:
        print(f"Warning: ML Models not found at {MODEL_DIR}. Fallbacks will be used.")

# Initialize model loading
load_ml_models()

# Optimal reference values for perturbation-based explainability
OPTIMAL_REFERENCES = {
    "sleep_hours": 8.0,
    "steps": 10000,
    "heart_rate": 75,
    "systolic": 115,
    "diastolic": 75,
    "glucose": 85,
}

FEATURE_INDEXES = {
    "sleep_hours": 0,
    "steps": 1,
    "heart_rate": 2,
    "systolic": 3,
    "diastolic": 4,
    "glucose": 5,
}

FEATURE_LABELS = {
    "sleep_hours": "Sleep Duration",
    "steps": "Physical Activity",
    "heart_rate": "Resting Heart Rate",
    "systolic": "Systolic BP",
    "diastolic": "Diastolic BP",
    "glucose": "Fasting Glucose",
}

def get_factor_impact_and_desc(feature: str, val: float, is_senior: bool, is_female: bool, diff: float) -> Tuple[str, str]:
    """
    Classify factor impact (positive, neutral, negative) and generate a natural language explanation.
    """
    # Define thresholds without demographic adjustments
    if feature == "sleep_hours":
        target = 7.0
        if val >= target and val <= 9.0:
            return "positive", "Your restful sleep duration supported optimal recovery."
        elif val < target:
            return "negative", "Shorter sleep duration reduced your recovery capacity."
        else:
            return "neutral", "Extended rest was recorded, which is restorative but alters your rhythm."
            
    elif feature == "steps":
        target = 5000
        if val >= target:
            return "positive", f"Active movement of {int(val)} steps supported circulation."
        else:
            return "negative", "Lower physical movement reduced wellness stability today."
            
    elif feature == "heart_rate":
        hr_min = 50
        hr_max = 100
        if hr_min <= val <= hr_max:
            return "positive", "Your resting heart rate remains in a stable, calm range."
        else:
            return "negative", "Resting heart rate showed slight elevation or variation."
            
    elif feature in ["systolic", "diastolic"]:
        # We handle blood pressure features individually
        if feature == "systolic":
            if 90 <= val <= 120:
                return "positive", "Systolic pressure remains in a balanced, healthy range."
            elif val < 90:
                return "negative", "Systolic pressure is slightly below the normal range."
            else:
                return "negative", "Systolic blood pressure shows minor elevation today."
        else:
            if 60 <= val <= 80:
                return "positive", "Diastolic pressure remains steady and comfortable."
            elif val < 60:
                return "negative", "Diastolic pressure is slightly below the normal range."
            else:
                return "negative", "Diastolic blood pressure is slightly elevated."
                
    elif feature == "glucose":
        if 70 <= val <= 100:
            return "positive", "Fasting glucose levels indicate excellent energy balance."
        elif 100 < val <= 200:
            return "neutral", "Glucose level is mildly elevated compared to fasting baseline."
        elif val > 200:
            return "negative", "Glucose level was significantly elevated."
        else:
            return "negative", "Fasting energy reserves were slightly lower than typical baseline."

    # General fallback
    if diff < -0.5:
        return "negative", f"{FEATURE_LABELS.get(feature, feature)} had a lower impact today."
    elif diff > 0.5:
        return "positive", f"{FEATURE_LABELS.get(feature, feature)} contributed positively to your score."
    else:
        return "neutral", f"{FEATURE_LABELS.get(feature, feature)} remained stable."

def compute_perturbation_xai(metrics: Dict[str, Any], is_senior: bool, is_female: bool) -> List[Dict[str, Any]]:
    """
    Computes feature contributions by replacing each feature with its optimal reference value
    and measuring the change in the predicted score.
    """
    if score_model is None:
        # Static fallback if model is not loaded
        return [
            {"label": FEATURE_LABELS[k], "impact": "positive" if k in ["sleep_hours", "steps"] else "neutral", "contributionPercent": 16.6, "description": "Metric remains in a stable range.", "scoreImprovementEstimate": 0.0}
            for k in FEATURE_INDEXES.keys()
        ]

    # Map features to a numpy array matching model requirements
    features_input = np.array([[
        metrics.get("sleep_hours", 7.0),
        metrics.get("steps", 5000),
        metrics.get("heart_rate", 72),
        metrics.get("systolic", 120),
        metrics.get("diastolic", 80),
        metrics.get("glucose", 90.0)
    ]])
    
    base_pred = score_model.predict(features_input)[0]
    
    contributions = []
    total_diff = 0.0
    diffs = {}
    
    # Calculate difference for each feature
    for feature, index in FEATURE_INDEXES.items():
        perturbed_features = features_input.copy()
        # Replace feature with its optimal reference
        perturbed_features[0, index] = OPTIMAL_REFERENCES[feature]
        perturbed_pred = score_model.predict(perturbed_features)[0]
        
        # Contribution difference (current score - score if this feature was optimal)
        # If current value is worse than optimal, perturbed_pred > base_pred, so diff < 0 (negative impact)
        diff = base_pred - perturbed_pred
        diffs[feature] = diff
        total_diff += abs(diff)

    # Convert to percentages and format
    for feature, diff in diffs.items():
        val = metrics.get(feature, OPTIMAL_REFERENCES[feature])
        impact, description = get_factor_impact_and_desc(feature, val, is_senior, is_female, diff)
        
        # Calculate percentage contribution
        contrib_percent = (abs(diff) / total_diff * 100.0) if total_diff > 0 else 16.67
        
        contributions.append({
            "label": FEATURE_LABELS[feature],
            "impact": impact,
            "contributionPercent": round(contrib_percent, 1),
            "description": description,
            "scoreImprovementEstimate": round(abs(diff), 1) if diff < 0 else 0.0
        })
        
    return contributions

def generate_wellness_prediction(
    metrics: Dict[str, Any],
    age_category: str = None,
    gender: str = None,
    cycle_phase: str = None
) -> Dict[str, Any]:
    """
    Full ML prediction pipeline:
    1. Feeds check-in metrics to RandomForestRegressor for the Overall Score.
    2. Feeds metrics to RandomForestClassifier for the primary attention category.
    3. Runs XAI perturbation contributions.
    4. Delegates explanations, wording, and ranking to the centralized InsightBuilder.
    5. Returns a production-grade PredictionSnapshotModel representation.
    """
    is_senior = age_category in ["Senior", "Senior Citizen"]
    is_female = gender.lower() == "female" if gender else False

    sleep_val = metrics.get("sleep_hours", 7.0)
    steps_val = metrics.get("steps", 5000)
    hr_val = metrics.get("heart_rate", 72)
    sys_val = metrics.get("systolic", 120)
    dia_val = metrics.get("diastolic", 80)
    glu_val = metrics.get("glucose", 90.0)

    # 1. Run ML Models
    is_ml_generated = False
    ml_score = None
    ml_primary_category = None

    if score_model is not None and cat_model is not None:
        try:
            features = np.array([[sleep_val, steps_val, hr_val, sys_val, dia_val, glu_val]])
            ml_score = int(round(score_model.predict(features)[0]))
            ml_primary_category = str(cat_model.predict(features)[0])
            is_ml_generated = True
        except Exception as e:
            print(f"ML Inference failed: {e}. Falling back to rule-based evaluation.")

    # 2. Compute perturbation-based explainability (XAI)
    xai_factors = compute_perturbation_xai(metrics, is_senior, is_female)

    # 3. Delegate to Centralized InsightBuilder
    from services.insight_builder import InsightBuilder
    built = InsightBuilder.build_insights(
        metrics=metrics,
        is_senior=is_senior,
        is_female=is_female,
        cycle_phase=cycle_phase,
        xai_factors=xai_factors
    )

    # 4. Calculate final calibrated overall score
    if ml_score is not None:
        overall_score = max(0, min(100, ml_score))
    else:
        # Rule-based fallback score
        avg_score = sum(c["score"] for c in built["categories"]) / len(built["categories"])
        overall_score = int(round(max(0, min(100, avg_score))))

    # Apply penalty if rule-based fallback
    if ml_score is None:
        needs_attention_count = sum(1 for c in built["categories"] if c["trendDirection"] == "needsAttention")
        penalty = 0
        if needs_attention_count == 1:
            penalty = 5
        elif needs_attention_count == 2:
            penalty = 15
        elif needs_attention_count >= 3:
            penalty = 25
        overall_score = max(0, overall_score - penalty)

    # Apply Safety Overrides: cap overall score to <= 40 if any critical vitals emergency is present
    is_critical_emergency = any(c["recommendationPriority"] == "Critical" for c in built["categories"])
    if is_critical_emergency:
        overall_score = min(overall_score, 40)

    # Attach explanation factors
    for c in built["categories"]:
        title = c["categoryTitle"]
        if title == "Sleep Wellness":
            relevant = [f for f in xai_factors if f["label"] == "Sleep Duration"]
        elif title == "Activity Wellness":
            relevant = [f for f in xai_factors if f["label"] == "Physical Activity"]
        elif title == "Heart Wellness":
            relevant = [f for f in xai_factors if f["label"] == "Resting Heart Rate"]
        elif title == "Blood Pressure Wellness":
            relevant = [f for f in xai_factors if f["label"] in ["Systolic BP", "Diastolic BP"]]
        else:
            relevant = [f for f in xai_factors if f["label"] == "Fasting Glucose"]
        c["explanation"] = {"factors": relevant}

    # Determine primary category for attention
    primary_category = ml_primary_category
    if not primary_category:
        min_cat = min(built["categories"], key=lambda x: x["score"])
        primary_category = min_cat["categoryTitle"] if min_cat["score"] < 85 else "Optimal"

    # Synchronize primary insight
    primary_insight = built["primaryInsight"]

    return {
        "overallWellnessScore": overall_score,
        "primary_category": primary_category,
        "primaryInsight": primary_insight,
        "is_ml_generated": is_ml_generated,
        "categories": built["categories"],
        "xai_factors": xai_factors,
        "highestImpactOpportunity": built["highestImpactOpportunity"],
        "secondaryOpportunity": built["secondaryOpportunity"],
        "stableMetrics": built["stableMetrics"]
    }

def resolve_recommendation_conflicts(categories: List[Dict[str, Any]], metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Wrapper for testing compatibility. Delegates to InsightBuilder.
    """
    for c in categories:
        if "recommendationPriority" not in c and "severity" in c:
            c["recommendationPriority"] = c["severity"]
        if "scoreImprovementEstimate" not in c:
            c["scoreImprovementEstimate"] = 0.0
        if "impactLevel" not in c:
            c["impactLevel"] = "Low"

    from services.insight_builder import InsightBuilder
    resolved = InsightBuilder._resolve_and_rank(categories, metrics)

    for c in resolved:
        if "severity" not in c and "recommendationPriority" in c:
            c["severity"] = c["recommendationPriority"]

    return resolved

