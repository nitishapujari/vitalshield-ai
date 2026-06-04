# VitalShield AI: Intelligent Wellness Companion

[![Flutter Version](https://img.shields.io/badge/Flutter-Stable-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI Version](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Scikit-Learn](https://img.shields.io/badge/scikit--learn-RF--Models-F7931E?logo=scikit-learn)](https://scikit-learn.org)
[![Platform Support](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)](#)
[![Test Suite](https://img.shields.io/badge/Tests-85%20Passed-4CAF50)](https://github.com/)

VitalShield AI is a state-of-the-art wellness intelligence and monitoring platform designed as a portfolio-quality B.Tech AI/Data Science demonstration project. The application captures daily health vitals, computes predictive wellness scores, applies clinical safety overrides, and provides conversational health coaching via an AI Wellness Assistant.

---

## 📌 Problem Statement

Traditional health monitoring systems suffer from three critical flaws:
1. **Rigid Connectivity Reliance**: Many systems become non-functional offline, leaving users without access to predictions or AI advisory when network coverage is lost.
2. **Clinical Safety Blindspots**: Standard machine learning models (like Random Forests) cannot extrapolate safety ceilings for extreme out-of-distribution values (e.g., critical blood pressure or blood sugar), potentially presenting high wellness scores during life-threatening crises.
3. **Conflicting & Unactionable Guidance**: Apps often deliver generic, disconnected tips (e.g., recommending a user in a hypertensive crisis to "increase activity to burn calories" or displaying duplicate, wordy insights across different screens).

**VitalShield AI solves these challenges** by implementing a resilient, offline-first hybrid architecture, incorporating deterministic safety override barriers, and utilizing a centralized `InsightBuilder` layer to enforce actionable, prioritized, and contradiction-free health guidance.

---

## 🎨 Core Value Propositions & Features

* **Offline-First Resilience**: An identical local prediction engine implemented in Dart runs when backend connectivity fails, namespacing offline check-ins and auto-syncing them with the backend when connection is restored.
* **Dual-Model ML Pipeline**: A RandomForest Regressor calculates the overall wellness score, while a RandomForest Classifier identifies the primary wellness domain requiring attention.
* **Clinical Safety Overrides & Suppression**: Enforces hard ceiling caps (Score $\le 40$) and triggers critical notifications during emergencies (SBP $\ge 180$, DBP $\ge 120$, Glucose $< 55$ or $> 300$). Lower-priority advice is suppressed to prevent medical contradictions.
* **Centralized `InsightBuilder`**: Establishes a single source of truth (duplicated in Python and Dart) that enforces physiology-focused actionable wording templates and computes quantitative `scoreImprovementEstimate` impact metrics.
* **AI Wellness Assistant**: An interactive wellness coach that parses the user's latest health snapshots to answer queries. Falls back to a deterministic rule-based dialogue tree offline.
* **Advanced Step Consistency**: Employs an activity consistency metric utilizing the Coefficient of Variation ($CV = \sigma / \mu$), capping steps at $5,000$ to prevent penalizing active users for extra movement.
* **Multi-Profile Management**: Supports namespaced profile switching for separate family members, ensuring complete database and local storage isolation.

---

## 📐 System Architecture

```mermaid
graph TD
    subgraph Client [Flutter Mobile & Web Client]
        UI[Responsive UI Screens]
        AuthService[AuthService]
        SyncService[PredictionSyncService]
        Storage[StorageService SharedPreferences]
        SecureStore[FlutterSecureStorage]
        LocalEngine[Dart Local Engine]
        DartBuilder[Dart InsightBuilder]
    end

    subgraph Server [FastAPI Backend Service]
        Endpoints[FastAPI Endpoints]
        PyBuilder[Python InsightBuilder]
        PredictService[PredictService]
        MLModels[RandomForest Regressor & Classifier]
        SQLite[(SQLite DB)]
    end

    UI --> AuthService
    UI --> SyncService
    AuthService --> SecureStore
    Storage <--> UI
    
    %% Offline Fallback Loop
    UI --> LocalEngine
    LocalEngine --> DartBuilder
    
    %% Online Flow
    SyncService <--> Endpoints
    Endpoints --> PyBuilder
    Endpoints --> PredictService
    PredictService --> MLModels
    Endpoints <--> SQLite

    classDef client fill:#1A2240,stroke:#6C63FF,stroke-width:2px,color:#F0F0F5;
    classDef server fill:#0A0E1A,stroke:#67E8F9,stroke-width:2px,color:#F0F0F5;
    class UI,AuthService,SyncService,Storage,SecureStore,LocalEngine,DartBuilder client;
    class Endpoints,PyBuilder,PredictService,MLModels,SQLite server;
```

---

## 🛠️ Technology Stack

* **Frontend Framework**: Flutter (Dart)
  - *State Management*: Riverpod
  - *Routing*: GoRouter (Declarative, URL-aware routing)
  - *UI Package*: Lucide Icons, Google Fonts (Inter)
* **Backend Framework**: FastAPI (Python)
  - *Server*: Uvicorn
  - *ORM*: SQLAlchemy
  - *Security*: Passlib (PBKDF2 Password Hashing), JWT-inspired HMAC-SHA256 tokens
* **Machine Learning**: Scikit-Learn
  - *Models*: RandomForestRegressor, RandomForestClassifier
  - *Data Manipulation*: Pandas, NumPy
* **Local Persistence**: `SharedPreferences` (Profiles, metrics), `FlutterSecureStorage` (Tokens)
* **Database**: SQLite (Highly portable, development-ready)
* **Containerization**: Docker, Docker Compose

---

## 🧠 Machine Learning & Data Pipeline

### 1. Training Dataset Generation & Physiology Correlations
The training dataset is generated synthetically (5,600 samples) inside `model_trainer.py`. Unlike naive random generators, it simulates true physiological relationships:
* **SBP-DBP Coupling**: Enforces diastolic blood pressure based on systolic:
  $$\text{DBP} = 0.5 \times \text{SBP} + 17.5 + \mathcal{N}(0, 5) \quad \text{s.t.} \quad \text{SBP} \ge \text{DBP} + 20$$
* **Poor Sleep to resting heart rate (RHR)**: Sleep $< 6\text{h}$ increases RHR by $4\text{--}10\text{ BPM}$.
* **Activity to RHR**: Steps $\ge 12,000$ reduce RHR by $5\text{--}12\text{ BPM}$; steps $\le 3,000$ increase RHR by $2\text{--}6\text{ BPM}$.
* **Elevated BP to RHR**: SBP $> 130$ mmHg increases RHR by $3\text{--}8\text{ BPM}$.
* **Emergency Augmentation**: Includes $600$ guaranteed hypertensive crisis, severe hypoglycemia, and hyperglycemia profiles.

### 2. Clinical Safety Overrides
Because standard ML classifiers cannot extrapolate out-of-distribution values, hard caps are applied:
* If SBP $\ge 180$, DBP $\ge 120$, Glucose $< 55$, or Glucose $> 300$, the labeling function overrides the regression score to $40$ and sets the classification category to `Critical`.
* This ensures that the ML models train on capped values and that the rule-based safety barrier is preserved in production.

---

## 🔒 Security Features

1. **Secure Token Storage**: Encrypts JWT tokens on mobile Keystore (Android) and Keychain (iOS) using `FlutterSecureStorage`.
2. **Namespaced Data Caching**: Health data in `SharedPreferences` is keyspace-partitioned using the active profile ID prefix (`profile_{id}_`), preventing data leaks between profiles.
3. **Password Hashing**: Backend password strings are salted and hashed using `PBKDF2-SHA256` via `passlib`.
4. **Secret Key Offloading**: Relies on environment variable configuration (`SECRET_KEY`), with a fallback default restricted to development environments.

---

## 📡 Offline-First Architecture & Sync

```
[Local Check-In Saved] ──> [Connectivity Failed?] ──> [Save to Namespaced Cache]
                                                               │
                                                       (Internet Restored)
                                                               │
                                                               ▼
                                               [Upload Snapshot & Merge Hashes]
```
* **Offline Calculation**: When the client detects an offline state, the local Dart engine performs identical scoring estimates.
* **Sync Mechanism**: Uses `PredictionSyncService` to query pending offline data points, serializes them, hashes the metric vectors (to prevent double uploads), and syncs them back to the SQLite DB when connectivity is restored.

---

## 💬 Conversational AI Assistant

* **Context Construction**: The assistant builds user prompt context by serializing the latest wellness score, the **Highest Impact Opportunity**, and current vital sign values into the query context.
* **Wording Alignment**: The assistant is constrained to explain sub-optimal metrics using the exact text formulated by the `InsightBuilder`, preventing halluncinations.
* **Emergency Interception**: The assistant intercepts exercise or workout optimization queries if the user has an active `Critical` category, returning a safety warning.

---

## 📁 Folder Structure

```
vitalshield_ai/
│
├── backend/                             # Python FastAPI Backend
│   ├── database/                        # Database models & connections
│   │   ├── db.py                        # SQLite engine setup
│   │   └── models.py                    # SQLAlchemy User/Profile/Checkin models
│   ├── models/                          # Trained RandomForest serialized jobs
│   ├── schemas/                         # Pydantic schemas (validation)
│   ├── services/                        # Business logic
│   │   ├── predict_service.py           # ML prediction, safety overrides
│   │   ├── analytics_service.py         # Step consistency calculations
│   │   └── insight_builder.py           # Centralized Python insight generator
│   ├── tests/                           # Pytest validation test suites
│   ├── main.py                          # Main API router & controller
│   └── model_trainer.py                 # Synthetic data & RF training script
│
├── lib/                                 # Flutter Frontend codebase
│   ├── core/                            # Shared core configurations
│   │   ├── constants/                   # String/image constants
│   │   ├── theme/                       # Design system (colors, spacings)
│   │   └── router/                      # GoRouter config
│   ├── features/                        # Feature-specific packages
│   │   ├── auth/                        # Login & SignUp modules
│   │   ├── checkin/                     # Vitals logging widgets
│   │   ├── dashboard/                   # Core metric scores, providers
│   │   ├── predictions/                 # Predictions UI & Dart InsightBuilder
│   │   └── assistant/                   # Wellness Chatbot UI & logic
│   ├── models/                          # User/Check-in models
│   ├── navigation/                      # Sidebar & BottomNav with "More" drawer
│   └── services/                        # Secure Storage, API, and Sync services
│
└── test/                                # Widget and unit test suites
```

---

## 🚀 Setup & Installation

### 1. Backend Server Setup
Ensure Python 3.10+ is installed:
```bash
cd backend

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install requirements
pip install -r requirements.txt

# Run ML training and seed DB
python model_trainer.py
python seed_demo_data.py

# Launch FastAPI development server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*Note: API documentation is auto-generated and viewable at `http://localhost:8000/docs`.*

### 2. Flutter Mobile & Web Setup
Ensure the Flutter SDK is installed:
```bash
# Get dependencies
flutter pub get

# Run on available Chrome web server or connected emulator
flutter run
```
*Note: If running on Android Emulator, API calls are automatically routed to `10.0.2.2` (loopback alias to host machine).*

---

## 🧪 Testing & Verification

Run the test suites to verify functionality:
* **Backend Pytest**:
  ```bash
  cd backend
  pytest tests/
  ```
* **Frontend Flutter Tests**:
  ```bash
  flutter test
  ```

---

## 🔮 Future Scope

1. **Wearable SDK Integration**: Direct integration with Apple HealthKit and Google Health Connect to pull vitals automatically instead of relying on manual check-ins.
2. **Advanced Neural Networks**: Transitioning the Regressor engine from RandomForests to deep neural networks for multi-variate time-series forecasting.
3. **Multi-Region Scale**: Upgrading the database layer from SQLite to PostgreSQL and deploying the API services on AWS ECS/Kubernetes.
