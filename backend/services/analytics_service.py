import math
from typing import List, Dict, Any, Optional
import datetime

def calculate_sleep_consistency(sleeps: List[float]) -> int:
    if len(sleeps) < 2:
        return 100
    
    mean = sum(sleeps) / len(sleeps)
    variance = sum((s - mean) ** 2 for s in sleeps) / len(sleeps)
    std_dev = math.sqrt(variance)

    # 0 std deviation means 100% consistency. Each 1 hour of stdDev reduces consistency by 15%.
    score = round(100 - (std_dev * 15))
    return max(30, min(100, score))

def calculate_activity_consistency(steps: List[int]) -> int:
    if len(steps) < 2:
        return 100

    # Cap steps at a target threshold of 5000 to avoid penalizing high variance from extra activity
    capped_steps = [min(s, 5000) for s in steps]
    mean = sum(capped_steps) / len(capped_steps)
    if mean == 0:
        return 100

    variance = sum((s - mean) ** 2 for s in capped_steps) / len(capped_steps)
    std_dev = math.sqrt(variance)

    # Coefficient of variation (stdDev / mean)
    cv = std_dev / mean
    score = round(100 - (cv * 100))
    return max(30, min(100, score))

def generate_trend_insight(
    sleep_average: float,
    sleep_consistency: int,
    activity_average: int,
    activity_consistency: int,
    age_category: Optional[str] = None
) -> str:
    is_senior = age_category in ["Senior", "Senior Citizen"]
    from services.insight_builder import InsightBuilder
    return InsightBuilder._generate_analytics_insight(
        sleep_average=sleep_average,
        sleep_consistency=sleep_consistency,
        activity_average=activity_average,
        activity_consistency=activity_consistency,
        is_senior=is_senior
    )

def generate_analytics_report(
    checkins: List[Dict[str, Any]],
    predictions: List[Dict[str, Any]],
    age_category: Optional[str] = None,
    gender: Optional[str] = None
) -> Dict[str, Any]:
    """
    Generate an AnalyticsReport from check-in list and prediction list.
    """
    # Require at least 1 check-in to begin analytics reporting
    if len(checkins) < 1:
        return {
            "hasEnoughData": False,
            "report": None
        }

    # Sort chronologically (oldest to newest) to draw charts correctly
    # checkin['timestamp'] is a datetime object or ISO string. We will parse it or assume sorted.
    def get_time(item):
        ts = item.get("timestamp")
        if isinstance(ts, str):
            return datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return ts or datetime.datetime.now()

    sorted_checkins = sorted(checkins, key=get_time)
    sorted_predictions = sorted(predictions, key=get_time)

    # 1. Build Wellness Score History
    score_history = []
    for pred in sorted_predictions:
        ts = get_time(pred)
        score_history.append({
            "date": ts.isoformat(),
            "score": float(pred.get("overall_score", pred.get("overallWellnessScore", 70)))
        })

    # 2. Build Sleep Consistency List (Last 7 check-ins)
    recent_checkins = sorted_checkins[-7:] if len(sorted_checkins) > 7 else sorted_checkins

    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    sleep_history = []
    activity_history = []

    for c in recent_checkins:
        ts = get_time(c)
        # Format dayName (e.g. Mon, Tue, etc.)
        day_name = ts.strftime("%a")
        
        sleep_history.append({
            "dayName": day_name,
            "hours": float(c.get("sleep_hours", 0)),
            "date": ts.isoformat()
        })
        
        activity_history.append({
            "dayName": day_name,
            "steps": int(c.get("steps", 0)),
            "date": ts.isoformat()
        })

    # 4. Calculate Averages
    valid_sleeps = [float(c.get("sleep_hours")) for c in sorted_checkins if c.get("sleep_hours") is not None]
    sleep_average = sum(valid_sleeps) / len(valid_sleeps) if valid_sleeps else 0.0

    valid_steps = [int(c.get("steps")) for c in sorted_checkins if c.get("steps") is not None]
    activity_average = round(sum(valid_steps) / len(valid_steps)) if valid_steps else 0

    # 5. Calculate Consistency Percentages
    sleep_consistency = calculate_sleep_consistency(valid_sleeps)
    activity_consistency = calculate_activity_consistency(valid_steps)

    # 6. Generate Trend Insight
    has_critical_emergency = False
    if sorted_checkins:
        latest_c = sorted_checkins[-1]
        sys_val = latest_c.get("systolic")
        dia_val = latest_c.get("diastolic")
        glu_val = latest_c.get("glucose")
        if (sys_val is not None and sys_val >= 180) or (dia_val is not None and dia_val >= 120):
            has_critical_emergency = True
        elif glu_val is not None and (glu_val < 55.0 or glu_val > 300.0):
            has_critical_emergency = True

    if has_critical_emergency:
        insight = "🚨 CRITICAL ALERT: Your latest readings indicate a medical emergency. Please seek immediate medical care. Wellness tracking should resume once your vitals are stable."
    else:
        insight = generate_trend_insight(
            sleep_average=sleep_average,
            sleep_consistency=sleep_consistency,
            activity_average=activity_average,
            activity_consistency=activity_consistency,
            age_category=age_category
        )

    return {
        "hasEnoughData": True,
        "report": {
            "scoreHistory": score_history,
            "sleepHistory": sleep_history,
            "activityHistory": activity_history,
            "sleepAverage": sleep_average,
            "activityAverage": activity_average,
            "sleepConsistencyPercent": sleep_consistency,
            "activityConsistencyPercent": activity_consistency,
            "insightText": insight
        }
    }
