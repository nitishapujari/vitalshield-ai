import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.model_selection import train_test_split
import pickle
import os


def calculate_score(row):
    """Calculate wellness score from health metrics.

    Scoring philosophy:
    - Base score of 70.
    - Bonuses for optimal ranges, penalties for deviations.
    - Safety override: emergency-level BP or glucose → hard cap at 40.
    """
    score = 70

    # --- Safety Emergency Override ---
    # Hypertensive crisis: SBP >= 180 OR DBP >= 120
    if row['systolic'] >= 180 or row['diastolic'] >= 120:
        return 40
    # Severe hypoglycemia: Glucose < 55
    if row['glucose'] < 55:
        return 40
    # Severe hyperglycemia: Glucose > 300
    if row['glucose'] > 300:
        return 40

    # --- Sleep ---
    if 7.0 <= row['sleep_hours'] <= 9.0:
        score += 10
    elif row['sleep_hours'] < 6.0:
        score -= 10
    elif row['sleep_hours'] < 7.0:
        score -= 5

    # --- Steps ---
    if row['steps'] >= 10000:
        score += 15
    elif row['steps'] >= 5000:
        score += 8
    else:
        score -= 5

    # --- Heart Rate ---
    if 50 <= row['heart_rate'] <= 100:
        score += 5
    else:
        score -= 5

    # --- Blood Pressure ---
    if 90 <= row['systolic'] <= 120 and 60 <= row['diastolic'] <= 80:
        score += 5
    else:
        score -= 3

    # --- Glucose ---
    if 70 <= row['glucose'] <= 100:
        score += 5
    elif row['glucose'] < 70:
        score -= 5
    elif 100 < row['glucose'] <= 200:
        score -= 2
    else:
        score -= 15

    return max(0, min(100, score))


# -------------------------------------------------------------------------
# DETERMINISTIC TIE-BREAKING PRIORITY
# Higher index = higher clinical priority.
# When multiple categories share the highest severity, the category
# with the highest clinical priority wins.
# -------------------------------------------------------------------------
_CLINICAL_PRIORITY = {
    'Activity Wellness': 0,
    'Sleep Wellness': 1,
    'Heart Wellness': 2,
    'Blood Pressure Wellness': 3,
    'Glucose Wellness': 4,
}


def _category_severity(row):
    """Evaluate each wellness category independently and return severities.

    Returns a dict mapping category name → integer severity.
    Higher severity means more clinically significant deviation.
    Severity scale:
        0 = within normal limits
        1 = mild abnormality
        2 = moderate abnormality
        3 = emergency / critical
    """
    severities = {}

    # --- Sleep ---
    if row['sleep_hours'] < 6.0:
        severities['Sleep Wellness'] = 2
    elif row['sleep_hours'] < 7.0:
        severities['Sleep Wellness'] = 1
    else:
        severities['Sleep Wellness'] = 0

    # --- Activity ---
    if row['steps'] < 5000:
        severities['Activity Wellness'] = 1
    else:
        severities['Activity Wellness'] = 0

    # --- Heart Rate ---
    if row['heart_rate'] < 50 or row['heart_rate'] > 100:
        severities['Heart Wellness'] = 1
    else:
        severities['Heart Wellness'] = 0

    # --- Blood Pressure ---
    sbp = row['systolic']
    dbp = row['diastolic']
    if sbp >= 180 or dbp >= 120:
        severities['Blood Pressure Wellness'] = 3
    elif sbp < 90 or dbp < 60 or sbp > 120 or dbp > 80:
        severities['Blood Pressure Wellness'] = 1
    else:
        severities['Blood Pressure Wellness'] = 0

    # --- Glucose ---
    g = row['glucose']
    if g < 55 or g > 300:
        severities['Glucose Wellness'] = 3
    elif g < 70 or g > 200:
        severities['Glucose Wellness'] = 1
    else:
        severities['Glucose Wellness'] = 0

    return severities


def determine_category(row):
    """Select the primary wellness category using independent severity evaluation.

    Algorithm:
    1. Evaluate each category's severity independently (no short-circuiting).
    2. Find the maximum severity across all categories.
    3. If max severity is 0, the user is 'Optimal'.
    4. If multiple categories share the max severity, use deterministic
       clinical-priority tie-breaking (glucose > BP > heart > sleep > activity).
    """
    severities = _category_severity(row)

    max_sev = max(severities.values())
    if max_sev == 0:
        return 'Optimal'

    # Collect all categories at the max severity level
    candidates = [cat for cat, sev in severities.items() if sev == max_sev]

    # Deterministic tie-break: highest clinical priority wins
    candidates.sort(key=lambda c: _CLINICAL_PRIORITY[c], reverse=True)
    return candidates[0]


