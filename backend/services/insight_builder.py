from typing import Dict, Any, List, Optional, Tuple

class InsightBuilder:
    @staticmethod
    def build_insights(
        metrics: Dict[str, Any],
        is_senior: bool = False,
        is_female: bool = False,
        cycle_phase: Optional[str] = None,
        xai_factors: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """
        Unified service to build all user-facing insights, recommendations,
        priorities, and opportunities from raw check-in metrics and XAI factors.
        """
        xai_map = {f["label"]: f for f in (xai_factors or [])}

        categories = []

        # 1. Sleep Category
        sleep_val = metrics.get("sleep_hours", 7.0)
        sleep_threshold = 7.0
        sleep_factor = xai_map.get("Sleep Duration", {})
        sleep_contrib = sleep_factor.get("contributionPercent", 60.0)
        sleep_est_improvement = sleep_factor.get("scoreImprovementEstimate", 0.0)

        # Decide score & priority
        if sleep_val >= sleep_threshold and sleep_val <= 9.0:
            sleep_score = 90
            sleep_status = "Optimal"
            sleep_trend = "stable"
            sleep_priority = "Info"
            sleep_impact = "Low"
            sleep_est_improvement = 0.0
            sleep_insight = f"Your sleep duration of {sleep_val:.1f} hours met your target of {sleep_threshold:.1f} hours, supporting steady restoration and optimal circadian rhythm alignment."
            sleep_rec = "Maintain your current bedtime routine by going to bed within the same 30-minute window tonight to reinforce your circadian clock, which is expected to sustain stable daytime energy levels and keep resting heart rate low."
        elif sleep_val > 9.0:
            sleep_score = 75
            sleep_status = "Stable"
            sleep_trend = "stable"
            sleep_priority = "Info"
            sleep_impact = "Low"
            sleep_est_improvement = 0.0
            sleep_insight = f"Your sleep duration of {sleep_val:.1f} hours was slightly longer than average, indicating extra rest recovery was prioritized."
            sleep_rec = "Aim for 7-9 hours tonight to support natural circadian pacing, which is expected to sustain consistent daytime alertness and optimize cardiorespiratory recovery."
        else:
            sleep_score = 50
            sleep_status = "Needs Attention"
            sleep_trend = "needsAttention"
            sleep_priority = "Warning"
            sleep_impact = "High" if sleep_est_improvement >= 10.0 else "Medium"
            if sleep_est_improvement == 0.0:
                sleep_est_improvement = 20.0  # fallback
            sleep_insight = f"Your sleep duration of {sleep_val:.1f} hours fell below your daily target of {sleep_threshold:.1f} hours, which contributed {sleep_contrib:.0f}% of the negative impact on your sleep score."
            sleep_rec = "Establish a wind-down routine starting 30 minutes before your bedtime (e.g., at 10:00 PM tonight) by turning off electronic screens and dimming lights. This allows your brain to release melatonin naturally, which is expected to increase deep sleep duration by 10% and improve morning alertness tomorrow."

        categories.append({
            "categoryTitle": "Sleep Wellness",
            "score": sleep_score,
            "status": sleep_status,
            "trendDirection": sleep_trend,
            "insight": sleep_insight,
            "recommendation": sleep_rec,
            "severity": sleep_priority,
            "recommendationPriority": sleep_priority,
            "impactLevel": sleep_impact,
            "scoreImprovementEstimate": sleep_est_improvement
        })

        # 2. Activity Category
        steps_val = metrics.get("steps", 5000)
        steps_threshold = 5000
        steps_factor = xai_map.get("Physical Activity", {})
        steps_contrib = steps_factor.get("contributionPercent", 60.0)
        steps_est_improvement = steps_factor.get("scoreImprovementEstimate", 0.0)

        if steps_val >= steps_threshold:
            steps_score = 95 if steps_val >= 10000 else 85
            steps_status = "Optimal" if steps_val >= 10000 else "Active"
            steps_trend = "stable"
            steps_priority = "Info"
            steps_impact = "Low"
            steps_est_improvement = 0.0
            steps_insight = f"Your daily steps of {steps_val} met your movement target of {steps_threshold} steps, supporting steady circulation and systemic blood flow."
            steps_rec = "Continue this active routine by taking brief 2-minute standing or stretching breaks every hour during prolonged sitting to prevent vascular stiffness, which is expected to maintain healthy lower-extremity circulation and sustain metabolic rate."
        else:
            steps_score = 55
            steps_status = "Needs Attention"
            steps_trend = "needsAttention"
            steps_priority = "Warning"
            steps_impact = "High" if steps_est_improvement >= 10.0 else "Medium"
            if steps_est_improvement == 0.0:
                steps_est_improvement = 15.0  # fallback
            steps_insight = f"Your daily steps of {steps_val} were below your movement target of {steps_threshold} steps, which contributed {steps_contrib:.0f}% of the negative impact on your activity score."
            steps_rec = "Incorporate a brisk 15-minute walk immediately following your next meal today. This brief session stimulates muscle glucose uptake and increases circulation, which is expected to lower post-meal blood sugar spikes by 15% and support evening sleep onset."

        categories.append({
            "categoryTitle": "Activity Wellness",
            "score": steps_score,
            "status": steps_status,
            "trendDirection": steps_trend,
            "insight": steps_insight,
            "recommendation": steps_rec,
            "severity": steps_priority,
            "recommendationPriority": steps_priority,
            "impactLevel": steps_impact,
            "scoreImprovementEstimate": steps_est_improvement
        })

        # 3. Heart Category
        hr_val = metrics.get("heart_rate", 72)
        hr_min, hr_max = 50, 100
        hr_factor = xai_map.get("Resting Heart Rate", {})
        hr_contrib = hr_factor.get("contributionPercent", 70.0)
        hr_est_improvement = hr_factor.get("scoreImprovementEstimate", 0.0)

        if hr_min <= hr_val <= hr_max:
            hr_score = 85
            hr_status = "Optimal"
            hr_trend = "stable"
            hr_priority = "Info"
            hr_impact = "Low"
            hr_est_improvement = 0.0
            hr_insight = f"Your resting heart rate of {hr_val} BPM remained within your balanced target range of {hr_min}-{hr_max} BPM, showing positive cardiovascular recovery."
            hr_rec = "Keep monitoring your heart rate trends during your daily activities to establish a highly personalized cardiovascular baseline, which is expected to help detect early physiological signs of stress or overtraining."
        else:
            hr_score = 60
            hr_status = "Needs Attention"
            hr_trend = "needsAttention"
            hr_priority = "Warning"
            hr_impact = "High" if hr_est_improvement >= 10.0 else "Medium"
            if hr_est_improvement == 0.0:
                hr_est_improvement = 15.0  # fallback
            hr_insight = f"Your resting heart rate of {hr_val} BPM deviated from your target range of {hr_min}-{hr_max} BPM, which contributed {hr_contrib:.0f}% of the negative impact on your heart score."
            hr_rec = (
                f"Your resting heart rate is lower than typical. If you are an active athlete, this may be normal. Otherwise, ensure you are well-rested."
                if hr_val < hr_min
                else "Focus on cardiovascular balance and light activity."
            )
            if hr_val < hr_min:
                hr_rec = "Drink 500mL of water immediately and ensure 7-9 hours of restful sleep tonight. This will restore blood volume and support autonomic balance, which is expected to normalize resting pulse and prevent lightheadedness."
            else:
                hr_rec = "Perform 5 minutes of guided diaphragmatic breathing (inhaling for 4 seconds, exhaling for 6 seconds) twice today to activate the vagus nerve. This will reduce sympathetic nervous system tone, which is expected to lower your resting pulse by 5-10 BPM within 15 minutes."

        categories.append({
            "categoryTitle": "Heart Wellness",
            "score": hr_score,
            "status": hr_status,
            "trendDirection": hr_trend,
            "insight": hr_insight,
            "recommendation": hr_rec,
            "severity": hr_priority,
            "recommendationPriority": hr_priority,
            "impactLevel": hr_impact,
            "scoreImprovementEstimate": hr_est_improvement
        })

        # 4. Blood Pressure Category
        sys_val = metrics.get("systolic", 120)
        dia_val = metrics.get("diastolic", 80)
        bp_factor = xai_map.get("Systolic BP", {}) or xai_map.get("Diastolic BP", {})
        bp_contrib = bp_factor.get("contributionPercent", 55.0)
        bp_est_improvement = bp_factor.get("scoreImprovementEstimate", 0.0)

        if sys_val >= 180 or dia_val >= 120:
            bp_score = 40
            bp_status = "Critical"
            bp_trend = "needsAttention"
            bp_priority = "Critical"
            bp_impact = "Critical"
            bp_est_improvement = 50.0
            bp_insight = f"Your blood pressure reading of {sys_val}/{dia_val} mmHg indicates a hypertensive crisis, deviating significantly from the healthy ceiling of 120/80 mmHg and overriding your overall wellness score to a critical cap of 40."
            bp_rec = "Sit quietly, avoid physical exertion, and contact emergency medical services (911 or local equivalent) immediately. This action is critical to prevent severe vascular complications and ensure immediate medical triage."
        elif 90 <= sys_val <= 120 and 60 <= dia_val <= 80:
            bp_score = 88
            bp_status = "Optimal"
            bp_trend = "stable"
            bp_priority = "Info"
            bp_impact = "Low"
            bp_est_improvement = 0.0
            bp_insight = f"Your blood pressure of {sys_val}/{dia_val} mmHg remained within the optimal range of 90-120 / 60-80 mmHg, supporting vascular health."
            bp_rec = "Maintain your current hydration levels (at least 2-2.5L of water daily) and low-sodium nutrition to preserve endothelial function, which is expected to keep your systemic vascular resistance low and sustain long-term vascular health."
        elif sys_val < 90 or dia_val < 60:
            bp_score = 65
            bp_status = "Needs Attention"
            bp_trend = "needsAttention"
            bp_priority = "Warning"
            bp_impact = "High" if bp_est_improvement >= 10.0 else "Medium"
            if bp_est_improvement == 0.0:
                bp_est_improvement = 15.0  # fallback
            bp_insight = f"Your blood pressure of {sys_val}/{dia_val} mmHg fell below the healthy floor of 90/60 mmHg, contributing {bp_contrib:.0f}% of the negative impact on your blood pressure score."
            bp_rec = "Consume 500mL of water immediately and transition slowly from lying or sitting to standing. This increases blood volume and prevents orthostatic drops, which is expected to eliminate dizziness and stabilize blood flow."
        else:
            bp_score = 65
            bp_status = "Needs Attention"
            bp_trend = "needsAttention"
            bp_priority = "Warning"
            bp_impact = "High" if bp_est_improvement >= 10.0 else "Medium"
            if bp_est_improvement == 0.0:
                bp_est_improvement = 15.0  # fallback
            bp_insight = f"Your blood pressure of {sys_val}/{dia_val} mmHg was above the healthy target of 120/80 mmHg, contributing {bp_contrib:.0f}% of the negative impact on your blood pressure score."
            bp_rec = "Reduce dietary sodium intake to under 2,000mg today and perform a 10-minute progressive muscle relaxation session. This reduces fluid retention and relaxes vascular walls, which is expected to lower systolic pressure by 3-5 mmHg over the next 24 hours."

        categories.append({
            "categoryTitle": "Blood Pressure Wellness",
            "score": bp_score,
            "status": bp_status,
            "trendDirection": bp_trend,
            "insight": bp_insight,
            "recommendation": bp_rec,
            "severity": bp_priority,
            "recommendationPriority": bp_priority,
            "impactLevel": bp_impact,
            "scoreImprovementEstimate": bp_est_improvement
        })

        # 5. Glucose Category
        glu_val = metrics.get("glucose", 90.0)
        glu_factor = xai_map.get("Fasting Glucose", {})
        glu_contrib = glu_factor.get("contributionPercent", 60.0)
        glu_est_improvement = glu_factor.get("scoreImprovementEstimate", 0.0)

        if glu_val < 55.0:
            glu_score = 40
            glu_status = "Critical"
            glu_trend = "needsAttention"
            glu_priority = "Critical"
            glu_impact = "Critical"
            glu_est_improvement = 50.0
            glu_insight = f"Your fasting glucose of {glu_val:.1f} mg/dL is critically low, indicating severe hypoglycemia below the safety floor of 55 mg/dL and overriding your overall wellness score to a critical cap of 40."
            glu_rec = "Consume 15 grams of fast-acting carbohydrates (e.g., 4 ounces of fruit juice, half a cup of regular soda, or 3-4 glucose tablets) immediately, rest for 15 minutes, and re-test. This action raises circulating blood sugar rapidly to protect brain function and prevent loss of consciousness."
        elif glu_val > 300.0:
            glu_score = 40
            glu_status = "Critical"
            glu_trend = "needsAttention"
            glu_priority = "Critical"
            glu_impact = "Critical"
            glu_est_improvement = 50.0
            glu_insight = f"Your fasting glucose of {glu_val:.1f} mg/dL is critically high, indicating extreme hyperglycemia above the safety ceiling of 300 mg/dL and overriding your overall wellness score to a critical cap of 40."
            glu_rec = "Contact emergency medical services or your primary care provider immediately, check for urine ketones if test strips are available, and drink plenty of water. This is essential to prevent diabetic ketoacidosis (DKA) or hyperosmolar state, ensuring safe clinical stabilization."
        elif 55.0 <= glu_val < 70.0:
            glu_score = 65
            glu_status = "Needs Attention"
            glu_trend = "needsAttention"
            glu_priority = "Warning"
            glu_impact = "High" if glu_est_improvement >= 10.0 else "Medium"
            if glu_est_improvement == 0.0:
                glu_est_improvement = 15.0  # fallback
            glu_insight = f"Your fasting glucose of {glu_val:.1f} mg/dL fell below the healthy baseline of 70 mg/dL, contributing {glu_contrib:.0f}% of the negative impact on your glucose score."
            glu_rec = "Eat a balanced snack containing 15g of complex carbohydrates and a source of protein (e.g., whole grain crackers with cheese or an apple with peanut butter) now. This provides a gradual, sustained release of glucose into the bloodstream, which is expected to stabilize your energy levels and prevent hypoglycemic fatigue."
        elif 70.0 <= glu_val <= 100.0:
            glu_score = 85
            glu_status = "Optimal"
            glu_trend = "stable"
            glu_priority = "Info"
            glu_impact = "Low"
            glu_est_improvement = 0.0
            glu_insight = f"Your fasting glucose of {glu_val:.1f} mg/dL was within the healthy fasting target of 70-100 mg/dL, supporting 100% of your metabolic energy category score."
            glu_rec = "Maintain your current routine of consuming complex carbohydrates paired with fiber and lean proteins during meals to sustain energy levels, which is expected to keep your HbA1c in a healthy range and prevent energy dips."
        elif 100.0 < glu_val <= 200.0:
            glu_score = 70
            glu_status = "Stable"
            glu_trend = "stable"
            glu_priority = "Info"
            glu_impact = "Low"
            glu_est_improvement = 0.0
            glu_insight = f"Your glucose of {glu_val:.1f} mg/dL is mildly elevated compared to the fasting target of 100 mg/dL, contributing {glu_contrib:.0f}% of the negative impact on your glucose score."
            glu_rec = "Focus on a low-glycemic, fiber-rich lunch and stay hydrated by drinking 1.5-2L of water throughout the day. This slows down carbohydrate digestion and absorption, which is expected to flatten post-meal glucose spikes and support insulin sensitivity. Note: Consider logging whether this measurement was taken fasting or post-meal to help personalize future trends."
        else: # 200.0 < glu_val <= 300.0
            glu_score = 40
            glu_status = "Needs Attention"
            glu_trend = "needsAttention"
            glu_priority = "Warning"
            glu_impact = "High" if glu_est_improvement >= 10.0 else "Medium"
            if glu_est_improvement == 0.0:
                glu_est_improvement = 25.0  # fallback
            glu_insight = f"Your glucose of {glu_val:.1f} mg/dL indicates severe hyperglycemia, contributing {glu_contrib:.0f}% of the negative impact on your glucose score."
            glu_rec = "Drink 500mL of water immediately and take a gentle 10-minute walk. This helps your kidneys filter out excess glucose through urine and encourages active muscle tissues to consume glucose without requiring extra insulin, which is expected to lower glucose levels by 20-30 mg/dL over the next two hours."

        categories.append({
            "categoryTitle": "Glucose Wellness",
            "score": glu_score,
            "status": glu_status,
            "trendDirection": glu_trend,
            "insight": glu_insight,
            "recommendation": glu_rec,
            "severity": glu_priority,
            "recommendationPriority": glu_priority,
            "impactLevel": glu_impact,
            "scoreImprovementEstimate": glu_est_improvement
        })

        # Apply conflicts / suppressions & ranking
        categories = InsightBuilder._resolve_and_rank(categories, metrics)

        # Separate into opportunities and stable
        highest, secondary, stable = InsightBuilder._identify_opportunities(categories)

        primary_insight = "Your wellness metrics are looking stable and consistent today."
        if highest:
            primary_insight = highest["insight"]

        # Generate analytics insight text
        analytics_insight = InsightBuilder._generate_analytics_insight(
            sleep_average=sleep_val,
            sleep_consistency=100,  # placeholder
            activity_average=steps_val,
            activity_consistency=100,  # placeholder
            is_senior=is_senior
        )

        return {
            "categories": categories,
            "primaryInsight": primary_insight,
            "analyticsInsightText": analytics_insight,
            "highestImpactOpportunity": highest,
            "secondaryOpportunity": secondary,
            "stableMetrics": stable
        }

    @staticmethod
    def _resolve_and_rank(categories: List[Dict[str, Any]], metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        # Check emergency triggers
        systolic = metrics.get("systolic", 120)
        diastolic = metrics.get("diastolic", 80)
        glucose = metrics.get("glucose", 90.0)
        heart_rate = metrics.get("heart_rate", 72)

        is_bp_crisis = (systolic >= 180 or diastolic >= 120)
        is_hypo = (glucose < 55.0)
        is_hyper = (glucose > 300.0)
        has_critical_category = any(c.get("recommendationPriority") == "Critical" for c in categories)

        is_emergency = is_bp_crisis or is_hypo or is_hyper or has_critical_category

        if is_emergency:
            for c in categories:
                if c.get("recommendationPriority") != "Critical":
                    c["recommendation"] = ""
                    c["impactLevel"] = "Low"
                    c["scoreImprovementEstimate"] = 0.0
        else:
            # Low BP or low HR activity suppression
            if (systolic < 90 or diastolic < 60) or (heart_rate < 50):
                for c in categories:
                    if c["categoryTitle"] == "Activity Wellness":
                        c["recommendation"] = ""
                        c["impactLevel"] = "Low"
                        c["scoreImprovementEstimate"] = 0.0

            # Recommendation deduplication / merging
            sleep_cat = next((c for c in categories if c["categoryTitle"] == "Sleep Wellness"), None)
            heart_cat = next((c for c in categories if c["categoryTitle"] == "Heart Wellness"), None)
            activity_cat = next((c for c in categories if c["categoryTitle"] == "Activity Wellness"), None)
            bp_cat = next((c for c in categories if c["categoryTitle"] == "Blood Pressure Wellness"), None)

            if sleep_cat and heart_cat:
                if sleep_cat.get("recommendationPriority") == "Warning" and heart_cat.get("recommendationPriority") == "Warning":
                    if "resting heart rate is lower" in heart_cat.get("recommendation", "") or "Drink 500mL of water" in heart_cat.get("recommendation", ""):
                        heart_cat["recommendation"] = "Your resting heart rate of {} BPM is lower than typical. Establish a wind-down routine tonight to support 7-9 hours of restful sleep and drink 500mL of water to optimize circulation.".format(heart_rate)
                        sleep_cat["recommendation"] = ""
                        sleep_cat["impactLevel"] = "Low"
                        sleep_cat["scoreImprovementEstimate"] = 0.0

            if activity_cat and heart_cat:
                if activity_cat.get("recommendationPriority") == "Warning" and heart_cat.get("recommendationPriority") == "Warning":
                    rec = heart_cat.get("recommendation", "")
                    if "vagus nerve" in rec or "diaphragmatic breathing" in rec or "cardiovascular balance" in rec:
                        heart_cat["recommendation"] = "Focus on cardiovascular balance today: perform 5 minutes of slow diaphragmatic breathing and take a gentle 15-minute walk post-meal to stabilize resting heart rate."
                        activity_cat["recommendation"] = ""
                        activity_cat["impactLevel"] = "Low"
                        activity_cat["scoreImprovementEstimate"] = 0.0

            if bp_cat and activity_cat:
                if bp_cat.get("recommendationPriority") == "Warning" and activity_cat.get("recommendationPriority") == "Info":
                    if "sodium" in bp_cat.get("recommendation", ""):
                        bp_cat["recommendation"] = "Maintain vascular ease by moderating sodium intake, exploring breathing routines, and taking brief standing breaks every hour."
                        activity_cat["recommendation"] = ""
                        activity_cat["impactLevel"] = "Low"
                        activity_cat["scoreImprovementEstimate"] = 0.0

        # Sort dynamically
        def get_sort_key(c):
            p = c.get("recommendationPriority", "Info")
            p_rank = 3 if p == "Critical" else (2 if p == "Warning" else 1)
            crit_rank = 0
            if p == "Critical":
                title = c["categoryTitle"]
                if title == "Glucose Wellness" and glucose < 55.0:
                    crit_rank = 3
                elif title == "Blood Pressure Wellness" and is_bp_crisis:
                    crit_rank = 2
                elif title == "Glucose Wellness" and glucose > 300.0:
                    crit_rank = 1
            score = c.get("score", 100)
            return (-p_rank, -crit_rank, score, c["categoryTitle"])

        categories.sort(key=get_sort_key)
        return categories

    @staticmethod
    def _identify_opportunities(categories: List[Dict[str, Any]]) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]], List[str]]:
        highest = None
        secondary = None
        stable = []

        sub_optimal = [c for c in categories if c.get("recommendationPriority") in ["Critical", "Warning"]]
        # Sort sub-optimal categories by scoreImprovementEstimate descending, then score ascending
        sub_optimal.sort(key=lambda x: (-x.get("scoreImprovementEstimate", 0.0), x.get("score", 100)))

        if len(sub_optimal) > 0:
            highest = {
                "categoryTitle": sub_optimal[0]["categoryTitle"],
                "insight": sub_optimal[0]["insight"],
                "recommendation": sub_optimal[0]["recommendation"],
                "recommendationPriority": sub_optimal[0]["recommendationPriority"],
                "impactLevel": sub_optimal[0]["impactLevel"],
                "scoreImprovementEstimate": sub_optimal[0]["scoreImprovementEstimate"]
            }
        if len(sub_optimal) > 1:
            secondary = {
                "categoryTitle": sub_optimal[1]["categoryTitle"],
                "insight": sub_optimal[1]["insight"],
                "recommendation": sub_optimal[1]["recommendation"],
                "recommendationPriority": sub_optimal[1]["recommendationPriority"],
                "impactLevel": sub_optimal[1]["impactLevel"],
                "scoreImprovementEstimate": sub_optimal[1]["scoreImprovementEstimate"]
            }

        for c in categories:
            if c.get("recommendationPriority") == "Info":
                stable.append(c["categoryTitle"])

        return highest, secondary, stable

    @staticmethod
    def _generate_analytics_insight(
        sleep_average: float,
        sleep_consistency: int,
        activity_average: int,
        activity_consistency: int,
        is_senior: bool
    ) -> str:
        # A single supportive, physiology-oriented analytics summary based on averages
        if sleep_average >= 7.0 and activity_average >= 8000:
            return (
                f"Your steady sleep average of {sleep_average:.1f}h and high physical movement are sustaining vascular elasticity. "
                "Action: Maintain this balance by aiming for a consistent 10 PM sleep schedule. "
                "Expected Outcome: Sustainable heart rate recovery and high daytime stamina."
            )
        elif sleep_average < 7.0:
            target = 6.5 if is_senior else 7.0
            return (
                f"Your sleep average of {sleep_average:.1f}h is below the target baseline of {target:.1f}h, limiting nightly cell repair. "
                "Action: Dedicate 30 minutes to a tech-free wind-down routine tonight. "
                "Expected Outcome: Optimized parasympathetic balance to support cardiovascular stability."
            )
        elif activity_average < 5000:
            target = 4000 if is_senior else 5000
            return (
                f"Your sleep is stable, but your daily steps average is below the recommended {target} steps, limiting active muscle circulation. "
                "Action: Take a 15-minute post-lunch walk today. "
                "Expected Outcome: Enhanced tissue glucose absorption and normalized daytime vascular tone."
            )
        else:
            return (
                "Your daily recovery rhythm shows steady wellness parameters. "
                "Action: Maintain a structured nightly wind-down schedule to preserve sleep quality. "
                "Expected Outcome: Sustained autonomic balance and optimal overall energy reserve."
            )
