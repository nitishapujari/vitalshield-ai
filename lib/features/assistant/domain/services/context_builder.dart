import '../../../checkin/data/local/checkin_storage.dart';
import '../../../predictions/data/prediction_storage.dart';
import '../../../predictions/domain/models/prediction_model.dart';
import '../../../checkin/domain/models/daily_checkin_model.dart';
import '../../../../services/storage_service.dart';
import '../../../wellness/data/cycle_storage.dart';
import '../../../wellness/domain/services/cycle_engine.dart';

/// Builds a contextual summary from the user's recent check-ins, predictions,
/// and user profile. This context is consumed by the response generator
/// to produce relevant, personalized answers.
class ContextBuilder {
  final CheckinStorage _checkinStorage;
  final PredictionStorage _predictionStorage;
  final StorageService _storageService;
  final CycleStorage _cycleStorage;

  ContextBuilder({
    CheckinStorage? checkinStorage,
    PredictionStorage? predictionStorage,
    StorageService? storageService,
    CycleStorage? cycleStorage,
  })  : _checkinStorage = checkinStorage ?? CheckinStorage(),
        _predictionStorage = predictionStorage ?? PredictionStorage(),
        _storageService = storageService ?? StorageService(),
        _cycleStorage = cycleStorage ?? CycleStorage();

  /// Builds a structured context map from the latest available data.
  Future<Map<String, dynamic>> buildContext() async {
    final latestCheckin = await _checkinStorage.getLatestCheckin();
    final latestPrediction = await _predictionStorage.getLatestPrediction();
    final allCheckins = await _checkinStorage.getAllCheckins();
    final allPredictions = await _predictionStorage.getPredictionHistory();
    final user = await _storageService.loadUser();
    
    final cycleData = await _cycleStorage.loadCycleData();
    final cycleContext = CycleEngine.getCurrentContext(cycleData);

    return {
      'hasCheckinData': latestCheckin != null,
      'hasPredictonData': latestPrediction != null,
      'checkin': latestCheckin != null ? _summarizeCheckin(latestCheckin) : null,
      'prediction': latestPrediction != null ? _summarizePrediction(latestPrediction) : null,
      'historyCheckins': allCheckins.map(_summarizeCheckin).toList(),
      'historyPredictions': allPredictions.map(_summarizePrediction).toList(),
      'userProfile': user != null

          ? {
              'name': user.name,
              'age': user.age,
              'ageCategory': user.ageCategory,
              'gender': user.gender,
            }
          : null,
      'cycleContext': cycleContext != null
          ? {
              'phaseLabel': cycleContext.phaseLabel.name,
              'daysIntoCycle': cycleContext.daysIntoCycle,
              'isLowerEnergyPhase': cycleContext.isLowerEnergyPhase,
            }
          : null,
    };
  }

  Map<String, dynamic> _summarizeCheckin(DailyCheckinModel checkin) {
    return {
      'heartRate': checkin.heartRate,
      'systolic': checkin.systolic,
      'diastolic': checkin.diastolic,
      'glucose': checkin.glucose,
      'steps': checkin.steps,
      'sleepHours': checkin.sleepHours,
      'timestamp': checkin.timestamp?.toIso8601String(),
    };
  }

  Map<String, dynamic> _summarizePrediction(PredictionSnapshotModel prediction) {
    return {
      'overallScore': prediction.overallWellnessScore,
      'primaryInsight': prediction.primaryInsight,
      'categories': prediction.categories.map((c) => {
        'title': c.categoryTitle,
        'categoryTitle': c.categoryTitle,
        'score': c.score,
        'trend': c.trendDirection.name,
        'insight': c.insight,
        'recommendation': c.recommendation,
        'severity': c.severity,
        'recommendationPriority': c.recommendationPriority,
        'impactLevel': c.impactLevel,
        'scoreImprovementEstimate': c.scoreImprovementEstimate,
        'explanation': c.explanation?.toMap(),
      }).toList(),
      'highestImpactOpportunity': prediction.highestImpactOpportunity?.toMap(),
      'secondaryOpportunity': prediction.secondaryOpportunity?.toMap(),
      'stableMetrics': prediction.stableMetrics,
    };
  }
}

