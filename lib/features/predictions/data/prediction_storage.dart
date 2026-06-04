import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/prediction_model.dart';
import '../../../../services/storage_service.dart';

class PredictionStorage {
  static const String _latestPredictionKey = 'latest_prediction_snapshot';
  static const String _predictionHistoryKey = 'prediction_snapshot_history'; // For future history integration
  
  final StorageService _storage = StorageService();

  Future<String> _getLatestKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_latestPredictionKey';
  }

  Future<String> _getHistoryKey() async {
    final prefix = await _storage.getProfilePrefix();
    return '$prefix$_predictionHistoryKey';
  }

  /// Saves the most recently generated prediction snapshot.
  Future<void> savePredictionSnapshot(PredictionSnapshotModel snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    
    final latestKey = await _getLatestKey();
    final historyKey = await _getHistoryKey();

    // Save as the latest
    await prefs.setString(latestKey, snapshot.toJson());
    
    // Append to history with deduplication and update checks
    final history = prefs.getStringList(historyKey) ?? [];
    
    bool isDuplicate = false;
    bool shouldReplaceLast = false;
    
    if (history.isNotEmpty) {
      try {
        final lastSnapshot = PredictionSnapshotModel.fromJson(history.last);
        final isSameDay = lastSnapshot.timestamp.year == snapshot.timestamp.year &&
            lastSnapshot.timestamp.month == snapshot.timestamp.month &&
            lastSnapshot.timestamp.day == snapshot.timestamp.day;
            
        if (isSameDay) {
          if (lastSnapshot.overallWellnessScore == snapshot.overallWellnessScore &&
              lastSnapshot.primaryInsight == snapshot.primaryInsight) {
            isDuplicate = true;
          } else {
            shouldReplaceLast = true;
          }
        }
      } catch (_) {}
    }

    if (!isDuplicate) {
      if (shouldReplaceLast) {
        history[history.length - 1] = snapshot.toJson();
      } else {
        history.add(snapshot.toJson());
      }
      
      // Keep only the last 30 snapshots to avoid excessive storage growth
      if (history.length > 30) {
        history.removeAt(0);
      }
      await prefs.setStringList(historyKey, history);
    }
  }

  /// Retrieves the latest stored prediction snapshot, if any.
  Future<PredictionSnapshotModel?> getLatestPrediction() async {
    final prefs = await SharedPreferences.getInstance();
    final latestKey = await _getLatestKey();
    final jsonString = prefs.getString(latestKey);
    
    if (jsonString != null) {
      try {
        return PredictionSnapshotModel.fromJson(jsonString);
      } catch (e) {
        // If parsing fails due to schema changes or corruption
        return null;
      }
    }
    return null;
  }

  /// Retrieves the full history of prediction snapshots, automatically cleaning up duplicates.
  Future<List<PredictionSnapshotModel>> getPredictionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = await _getHistoryKey();
    final historyStrings = prefs.getStringList(historyKey) ?? [];
    
    final List<PredictionSnapshotModel> history = [];
    bool hasDuplicates = false;
    
    for (final str in historyStrings) {
      try {
        final snapshot = PredictionSnapshotModel.fromJson(str);
        if (history.isNotEmpty) {
          final last = history.last;
          final isSameDay = last.timestamp.year == snapshot.timestamp.year &&
              last.timestamp.month == snapshot.timestamp.month &&
              last.timestamp.day == snapshot.timestamp.day;
              
          if (isSameDay &&
              last.overallWellnessScore == snapshot.overallWellnessScore &&
              last.primaryInsight == snapshot.primaryInsight) {
            hasDuplicates = true;
            continue; // Skip consecutive identical entries on the same day
          }
        }
        history.add(snapshot);
      } catch (e) {
        // Skip corrupted entries
      }
    }
    
    // Persist cleaned history back to local storage if duplicates were removed
    if (hasDuplicates) {
      final cleanedStrings = history.map((e) => e.toJson()).toList();
      await prefs.setStringList(historyKey, cleanedStrings);
    }
    
    return history;
  }

  /// Clears all stored prediction data.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final latestKey = await _getLatestKey();
    final historyKey = await _getHistoryKey();
    await prefs.remove(latestKey);
    await prefs.remove(historyKey);
  }
}
