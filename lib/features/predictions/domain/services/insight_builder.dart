import 'dart:math' as math;
import '../../domain/models/prediction_model.dart';
import '../../domain/models/explanation_model.dart';
import '../../../checkin/domain/models/daily_checkin_model.dart';

class InsightBuilder {
  static Map<String, dynamic> buildInsights({
    required Map<String, dynamic> metrics,
    bool isSenior = false,
    bool isFemale = false,
    String? cyclePhase,
    List<ContributingFactor>? xaiFactors,
  }) {
    final xaiMap = <String, ContributingFactor>{};
    if (xaiFactors != null) {
      for (final factor in xaiFactors) {
        xaiMap[factor.label] = factor;
      }
    }

    final categories = <PredictionCategoryModel>[];

    // 1. Sleep Category
    final sleepVal = (metrics['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final sleepThreshold = 7.0;
    final sleepFactor = xaiMap['Sleep Duration'];
    final sleepContrib = sleepFactor?.contributionPercent ?? 60.0;
    double sleepEstImprovement = sleepFactor?.scoreImprovementEstimate ?? 0.0;

    int sleepScore;
    String sleepStatus;
    TrendDirection sleepTrend;
    String sleepPriority;
    String sleepImpact;
    String sleepInsight;
    String sleepRec;

    if (sleepVal >= sleepThreshold && sleepVal <= 9.0) {
      sleepScore = 90;
      sleepStatus = 'Optimal';
      sleepTrend = TrendDirection.stable;
      sleepPriority = 'Info';
      sleepImpact = 'Low';
      sleepEstImprovement = 0.0;
      sleepInsight = 'Your sleep duration of ${sleepVal.toStringAsFixed(1)} hours met your target of ${sleepThreshold.toStringAsFixed(1)} hours, supporting steady restoration and optimal circadian rhythm alignment.';
      sleepRec = 'Maintain your current bedtime routine by going to bed within the same 30-minute window tonight to reinforce your circadian clock, which is expected to sustain stable daytime energy levels and keep resting heart rate low.';
    } else if (sleepVal > 9.0) {
      sleepScore = 75;
      sleepStatus = 'Stable';
      sleepTrend = TrendDirection.stable;
      sleepPriority = 'Info';
      sleepImpact = 'Low';
      sleepEstImprovement = 0.0;
      sleepInsight = 'Your sleep duration of ${sleepVal.toStringAsFixed(1)} hours was slightly longer than average, indicating extra rest recovery was prioritized.';
      sleepRec = 'Aim for 7-9 hours tonight to support natural circadian pacing, which is expected to sustain consistent daytime alertness and optimize cardiorespiratory recovery.';
    } else {
      sleepScore = 50;
      sleepStatus = 'Needs Attention';
      sleepTrend = TrendDirection.needsAttention;
      sleepPriority = 'Warning';
      sleepImpact = sleepEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (sleepEstImprovement == 0.0) {
        sleepEstImprovement = 20.0;
      }
      sleepInsight = 'Your sleep duration of ${sleepVal.toStringAsFixed(1)} hours fell below your daily target of ${sleepThreshold.toStringAsFixed(1)} hours, which contributed ${sleepContrib.toStringAsFixed(0)}% of the negative impact on your sleep score.';
      sleepRec = 'Establish a wind-down routine starting 30 minutes before your bedtime (e.g., at 10:00 PM tonight) by turning off electronic screens and dimming lights. This allows your brain to release melatonin naturally, which is expected to increase deep sleep duration by 10% and improve morning alertness tomorrow.';
    }

    categories.add(PredictionCategoryModel(
      categoryTitle: 'Sleep Wellness',
      score: sleepScore,
      status: sleepStatus,
      trendDirection: sleepTrend,
      insight: sleepInsight,
      recommendation: sleepRec,
      severity: sleepPriority,
      recommendationPriority: sleepPriority,
      impactLevel: sleepImpact,
      scoreImprovementEstimate: sleepEstImprovement,
    ));

    // 2. Activity Category
    final stepsVal = (metrics['steps'] as num?)?.toInt() ?? 5000;
    final stepsThreshold = 5000;
    final stepsFactor = xaiMap['Physical Activity'];
    final stepsContrib = stepsFactor?.contributionPercent ?? 60.0;
    double stepsEstImprovement = stepsFactor?.scoreImprovementEstimate ?? 0.0;

    int stepsScore;
    String stepsStatus;
    TrendDirection stepsTrend;
    String stepsPriority;
    String stepsImpact;
    String stepsInsight;
    String stepsRec;

    if (stepsVal >= stepsThreshold) {
      stepsScore = stepsVal >= 10000 ? 95 : 85;
      stepsStatus = stepsVal >= 10000 ? 'Optimal' : 'Active';
      stepsTrend = TrendDirection.stable;
      stepsPriority = 'Info';
      stepsImpact = 'Low';
      stepsEstImprovement = 0.0;
      stepsInsight = 'Your daily steps of $stepsVal met your movement target of $stepsThreshold steps, supporting steady circulation and systemic blood flow.';
      stepsRec = 'Continue this active routine by taking brief 2-minute standing or stretching breaks every hour during prolonged sitting to prevent vascular stiffness, which is expected to maintain healthy lower-extremity circulation and sustain metabolic rate.';
    } else {
      stepsScore = 55;
      stepsStatus = 'Needs Attention';
      stepsTrend = TrendDirection.needsAttention;
      stepsPriority = 'Warning';
      stepsImpact = stepsEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (stepsEstImprovement == 0.0) {
        stepsEstImprovement = 15.0;
      }
      stepsInsight = 'Your daily steps of $stepsVal were below your movement target of $stepsThreshold steps, which contributed ${stepsContrib.toStringAsFixed(0)}% of the negative impact on your activity score.';
      stepsRec = 'Incorporate a brisk 15-minute walk immediately following your next meal today. This brief session stimulates muscle glucose uptake and increases circulation, which is expected to lower post-meal blood sugar spikes by 15% and support evening sleep onset.';
    }

    categories.add(PredictionCategoryModel(
      categoryTitle: 'Activity Wellness',
      score: stepsScore,
      status: stepsStatus,
      trendDirection: stepsTrend,
      insight: stepsInsight,
      recommendation: stepsRec,
      severity: stepsPriority,
      recommendationPriority: stepsPriority,
      impactLevel: stepsImpact,
      scoreImprovementEstimate: stepsEstImprovement,
    ));

    // 3. Heart Category
    final hrVal = (metrics['heart_rate'] as num?)?.toInt() ?? 72;
    final hrMin = 50;
    final hrMax = 100;
    final hrFactor = xaiMap['Resting Heart Rate'];
    final hrContrib = hrFactor?.contributionPercent ?? 70.0;
    double hrEstImprovement = hrFactor?.scoreImprovementEstimate ?? 0.0;

    int hrScore;
    String hrStatus;
    TrendDirection hrTrend;
    String hrPriority;
    String hrImpact;
    String hrInsight;
    String hrRec;

    if (hrVal >= hrMin && hrVal <= hrMax) {
      hrScore = 85;
      hrStatus = 'Optimal';
      hrTrend = TrendDirection.stable;
      hrPriority = 'Info';
      hrImpact = 'Low';
      hrEstImprovement = 0.0;
      hrInsight = 'Your resting heart rate of $hrVal BPM remained within your balanced target range of $hrMin-$hrMax BPM, showing positive cardiovascular recovery.';
      hrRec = 'Keep monitoring your heart rate trends during your daily activities to establish a highly personalized cardiovascular baseline, which is expected to help detect early physiological signs of stress or overtraining.';
    } else {
      hrScore = 60;
      hrStatus = 'Needs Attention';
      hrTrend = TrendDirection.needsAttention;
      hrPriority = 'Warning';
      hrImpact = hrEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (hrEstImprovement == 0.0) {
        hrEstImprovement = 15.0;
      }
      hrInsight = 'Your resting heart rate of $hrVal BPM deviated from your target range of $hrMin-$hrMax BPM, which contributed ${hrContrib.toStringAsFixed(0)}% of the negative impact on your heart score.';
      if (hrVal < hrMin) {
        hrRec = 'Drink 500mL of water immediately and ensure 7-9 hours of restful sleep tonight. This will restore blood volume and support autonomic balance, which is expected to normalize resting pulse and prevent lightheadedness.';
      } else {
        hrRec = 'Perform 5 minutes of guided diaphragmatic breathing (inhaling for 4 seconds, exhaling for 6 seconds) twice today to activate the vagus nerve. This will reduce sympathetic nervous system tone, which is expected to lower your resting pulse by 5-10 BPM within 15 minutes.';
      }
    }

    categories.add(PredictionCategoryModel(
      categoryTitle: 'Heart Wellness',
      score: hrScore,
      status: hrStatus,
      trendDirection: hrTrend,
      insight: hrInsight,
      recommendation: hrRec,
      severity: hrPriority,
      recommendationPriority: hrPriority,
      impactLevel: hrImpact,
      scoreImprovementEstimate: hrEstImprovement,
    ));

    // 4. Blood Pressure Category
    final sysVal = (metrics['systolic'] as num?)?.toInt() ?? 120;
    final diaVal = (metrics['diastolic'] as num?)?.toInt() ?? 80;
    final bpFactor = xaiMap['Systolic BP'] ?? xaiMap['Diastolic BP'];
    final bpContrib = bpFactor?.contributionPercent ?? 55.0;
    double bpEstImprovement = bpFactor?.scoreImprovementEstimate ?? 0.0;

    int bpScore;
    String bpStatus;
    TrendDirection bpTrend;
    String bpPriority;
    String bpImpact;
    String bpInsight;
    String bpRec;

    if (sysVal >= 180 || diaVal >= 120) {
      bpScore = 40;
      bpStatus = 'Critical';
      bpTrend = TrendDirection.needsAttention;
      bpPriority = 'Critical';
      bpImpact = 'Critical';
      bpEstImprovement = 50.0;
      bpInsight = 'Your blood pressure reading of $sysVal/$diaVal mmHg indicates a hypertensive crisis, deviating significantly from the healthy ceiling of 120/80 mmHg and overriding your overall wellness score to a critical cap of 40.';
      bpRec = 'Sit quietly, avoid physical exertion, and contact emergency medical services (911 or local equivalent) immediately. This action is critical to prevent severe vascular complications and ensure immediate medical triage.';
    } else if (sysVal >= 90 && sysVal <= 120 && diaVal >= 60 && diaVal <= 80) {
      bpScore = 88;
      bpStatus = 'Optimal';
      bpTrend = TrendDirection.stable;
      bpPriority = 'Info';
      bpImpact = 'Low';
      bpEstImprovement = 0.0;
      bpInsight = 'Your blood pressure of $sysVal/$diaVal mmHg remained within the optimal range of 90-120 / 60-80 mmHg, supporting vascular health.';
      bpRec = 'Maintain your current hydration levels (at least 2-2.5L of water daily) and low-sodium nutrition to preserve endothelial function, which is expected to keep your systemic vascular resistance low and sustain long-term vascular health.';
    } else if (sysVal < 90 || diaVal < 60) {
      bpScore = 65;
      bpStatus = 'Needs Attention';
      bpTrend = TrendDirection.needsAttention;
      bpPriority = 'Warning';
      bpImpact = bpEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (bpEstImprovement == 0.0) {
        bpEstImprovement = 15.0;
      }
      bpInsight = 'Your blood pressure of $sysVal/$diaVal mmHg fell below the healthy floor of 90/60 mmHg, contributing ${bpContrib.toStringAsFixed(0)}% of the negative impact on your blood pressure score.';
      bpRec = 'Consume 500mL of water immediately and transition slowly from lying or sitting to standing. This increases blood volume and prevents orthostatic drops, which is expected to eliminate dizziness and stabilize blood flow.';
    } else {
      bpScore = 65;
      bpStatus = 'Needs Attention';
      bpTrend = TrendDirection.needsAttention;
      bpPriority = 'Warning';
      bpImpact = bpEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (bpEstImprovement == 0.0) {
        bpEstImprovement = 15.0;
      }
      bpInsight = 'Your blood pressure of $sysVal/$diaVal mmHg was above the healthy target of 120/80 mmHg, contributing ${bpContrib.toStringAsFixed(0)}% of the negative impact on your blood pressure score.';
      bpRec = 'Reduce dietary sodium intake to under 2,000mg today and perform a 10-minute progressive muscle relaxation session. This reduces fluid retention and relaxes vascular walls, which is expected to lower systolic pressure by 3-5 mmHg over the next 24 hours.';
    }

    categories.add(PredictionCategoryModel(
      categoryTitle: 'Blood Pressure Wellness',
      score: bpScore,
      status: bpStatus,
      trendDirection: bpTrend,
      insight: bpInsight,
      recommendation: bpRec,
      severity: bpPriority,
      recommendationPriority: bpPriority,
      impactLevel: bpImpact,
      scoreImprovementEstimate: bpEstImprovement,
    ));

    // 5. Glucose Category
    final gluVal = (metrics['glucose'] as num?)?.toDouble() ?? 90.0;
    final gluFactor = xaiMap['Fasting Glucose'];
    final gluContrib = gluFactor?.contributionPercent ?? 60.0;
    double gluEstImprovement = gluFactor?.scoreImprovementEstimate ?? 0.0;

    int gluScore;
    String gluStatus;
    TrendDirection gluTrend;
    String gluPriority;
    String gluImpact;
    String gluInsight;
    String gluRec;

    if (gluVal < 55.0) {
      gluScore = 40;
      gluStatus = 'Critical';
      gluTrend = TrendDirection.needsAttention;
      gluPriority = 'Critical';
      gluImpact = 'Critical';
      gluEstImprovement = 50.0;
      gluInsight = 'Your fasting glucose of ${gluVal.toStringAsFixed(1)} mg/dL is critically low, indicating severe hypoglycemia below the safety floor of 55 mg/dL and overriding your overall wellness score to a critical cap of 40.';
      gluRec = 'Consume 15 grams of fast-acting carbohydrates (e.g., 4 ounces of fruit juice, half a cup of regular soda, or 3-4 glucose tablets) immediately, rest for 15 minutes, and re-test. This action raises circulating blood sugar rapidly to protect brain function and prevent loss of consciousness.';
    } else if (gluVal > 300.0) {
      gluScore = 40;
      gluStatus = 'Critical';
      gluTrend = TrendDirection.needsAttention;
      gluPriority = 'Critical';
      gluImpact = 'Critical';
      gluEstImprovement = 50.0;
      gluInsight = 'Your fasting glucose of ${gluVal.toStringAsFixed(1)} mg/dL is critically high, indicating extreme hyperglycemia above the safety ceiling of 300 mg/dL and overriding your overall wellness score to a critical cap of 40.';
      gluRec = 'Contact emergency medical services or your primary care provider immediately, check for urine ketones if test strips are available, and drink plenty of water. This is essential to prevent diabetic ketoacidosis (DKA) or hyperosmolar state, ensuring safe clinical stabilization.';
    } else if (gluVal >= 55.0 && gluVal < 70.0) {
      gluScore = 65;
      gluStatus = 'Needs Attention';
      gluTrend = TrendDirection.needsAttention;
      gluPriority = 'Warning';
      gluImpact = gluEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (gluEstImprovement == 0.0) {
        gluEstImprovement = 15.0;
      }
      gluInsight = 'Your fasting glucose of ${gluVal.toStringAsFixed(1)} mg/dL fell below the healthy baseline of 70 mg/dL, contributing ${gluContrib.toStringAsFixed(0)}% of the negative impact on your glucose score.';
      gluRec = 'Eat a balanced snack containing 15g of complex carbohydrates and a source of protein (e.g., whole grain crackers with cheese or an apple with peanut butter) now. This provides a gradual, sustained release of glucose into the bloodstream, which is expected to stabilize your energy levels and prevent hypoglycemic fatigue.';
    } else if (gluVal >= 70.0 && gluVal <= 100.0) {
      gluScore = 85;
      gluStatus = 'Optimal';
      gluTrend = TrendDirection.stable;
      gluPriority = 'Info';
      gluImpact = 'Low';
      gluEstImprovement = 0.0;
      gluInsight = 'Your fasting glucose of ${gluVal.toStringAsFixed(1)} mg/dL was within the healthy fasting target of 70-100 mg/dL, supporting 100% of your metabolic energy category score.';
      gluRec = 'Maintain your current routine of consuming complex carbohydrates paired with fiber and lean proteins during meals to sustain energy levels, which is expected to keep your HbA1c in a healthy range and prevent energy dips.';
    } else if (gluVal > 100.0 && gluVal <= 200.0) {
      gluScore = 70;
      gluStatus = 'Stable';
      gluTrend = TrendDirection.stable;
      gluPriority = 'Info';
      gluImpact = 'Low';
      gluEstImprovement = 0.0;
      gluInsight = 'Your glucose of ${gluVal.toStringAsFixed(1)} mg/dL is mildly elevated compared to the fasting target of 100 mg/dL, contributing ${gluContrib.toStringAsFixed(0)}% of the negative impact on your glucose score.';
      gluRec = 'Focus on a low-glycemic, fiber-rich lunch and stay hydrated by drinking 1.5-2L of water throughout the day. This slows down carbohydrate digestion and absorption, which is expected to flatten post-meal glucose spikes and support insulin sensitivity. Note: Consider logging whether this measurement was taken fasting or post-meal to help personalize future trends.';
    } else { // 200.0 < gluVal <= 300.0
      gluScore = 40;
      gluStatus = 'Needs Attention';
      gluTrend = TrendDirection.needsAttention;
      gluPriority = 'Warning';
      gluImpact = gluEstImprovement >= 10.0 ? 'High' : 'Medium';
      if (gluEstImprovement == 0.0) {
        gluEstImprovement = 25.0;
      }
      gluInsight = 'Your glucose of ${gluVal.toStringAsFixed(1)} mg/dL indicates severe hyperglycemia, contributing ${gluContrib.toStringAsFixed(0)}% of the negative impact on your glucose score.';
      gluRec = 'Drink 500mL of water immediately and take a gentle 10-minute walk. This helps your kidneys filter out excess glucose through urine and encourages active muscle tissues to consume glucose without requiring extra insulin, which is expected to lower glucose levels by 20-30 mg/dL over the next two hours.';
    }

    categories.add(PredictionCategoryModel(
      categoryTitle: 'Glucose Wellness',
      score: gluScore,
      status: gluStatus,
      trendDirection: gluTrend,
      insight: gluInsight,
      recommendation: gluRec,
      severity: gluPriority,
      recommendationPriority: gluPriority,
      impactLevel: gluImpact,
      scoreImprovementEstimate: gluEstImprovement,
    ));

    // Apply conflicts / suppressions & ranking
    final resolved = _resolveAndRank(categories, metrics);

    // Separate into opportunities and stable
    final opts = _identifyOpportunities(resolved);

    final highest = opts['highest'] as OpportunityModel?;
    String primaryInsight = 'Your wellness metrics are looking stable and consistent today.';
    if (highest != null) {
      primaryInsight = highest.insight;
    }

    // Generate analytics trend insight
    final analyticsInsight = generateAnalyticsInsight(
      sleepAverage: sleepVal,
      sleepConsistency: 100,
      activityAverage: stepsVal,
      activityConsistency: 100,
      isSenior: isSenior,
    );

    return {
      'categories': resolved,
      'primaryInsight': primaryInsight,
      'analyticsInsightText': analyticsInsight,
      'highestImpactOpportunity': highest,
      'secondaryOpportunity': opts['secondary'] as OpportunityModel?,
      'stableMetrics': opts['stable'] as List<String>,
    };
  }

  static List<PredictionCategoryModel> _resolveAndRank(
    List<PredictionCategoryModel> categories,
    Map<String, dynamic> metrics,
  ) {
    final systolic = (metrics['systolic'] as num?)?.toInt() ?? 120;
    final diastolic = (metrics['diastolic'] as num?)?.toInt() ?? 80;
    final glucose = (metrics['glucose'] as num?)?.toDouble() ?? 90.0;
    final heartRate = (metrics['heart_rate'] as num?)?.toInt() ?? 72;

    final isBpCrisis = (systolic >= 180 || diastolic >= 120);
    final isHypo = (glucose < 55.0);
    final isHyper = (glucose > 300.0);
    final hasCriticalCategory = categories.any((c) => c.recommendationPriority == 'Critical');

    final isEmergency = isBpCrisis || isHypo || isHyper || hasCriticalCategory;

    var updated = List<PredictionCategoryModel>.from(categories);

    if (isEmergency) {
      updated = updated.map((c) {
        if (c.recommendationPriority != 'Critical') {
          return PredictionCategoryModel(
            categoryTitle: c.categoryTitle,
            score: c.score,
            status: c.status,
            trendDirection: c.trendDirection,
            insight: c.insight,
            recommendation: '',
            severity: c.severity,
            recommendationPriority: c.recommendationPriority,
            impactLevel: 'Low',
            scoreImprovementEstimate: 0.0,
            explanation: c.explanation,
          );
        }
        return c;
      }).toList();
    } else {
      // Low BP or low HR activity suppression
      if ((systolic < 90 || diastolic < 60) || (heartRate < 50)) {
        updated = updated.map((c) {
          if (c.categoryTitle == 'Activity Wellness') {
            return PredictionCategoryModel(
              categoryTitle: c.categoryTitle,
              score: c.score,
              status: c.status,
              trendDirection: c.trendDirection,
              insight: c.insight,
              recommendation: '',
              severity: c.severity,
              recommendationPriority: c.recommendationPriority,
              impactLevel: 'Low',
              scoreImprovementEstimate: 0.0,
              explanation: c.explanation,
            );
          }
          return c;
        }).toList();
      }

      // Recommendation deduplication / merging
      int sleepIdx = updated.indexWhere((c) => c.categoryTitle == 'Sleep Wellness');
      int heartIdx = updated.indexWhere((c) => c.categoryTitle == 'Heart Wellness');
      int activityIdx = updated.indexWhere((c) => c.categoryTitle == 'Activity Wellness');
      int bpIdx = updated.indexWhere((c) => c.categoryTitle == 'Blood Pressure Wellness');

      void updateRec(int index, String newRec) {
        if (index != -1) {
          final c = updated[index];
          updated[index] = PredictionCategoryModel(
            categoryTitle: c.categoryTitle,
            score: c.score,
            status: c.status,
            trendDirection: c.trendDirection,
            insight: c.insight,
            recommendation: newRec,
            severity: c.severity,
            recommendationPriority: c.recommendationPriority,
            impactLevel: 'Low',
            scoreImprovementEstimate: 0.0,
            explanation: c.explanation,
          );
        }
      }

      if (sleepIdx != -1 && heartIdx != -1) {
        final sleep = updated[sleepIdx];
        final heart = updated[heartIdx];
        if (sleep.recommendationPriority == 'Warning' && heart.recommendationPriority == 'Warning') {
          if (heart.recommendation.contains('resting heart rate is lower') || heart.recommendation.contains('Drink 500mL of water')) {
            updateRec(heartIdx, 'Your resting heart rate of $heartRate BPM is lower than typical. Establish a wind-down routine tonight to support 7-9 hours of restful sleep and drink 500mL of water to optimize circulation.');
            updateRec(sleepIdx, '');
          }
        }
      }

      if (activityIdx != -1 && heartIdx != -1) {
        final activity = updated[activityIdx];
        final heart = updated[heartIdx];
        if (activity.recommendationPriority == 'Warning' && heart.recommendationPriority == 'Warning') {
          if (heart.recommendation.contains('vagus nerve') ||
              heart.recommendation.contains('diaphragmatic breathing') ||
              heart.recommendation.contains('cardiovascular balance')) {
            updateRec(heartIdx, 'Focus on cardiovascular balance today: perform 5 minutes of slow diaphragmatic breathing and take a gentle 15-minute walk post-meal to stabilize resting heart rate.');
            updateRec(activityIdx, '');
          }
        }
      }

      if (bpIdx != -1 && activityIdx != -1) {
        final bp = updated[bpIdx];
        final activity = updated[activityIdx];
        if (bp.recommendationPriority == 'Warning' && activity.recommendationPriority == 'Info') {
          if (bp.recommendation.contains('sodium') || bp.recommendation.contains('moderating sodium')) {
            updateRec(bpIdx, 'Maintain vascular ease by moderating sodium intake, exploring breathing routines, and taking brief standing breaks every hour.');
            updateRec(activityIdx, '');
          }
        }
      }
    }

    // Sort dynamically
    updated.sort((a, b) {
      int getPriorityRank(String priority) {
        switch (priority.toLowerCase()) {
          case 'critical':
            return 3;
          case 'warning':
            return 2;
          case 'info':
          default:
            return 1;
        }
      }

      final pA = getPriorityRank(a.recommendationPriority);
      final pB = getPriorityRank(b.recommendationPriority);

      if (pA != pB) {
        return pB.compareTo(pA); // descending priority
      }

      if (pA == 3) {
        int getCriticalRank(PredictionCategoryModel c) {
          if (c.categoryTitle == 'Glucose Wellness' && glucose < 55.0) {
            return 3;
          }
          if (c.categoryTitle == 'Blood Pressure Wellness' && isBpCrisis) {
            return 2;
          }
          if (c.categoryTitle == 'Glucose Wellness' && glucose > 300.0) {
            return 1;
          }
          return 0;
        }

        final cA = getCriticalRank(a);
        final cB = getCriticalRank(b);
        if (cA != cB) {
          return cB.compareTo(cA); // descending
        }
      }

      if (a.score != b.score) {
        return a.score.compareTo(b.score); // ascending score
      }

      return a.categoryTitle.compareTo(b.categoryTitle);
    });

    return updated;
  }

  static Map<String, dynamic> _identifyOpportunities(List<PredictionCategoryModel> categories) {
    OpportunityModel? highest;
    OpportunityModel? secondary;
    final stable = <String>[];

    final subOptimal = categories
        .where((c) => c.recommendationPriority == 'Critical' || c.recommendationPriority == 'Warning')
        .toList();

    // Sort by scoreImprovementEstimate descending, then score ascending
    subOptimal.sort((a, b) {
      final impA = a.scoreImprovementEstimate;
      final impB = b.scoreImprovementEstimate;
      if (impA != impB) {
        return impB.compareTo(impA); // descending
      }
      return a.score.compareTo(b.score); // ascending
    });

    if (subOptimal.isNotEmpty) {
      final c = subOptimal[0];
      highest = OpportunityModel(
        categoryTitle: c.categoryTitle,
        insight: c.insight,
        recommendation: c.recommendation,
        recommendationPriority: c.recommendationPriority,
        impactLevel: c.impactLevel,
        scoreImprovementEstimate: c.scoreImprovementEstimate,
      );
    }
    if (subOptimal.length > 1) {
      final c = subOptimal[1];
      secondary = OpportunityModel(
        categoryTitle: c.categoryTitle,
        insight: c.insight,
        recommendation: c.recommendation,
        recommendationPriority: c.recommendationPriority,
        impactLevel: c.impactLevel,
        scoreImprovementEstimate: c.scoreImprovementEstimate,
      );
    }

    for (final c in categories) {
      if (c.recommendationPriority == 'Info') {
        stable.add(c.categoryTitle);
      }
    }

    return {
      'highest': highest,
      'secondary': secondary,
      'stable': stable,
    };
  }

  static String generateAnalyticsInsight({
    required double sleepAverage,
    required int sleepConsistency,
    required int activityAverage,
    required int activityConsistency,
    required bool isSenior,
  }) {
    if (sleepAverage >= 7.0 && activityAverage >= 8000) {
      return 'Your steady sleep average of ${sleepAverage.toStringAsFixed(1)}h and high physical movement are sustaining vascular elasticity. '
          'Action: Maintain this balance by aiming for a consistent 10 PM sleep schedule. '
          'Expected Outcome: Sustainable heart rate recovery and high daytime stamina.';
    } else if (sleepAverage < 7.0) {
      final target = isSenior ? 6.5 : 7.0;
      return 'Your sleep average of ${sleepAverage.toStringAsFixed(1)}h is below the target baseline of ${target.toStringAsFixed(1)}h, limiting nightly cell repair. '
          'Action: Dedicate 30 minutes to a tech-free wind-down routine tonight. '
          'Expected Outcome: Optimized parasympathetic balance to support cardiovascular stability.';
    } else if (activityAverage < 5000) {
      final target = isSenior ? 4000 : 5000;
      return 'Your sleep is stable, but your daily steps average is below the recommended $target steps, limiting active muscle circulation. '
          'Action: Take a 15-minute post-lunch walk today. '
          'Expected Outcome: Enhanced tissue glucose absorption and normalized daytime vascular tone.';
    } else {
      return 'Your daily recovery rhythm shows steady wellness parameters. '
          'Action: Maintain a structured nightly wind-down schedule to preserve sleep quality. '
          'Expected Outcome: Sustained autonomic balance and optimal overall energy reserve.';
    }
  }
}
