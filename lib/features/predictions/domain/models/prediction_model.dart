import 'dart:convert';
import 'explanation_model.dart';

/// Represents the trend direction for a wellness prediction
enum TrendDirection {
  improving,
  stable,
  needsAttention,
}

/// Represents a structured opportunity for wellness score improvement.
class OpportunityModel {
  final String categoryTitle;
  final String insight;
  final String recommendation;
  final String recommendationPriority;
  final String impactLevel;
  final double scoreImprovementEstimate;

  const OpportunityModel({
    required this.categoryTitle,
    required this.insight,
    required this.recommendation,
    required this.recommendationPriority,
    required this.impactLevel,
    required this.scoreImprovementEstimate,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryTitle': categoryTitle,
      'insight': insight,
      'recommendation': recommendation,
      'recommendationPriority': recommendationPriority,
      'impactLevel': impactLevel,
      'scoreImprovementEstimate': scoreImprovementEstimate,
    };
  }

  factory OpportunityModel.fromMap(Map<String, dynamic> map) {
    return OpportunityModel(
      categoryTitle: map['categoryTitle'] ?? '',
      insight: map['insight'] ?? '',
      recommendation: map['recommendation'] ?? '',
      recommendationPriority: map['recommendationPriority'] ?? 'Info',
      impactLevel: map['impactLevel'] ?? 'Low',
      scoreImprovementEstimate: (map['scoreImprovementEstimate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents the output of a single prediction category (e.g., Sleep Wellness, Heart Wellness).
class PredictionCategoryModel {
  final String categoryTitle;
  final int score;
  final String status;
  final TrendDirection trendDirection;
  final String insight;
  final String recommendation;
  final String severity;
  final String recommendationPriority;
  final String impactLevel;
  final double scoreImprovementEstimate;
  final PredictionExplanation? explanation;

  const PredictionCategoryModel({
    required this.categoryTitle,
    required this.score,
    required this.status,
    required this.trendDirection,
    required this.insight,
    required this.recommendation,
    this.severity = 'Info',
    this.recommendationPriority = 'Info',
    this.impactLevel = 'Low',
    this.scoreImprovementEstimate = 0.0,
    this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryTitle': categoryTitle,
      'score': score,
      'status': status,
      'trendDirection': trendDirection.name,
      'insight': insight,
      'recommendation': recommendation,
      'severity': severity,
      'recommendationPriority': recommendationPriority,
      'impactLevel': impactLevel,
      'scoreImprovementEstimate': scoreImprovementEstimate,
      'explanation': explanation?.toMap(),
    };
  }

  factory PredictionCategoryModel.fromMap(Map<String, dynamic> map) {
    return PredictionCategoryModel(
      categoryTitle: map['categoryTitle'] ?? '',
      score: map['score']?.toInt() ?? 0,
      status: map['status'] ?? '',
      trendDirection: TrendDirection.values.firstWhere(
        (e) => e.name == map['trendDirection'],
        orElse: () => TrendDirection.stable,
      ),
      insight: map['insight'] ?? '',
      recommendation: map['recommendation'] ?? '',
      severity: map['severity'] ?? 'Info',
      recommendationPriority: map['recommendationPriority'] ?? map['severity'] ?? 'Info',
      impactLevel: map['impactLevel'] ?? 'Low',
      scoreImprovementEstimate: (map['scoreImprovementEstimate'] as num?)?.toDouble() ?? 0.0,
      explanation: map['explanation'] != null
          ? PredictionExplanation.fromMap(map['explanation'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A complete snapshot of all predictions generated at a specific time.
class PredictionSnapshotModel {
  final String id;
  final DateTime timestamp;
  final int overallWellnessScore;
  final List<PredictionCategoryModel> categories;
  final String primaryInsight;
  final String? predictionHash;
  final bool pendingSync;

  // Optional raw metrics fields for hash generation / sync
  final double? sleepHours;
  final int? steps;
  final int? heartRate;
  final int? systolic;
  final int? diastolic;
  final double? glucose;

  // Opportunities and stable metrics
  final OpportunityModel? highestImpactOpportunity;
  final OpportunityModel? secondaryOpportunity;
  final List<String> stableMetrics;

  const PredictionSnapshotModel({
    required this.id,
    required this.timestamp,
    required this.overallWellnessScore,
    required this.categories,
    required this.primaryInsight,
    this.predictionHash,
    this.pendingSync = false,
    this.sleepHours,
    this.steps,
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.glucose,
    this.highestImpactOpportunity,
    this.secondaryOpportunity,
    this.stableMetrics = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'overallWellnessScore': overallWellnessScore,
      'categories': categories.map((x) => x.toMap()).toList(),
      'primaryInsight': primaryInsight,
      'predictionHash': predictionHash,
      'pendingSync': pendingSync,
      'sleepHours': sleepHours,
      'steps': steps,
      'heartRate': heartRate,
      'systolic': systolic,
      'diastolic': diastolic,
      'glucose': glucose,
      'highestImpactOpportunity': highestImpactOpportunity?.toMap(),
      'secondaryOpportunity': secondaryOpportunity?.toMap(),
      'stableMetrics': stableMetrics,
    };
  }

  factory PredictionSnapshotModel.fromMap(Map<String, dynamic> map) {
    return PredictionSnapshotModel(
      id: map['id'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      overallWellnessScore: map['overallWellnessScore']?.toInt() ?? 70,
      categories: List<PredictionCategoryModel>.from(
        (map['categories'] as List<dynamic>? ?? []).map(
          (x) => PredictionCategoryModel.fromMap(x as Map<String, dynamic>),
        ),
      ),
      primaryInsight: map['primaryInsight'] ?? '',
      predictionHash: map['predictionHash'],
      pendingSync: map['pendingSync'] ?? false,
      sleepHours: (map['sleepHours'] as num?)?.toDouble(),
      steps: map['steps']?.toInt(),
      heartRate: map['heartRate']?.toInt(),
      systolic: map['systolic']?.toInt(),
      diastolic: map['diastolic']?.toInt(),
      glucose: (map['glucose'] as num?)?.toDouble(),
      highestImpactOpportunity: map['highestImpactOpportunity'] != null
          ? OpportunityModel.fromMap(map['highestImpactOpportunity'] as Map<String, dynamic>)
          : null,
      secondaryOpportunity: map['secondaryOpportunity'] != null
          ? OpportunityModel.fromMap(map['secondaryOpportunity'] as Map<String, dynamic>)
          : null,
      stableMetrics: List<String>.from(map['stableMetrics'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory PredictionSnapshotModel.fromJson(String source) =>
      PredictionSnapshotModel.fromMap(json.decode(source));
}