def generate_synthetic_data(num_samples=2000, seed=42):
    """Generate synthetic health data with realistic physiological correlations.

    Correlations injected:
    1. SBP ↔ DBP: DBP derived from SBP via linear model + noise.
    2. Steps → RHR: High activity lowers resting heart rate.
    3. Sleep → RHR: Poor sleep elevates resting heart rate.
    4. Elevated BP → RHR: Hypertension elevates resting heart rate.
    5. Emergency coverage: bounds expanded to include critical profiles.
    """
    if seed is not None:
        np.random.seed(seed)

    # --- Independent base features ---
    sleep_hours = np.random.normal(7, 1.5, num_samples).clip(3, 12)
    steps = np.random.normal(6000, 3000, num_samples).clip(0, 20000)

    # SBP: expanded range to include hypertensive crisis (up to 200)
    systolic = np.random.normal(115, 15, num_samples).clip(80, 200)

    # Glucose: expanded range to include severe hypo/hyperglycemia
    glucose = np.random.normal(95, 20, num_samples).clip(40, 350)

    # --- Correlated features ---

    # 1. DBP correlated with SBP:  DBP ≈ 0.5 × SBP + 17.5 + noise
    diastolic = (0.5 * systolic + 17.5 + np.random.normal(0, 5, num_samples))
    diastolic = diastolic.clip(40, 120)
    # Enforce physiological constraint: SBP must exceed DBP by ≥ 20 mmHg
    too_close = systolic < (diastolic + 20)
    diastolic[too_close] = systolic[too_close] - 20

    # 2. Base RHR
    heart_rate = np.random.normal(75, 15, num_samples)

    # 3. Activity → RHR: high activity lowers RHR, low activity raises it
    high_activity = steps >= 12000
    low_activity = steps <= 3000
    heart_rate[high_activity] -= np.random.uniform(5, 12, high_activity.sum())
    heart_rate[low_activity] += np.random.uniform(2, 6, low_activity.sum())

    # 4. Poor sleep → RHR elevation
    poor_sleep = sleep_hours < 6.0
    heart_rate[poor_sleep] += np.random.uniform(4, 10, poor_sleep.sum())

    # 5. Elevated BP → RHR elevation
    elevated_bp = systolic > 130
    heart_rate[elevated_bp] += np.random.uniform(3, 8, elevated_bp.sum())

    # Final clamp
    heart_rate = heart_rate.clip(40, 180)

    data = {
        'sleep_hours': sleep_hours,
        'steps': steps,
        'heart_rate': heart_rate,
        'systolic': systolic,
        'diastolic': diastolic,
        'glucose': glucose,
    }

    df = pd.DataFrame(data)
    df['overall_score'] = df.apply(calculate_score, axis=1)
    df['primary_category'] = df.apply(determine_category, axis=1)

    return df


