import os
import pickle
import pandas as pd
import numpy as np
from sklearn.metrics import confusion_matrix
import sys

sys.path.append(r"c:\Users\Nitisha Pujari\Documents\programming\dev\projects\vitalshield_ai\backend")
from model_trainer import generate_synthetic_data

def inspect():
    model_dir = r"c:\Users\Nitisha Pujari\Documents\programming\dev\projects\vitalshield_ai\backend\models"
    with open(os.path.join(model_dir, 'score_model.pkl'), 'rb') as f:
        score_model = pickle.load(f)
    with open(os.path.join(model_dir, 'cat_model.pkl'), 'rb') as f:
        cat_model = pickle.load(f)
        
    features = ['sleep_hours', 'steps', 'heart_rate', 'systolic', 'diastolic', 'glucose']
    
    np.random.seed(99)
    df_test = generate_synthetic_data(1000, seed=99)
    X_test = df_test[features]
    y_score_test = df_test['overall_score']
    y_cat_test = df_test['primary_category']
    
    # Class distribution
    print("=== TEST SET CLASS DISTRIBUTION ===")
    dist = y_cat_test.value_counts()
    for cat, val in dist.items():
        print(f"{cat:25s}: {val} ({val/len(y_cat_test)*100.2:.1f}%)")
        
    # Classifier predictions
    y_cat_pred = cat_model.predict(X_test)
    classes = sorted(list(y_cat_test.unique()))
    print(f"\n=== FULL CONFUSION MATRIX ===")
    cm = confusion_matrix(y_cat_test, y_cat_pred, labels=classes)
    pd.set_option('display.max_columns', None)
    pd.set_option('display.width', 1000)
    cm_df = pd.DataFrame(cm, index=classes, columns=classes)
    print(cm_df)

if __name__ == "__main__":
    inspect()
