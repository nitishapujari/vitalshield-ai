import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/prediction_storage.dart';
import '../domain/models/prediction_model.dart';
import '../../../../services/storage_service.dart';
import '../../../../services/api_service.dart';
import '../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../analytics/presentation/providers/analytics_provider.dart';
import '../../journey/presentation/providers/journey_provider.dart';
import '../presentation/providers/predictions_provider.dart';

class PredictionSyncService {
  final Ref _ref;
  final PredictionStorage _predictionStorage = PredictionStorage();
  bool _isSyncing = false;

  PredictionSyncService(this._ref);

  bool get isSyncing => _isSyncing;

  Future<void> triggerSync() async {
    if (_isSyncing) return;
    
    final isOffline = _ref.read(backendProvider).isOffline;
    if (isOffline) {
      debugPrint('[PredictionSyncService] System is offline, skipping synchronization.');
      return;
    }

    final profileId = await StorageService().getCurrentProfileId();
    if (profileId == null) {
      debugPrint('[PredictionSyncService] No active profile selected, skipping synchronization.');
      return;
    }

    _isSyncing = true;
    try {
      debugPrint('[PredictionSyncService] Starting synchronization for profile: $profileId');
      
      // 1. Fetch history from prediction storage
      final history = await _predictionStorage.getPredictionHistory();
      
      // 2. Filter predictions that are pending sync
      final pending = history.where((p) => p.pendingSync).toList();
      if (pending.isEmpty) {
        debugPrint('[PredictionSyncService] No pending predictions to synchronize.');
        _isSyncing = false;
        return;
      }

      debugPrint('[PredictionSyncService] Found ${pending.length} pending predictions to sync.');

      // 3. Post to backend
      final apiService = _ref.read(apiServiceProvider);
      
      final payload = pending.map((p) {
        return {
          'id': p.id,
          'timestamp': p.timestamp.toUtc().toIso8601String(),
          'overallWellnessScore': p.overallWellnessScore,
          'categories': p.categories.map((c) => c.toMap()).toList(),
          'primaryInsight': p.primaryInsight,
          'is_ml_generated': false,
          'predictionHash': p.predictionHash,
          'sleepHours': p.sleepHours,
          'steps': p.steps,
          'heartRate': p.heartRate,
          'systolic': p.systolic,
          'diastolic': p.diastolic,
          'glucose': p.glucose,
        };
      }).toList();

      final response = await apiService.post(
        '/predictions/sync',
        payload,
        queryParams: {'profile_id': profileId},
        notifier: _ref.read(backendProvider.notifier),
      );

      if (response != null && response is Map<String, dynamic> && response['status'] == 'success') {
        final syncedList = response['synced'] as List<dynamic>? ?? [];
        final syncedHashes = syncedList.map((h) => h.toString()).toSet();

        debugPrint('[PredictionSyncService] Backend successfully processed sync. Hashes: $syncedHashes');

        // 4. Update local storage: mark successfully synced items as pendingSync = false
        final prefs = await SharedPreferences.getInstance();
        final prefix = await StorageService().getProfilePrefix();
        final historyKey = '${prefix}prediction_snapshot_history';
        
        final historyStrings = prefs.getStringList(historyKey) ?? [];
        final List<String> updatedStrings = [];
        
        for (final str in historyStrings) {
          try {
            final snapshot = PredictionSnapshotModel.fromJson(str);
            if (snapshot.predictionHash != null && syncedHashes.contains(snapshot.predictionHash)) {
              final updatedSnapshot = PredictionSnapshotModel(
                id: snapshot.id,
                timestamp: snapshot.timestamp,
                overallWellnessScore: snapshot.overallWellnessScore,
                categories: snapshot.categories,
                primaryInsight: snapshot.primaryInsight,
                predictionHash: snapshot.predictionHash,
                pendingSync: false,
                sleepHours: snapshot.sleepHours,
                steps: snapshot.steps,
                heartRate: snapshot.heartRate,
                systolic: snapshot.systolic,
                diastolic: snapshot.diastolic,
                glucose: snapshot.glucose,
              );
              updatedStrings.add(updatedSnapshot.toJson());
            } else {
              updatedStrings.add(str);
            }
          } catch (_) {
            updatedStrings.add(str);
          }
        }
        await prefs.setStringList(historyKey, updatedStrings);

        // Also update the latest key if it matches a synced hash
        final latestKey = '${prefix}latest_prediction_snapshot';
        final latestStr = prefs.getString(latestKey);
        if (latestStr != null) {
          try {
            final latestSnapshot = PredictionSnapshotModel.fromJson(latestStr);
            if (latestSnapshot.predictionHash != null && syncedHashes.contains(latestSnapshot.predictionHash)) {
              final updatedLatest = PredictionSnapshotModel(
                id: latestSnapshot.id,
                timestamp: latestSnapshot.timestamp,
                overallWellnessScore: latestSnapshot.overallWellnessScore,
                categories: latestSnapshot.categories,
                primaryInsight: latestSnapshot.primaryInsight,
                predictionHash: latestSnapshot.predictionHash,
                pendingSync: false,
                sleepHours: latestSnapshot.sleepHours,
                steps: latestSnapshot.steps,
                heartRate: latestSnapshot.heartRate,
                systolic: latestSnapshot.systolic,
                diastolic: latestSnapshot.diastolic,
                glucose: latestSnapshot.glucose,
              );
              await prefs.setString(latestKey, updatedLatest.toJson());
            }
          } catch (_) {}
        }

        debugPrint('[PredictionSyncService] Local storage updated.');

        // 5. Invalidate dependent providers to trigger reactive UI reload
        debugPrint('[PredictionSyncService] Invalidating dependent providers...');
        _ref.invalidate(predictionsProvider);
        _ref.invalidate(dashboardProvider);
        _ref.invalidate(analyticsProvider);
        _ref.invalidate(journeyProvider);
      }
    } catch (e, stack) {
      debugPrint('[PredictionSyncService] Synchronization error: $e\n$stack');
    } finally {
      _isSyncing = false;
    }
  }
}

final predictionSyncServiceProvider = Provider<PredictionSyncService>((ref) {
  final service = PredictionSyncService(ref);
  // Listen to connectivity transitions from offline to online
  ref.listen<BackendState>(backendProvider, (previous, next) {
    if (previous != null && previous.isOffline && !next.isOffline) {
      debugPrint('[PredictionSyncService] Connectivity restored. Triggering sync.');
      service.triggerSync();
    }
  });
  return service;
});