def generate_emergency_dataset(seed=77):
    """Generate a dedicated emergency validation dataset with guaranteed coverage.

    Creates 200 profiles across 4 emergency categories:
    - 50 Hypertensive Crisis (SBP >= 180 and/or DBP >= 120)
    - 50 Severe Hypoglycemia (glucose < 55)
    - 50 Severe Hyperglycemia (glucose > 300)
    - 50 Mixed Emergency (multiple simultaneous critical abnormalities)

    Non-emergency features are randomized within plausible ranges to ensure
    the model is tested against realistic combinations, not just edge-case
    extremes on a single axis.
    """
    if seed is not None:
        np.random.seed(seed)

    records = []

    def _base_features():
        """Generate plausible non-emergency baseline features."""
        return {
            'sleep_hours': np.random.uniform(4.0, 9.0),
            'steps': np.random.uniform(1000, 12000),
            'heart_rate': np.random.uniform(55, 110),
        }

    # --- 1. Hypertensive Crisis (SBP >= 180 and/or DBP >= 120) ---
    for _ in range(50):
        r = _base_features()
        # Randomly choose: high SBP only, high DBP only, or both
        variant = np.random.choice(['sbp', 'dbp', 'both'])
        if variant == 'sbp':
            r['systolic'] = np.random.uniform(180, 210)
            r['diastolic'] = np.random.uniform(70, 110)
        elif variant == 'dbp':
            r['systolic'] = np.random.uniform(130, 170)
            r['diastolic'] = np.random.uniform(120, 140)
        else:
            r['systolic'] = np.random.uniform(185, 220)
            r['diastolic'] = np.random.uniform(120, 140)
        # Enforce SBP > DBP + 20
        if r['systolic'] < r['diastolic'] + 20:
            r['systolic'] = r['diastolic'] + 25
        r['glucose'] = np.random.uniform(70, 100)  # normal glucose
        r['_emergency_type'] = 'hypertensive_crisis'
        records.append(r)

    # --- 2. Severe Hypoglycemia (glucose < 55) ---
    for _ in range(50):
        r = _base_features()
        r['systolic'] = np.random.uniform(100, 135)
        r['diastolic'] = np.random.uniform(60, 85)
        if r['systolic'] < r['diastolic'] + 20:
            r['systolic'] = r['diastolic'] + 25
        r['glucose'] = np.random.uniform(30, 54.9)
        r['_emergency_type'] = 'severe_hypoglycemia'
        records.append(r)

    # --- 3. Severe Hyperglycemia (glucose > 300) ---
    for _ in range(50):
        r = _base_features()
        r['systolic'] = np.random.uniform(100, 140)
        r['diastolic'] = np.random.uniform(60, 90)
        if r['systolic'] < r['diastolic'] + 20:
            r['systolic'] = r['diastolic'] + 25
        r['glucose'] = np.random.uniform(301, 450)
        r['_emergency_type'] = 'severe_hyperglycemia'
        records.append(r)

    # --- 4. Mixed Emergency (multiple simultaneous critical abnormalities) ---
    for _ in range(50):
        r = _base_features()
        # Always hypertensive crisis
        r['systolic'] = np.random.uniform(185, 220)
        r['diastolic'] = np.random.uniform(120, 140)
        if r['systolic'] < r['diastolic'] + 20:
            r['systolic'] = r['diastolic'] + 25
        # Randomly add severe hypo or hyperglycemia
        if np.random.random() < 0.5:
            r['glucose'] = np.random.uniform(30, 54.9)
        else:
            r['glucose'] = np.random.uniform(301, 450)
        r['_emergency_type'] = 'mixed_emergency'
        records.append(r)

    df = pd.DataFrame(records)
    # Store emergency type before scoring
    emergency_types = df['_emergency_type'].copy()
    df = df.drop(columns=['_emergency_type'])

    df['overall_score'] = df.apply(calculate_score, axis=1)
    df['primary_category'] = df.apply(determine_category, axis=1)
    df['_emergency_type'] = emergency_types

    return df


def train_models():
    print("Generating synthetic data (5000 samples with physiological correlations)...")
    df = generate_synthetic_data(5000)

    # Augment training data with dedicated emergency profiles so the model
    # learns the score ceiling at 40 for critical vitals.
    print("Injecting emergency training profiles (500 samples)...")
    df_emergency = generate_emergency_dataset(seed=42)
    # Generate additional emergency batches with different seeds for variety
    for extra_seed in [43, 44]:
        df_emergency = pd.concat(
            [df_emergency, generate_emergency_dataset(seed=extra_seed)],
            ignore_index=True
        )
    # Drop the metadata column before merging
    if '_emergency_type' in df_emergency.columns:
        df_emergency = df_emergency.drop(columns=['_emergency_type'])
    df = pd.concat([df, df_emergency], ignore_index=True)
    print(f"Total training samples: {len(df)}")

    # --- Print class distribution ---
    print("\n=== Training Data Class Distribution ===")
    cat_counts = df['primary_category'].value_counts()
    for cat, count in cat_counts.items():
        print(f"  {cat}: {count} ({count/len(df)*100:.1f}%)")

    features = ['sleep_hours', 'steps', 'heart_rate', 'systolic', 'diastolic', 'glucose']
    X = df[features]

    # Train Score Regressor
    y_score = df['overall_score']
    score_model = RandomForestRegressor(n_estimators=100, random_state=42)
    score_model.fit(X, y_score)
    print(f"\nTrained Score Regressor. R^2: {score_model.score(X, y_score):.3f}")

    # Train Category Classifier
    y_cat = df['primary_category']
    cat_model = RandomForestClassifier(n_estimators=100, random_state=42, class_weight='balanced')
    cat_model.fit(X, y_cat)
    print(f"Trained Category Classifier. Accuracy: {cat_model.score(X, y_cat):.3f}")

    # Save Models
    base_dir = os.path.dirname(os.path.abspath(__file__))
    model_dir = os.path.join(base_dir, "models")
    os.makedirs(model_dir, exist_ok=True)
    with open(os.path.join(model_dir, 'score_model.pkl'), 'wb') as f:
        pickle.dump(score_model, f)
    with open(os.path.join(model_dir, 'cat_model.pkl'), 'wb') as f:
        pickle.dump(cat_model, f)

    print(f"\nModels saved successfully to {model_dir}")


if __name__ == "__main__":
    train_models()

