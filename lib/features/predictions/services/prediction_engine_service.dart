import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../checkin/domain/models/daily_checkin_model.dart';
import '../domain/models/prediction_model.dart';
import '../domain/services/explanation_engine.dart';
import '../domain/services/insight_builder.dart';
import '../../../../core/constants/metric_ranges.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';
import '../../wellness/data/cycle_storage.dart';
import '../../wellness/domain/services/cycle_engine.dart';
import '../../wellness/domain/models/cycle_model.dart';

/// A modular rule-based forecasting logic engine.
/// This acts as a foundation that can later be replaced with ML pipelines.
class PredictionEngineService {
  bool _isBackendOffline = false;

  String formatUtcTimestamp(DateTime dt) {
    final utc = dt.toUtc();
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";
    return "${utc.year}-${twoDigits(utc.month)}-${twoDigits(utc.day)}T${twoDigits(utc.hour)}:${twoDigits(utc.minute)}:${twoDigits(utc.second)}Z";
  }

  String calculatePredictionHash({
    required String profileId,
    required String timestamp,
    required double sleep,
    required int steps,
    required int heartRate,
    required int systolic,
    required int diastolic,
    required double glucose,
  }) {
    final inputStr = '$profileId|'
        '$timestamp|'
        '${sleep.toStringAsFixed(2)}|'
        '$steps|'
        '$heartRate|'
        '$systolic|'
        '$diastolic|'
        '${glucose.toStringAsFixed(2)}';
    final bytes = utf8.encode(inputStr);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }


  /// Returns true if the last prediction request to the ML backend failed,
  /// indicating we are falling back to local wellness estimation.
  bool get isBackendOffline => _isBackendOffline;

