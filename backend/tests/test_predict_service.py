import os
import sys

# Ensure backend package dir is on sys.path when running tests directly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services import predict_service

if __name__ == '__main__':
    metrics = {
        'sleep_hours': 7.5,
        'steps': 7200,
        'heart_rate': 72,
        'systolic': 118,
        'diastolic': 78,
        'glucose': 88.5,
    }

    res = predict_service.generate_wellness_prediction(metrics, age_category='Adult', gender='female')

    # Basic sanity checks
    if 'overallWellnessScore' not in res:
        raise SystemExit('Missing overallWellnessScore')
    if 'categories' not in res or not isinstance(res['categories'], list):
        raise SystemExit('Categories missing or invalid')
    if 'primaryInsight' not in res:
        raise SystemExit('Missing primaryInsight')

    print('predict_service basic checks passed')