  /// Generates a complete prediction snapshot based on the user's check-in history.
  /// Optionally accepts user demographics for personalized thresholds and language.
  Future<PredictionSnapshotModel> generatePrediction(
    List<DailyCheckinModel> history, {
    int? age,
    String? ageCategory,
    String? gender,
    bool isOffline = false,
  }) async {
    final snapshotId = DateTime.now().millisecondsSinceEpoch.toString();
    final isSenior = ageCategory == 'Senior' || ageCategory == 'Senior Citizen';
    final isFemale = gender?.toLowerCase() == 'female';

    if (history.isEmpty) {
      _isBackendOffline = false;
      // Return an empty/neutral snapshot if no data is available
      return PredictionSnapshotModel(
        id: snapshotId,
        timestamp: DateTime.now(),
        overallWellnessScore: 70,
        categories: [],
        primaryInsight: 'Complete more daily check-ins to unlock wellness predictions.',
      );
    }

    // Sort history from newest to oldest
    final sortedHistory = List<DailyCheckinModel>.from(history)
      ..sort((a, b) => (b.timestamp ?? DateTime.now()).compareTo(a.timestamp ?? DateTime.now()));
    
    // Get up to the last 7 days of data for trend analysis
    final recentHistory = sortedHistory.take(7).toList();
    final latest = recentHistory.first;

    // Fetch cycle context if female
    CycleContext? cycleContext;
    if (isFemale) {
      try {
        final cycleData = await CycleStorage().loadCycleData();
        cycleContext = CycleEngine.getCurrentContext(cycleData);
      } catch (e) {
        debugPrint('Failed to load cycle data for predictions: $e');
      }
    }

    // Try generating prediction using real ML pipeline on FastAPI backend
    final profileId = await StorageService().getCurrentProfileId();
    if (profileId != null && !isOffline) {
      try {
        final apiService = ApiService();
        final body = {
          'metrics': {
            'sleep_hours': latest.sleepHours ?? 7.0,
            'steps': latest.steps ?? 5000,
            'heart_rate': latest.heartRate ?? 72,
            'systolic': latest.systolic ?? 120,
            'diastolic': latest.diastolic ?? 80,
            'glucose': latest.glucose ?? 90.0,
          },
          'age': age,
          'age_category': ageCategory,
          'gender': gender,
          if (cycleContext != null) 'cycle_phase': cycleContext.phaseLabel.name,
        };
        final response = await apiService.post(
          '/predictions/generate',
          body,
          queryParams: {'profile_id': profileId},
        );
        _isBackendOffline = false;
        if (response != null && response is Map<String, dynamic>) {
          return PredictionSnapshotModel.fromMap(response);
        }
      } catch (e) {
        debugPrint('Failed to generate prediction from backend: $e. Falling back to local estimation.');
        _isBackendOffline = true;
      }
    } else {
      _isBackendOffline = true;
    }

    // Fallback rule-based local estimator block using InsightBuilder
    final metricsInput = {
      'sleep_hours': latest.sleepHours ?? 7.0,
      'steps': latest.steps ?? 5000,
      'heart_rate': latest.heartRate ?? 72,
      'systolic': latest.systolic ?? 120,
      'diastolic': latest.diastolic ?? 80,
      'glucose': latest.glucose ?? 90.0,
    };

    final built = InsightBuilder.buildInsights(
      metrics: metricsInput,
      isSenior: isSenior,
      isFemale: isFemale,
      cyclePhase: cycleContext?.phaseLabel.name,
    );

    final rawCategories = built['categories'] as List<PredictionCategoryModel>;
    final categories = rawCategories.map((cat) {
      final explanation = ExplanationEngine.explain(
        cat,
        latest,
        recentHistory,
        isSenior: isSenior,
      );
      return PredictionCategoryModel(
        categoryTitle: cat.categoryTitle,
        score: cat.score,
        status: cat.status,
        trendDirection: cat.trendDirection,
        insight: cat.insight,
        recommendation: cat.recommendation,
        severity: cat.severity,
        recommendationPriority: cat.recommendationPriority,
        impactLevel: cat.impactLevel,
        scoreImprovementEstimate: cat.scoreImprovementEstimate,
        explanation: explanation,
      );
    }).toList();

    // Re-resolve and sort to ensure stability after explanation attachment
    // (ranking remains identical)
    final resolvedCategories = PredictionEngineService._sortResolved(categories, metricsInput);

    // Score calculation
    double totalScore = 0;
    int needsAttentionCount = 0;
    for (var cat in resolvedCategories) {
      totalScore += cat.score;
      if (cat.trendDirection == TrendDirection.needsAttention || cat.status == 'Needs Attention') {
        needsAttentionCount++;
      }
    }
    double averageScore = totalScore / resolvedCategories.length;

    double penalty = 0;
    if (needsAttentionCount == 1) {
      penalty = 5;
    } else if (needsAttentionCount == 2) {
      penalty = 15;
    } else if (needsAttentionCount >= 3) {
      penalty = 25;
    }

    int overallScore = (averageScore - penalty).round().clamp(0, 100);

    // Apply Safety Overrides: cap overall score to <= 40 if any critical vitals emergency is present
    final isCriticalEmergency = resolvedCategories.any((cat) => cat.severity == 'Critical');
    if (isCriticalEmergency && overallScore > 40) {
      overallScore = 40;
    }

    final primaryInsight = built['primaryInsight'] as String;
    final highest = built['highestImpactOpportunity'] as OpportunityModel?;
    final secondary = built['secondaryOpportunity'] as OpportunityModel?;
    final stable = List<String>.from(built['stableMetrics'] ?? []);

    final now = DateTime.now();
    final timestampStr = formatUtcTimestamp(now);
    final timestampWithoutMicroseconds = DateTime.parse(timestampStr);

    final hash = calculatePredictionHash(
      profileId: profileId ?? 'local',
      timestamp: timestampStr,
      sleep: latest.sleepHours ?? 7.0,
      steps: latest.steps ?? 5000,
      heartRate: latest.heartRate ?? 72,
      systolic: latest.systolic ?? 120,
      diastolic: latest.diastolic ?? 80,
      glucose: latest.glucose ?? 90.0,
    );

    return PredictionSnapshotModel(
      id: snapshotId,
      timestamp: timestampWithoutMicroseconds,
      overallWellnessScore: overallScore,
      categories: resolvedCategories,
      primaryInsight: primaryInsight,
      predictionHash: hash,
      pendingSync: true,
      sleepHours: latest.sleepHours ?? 7.0,
      steps: latest.steps ?? 5000,
      heartRate: latest.heartRate ?? 72,
      systolic: latest.systolic ?? 120,
      diastolic: latest.diastolic ?? 80,
      glucose: latest.glucose ?? 90.0,
      highestImpactOpportunity: highest,
      secondaryOpportunity: secondary,
      stableMetrics: stable,
    );
  }

  static List<PredictionCategoryModel> _sortResolved(
    List<PredictionCategoryModel> categories,
    Map<String, dynamic> metrics,
  ) {
    final systolic = (metrics['systolic'] as num?)?.toInt() ?? 120;
    final diastolic = (metrics['diastolic'] as num?)?.toInt() ?? 80;
    final glucose = (metrics['glucose'] as num?)?.toDouble() ?? 90.0;

    final isBpCrisis = (systolic >= 180 || diastolic >= 120);

    final updated = List<PredictionCategoryModel>.from(categories);

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
}
