import '../models/cycle_model.dart';

class CycleEngine {
  /// Computes the current cycle context (phase, day, energy level) from CycleData.
  static CycleContext? getCurrentContext(CycleData data) {
    if (!data.isTrackingEnabled || data.lastCycleStart == null) {
      return null;
    }

    final now = DateTime.now();
    final start = data.lastCycleStart!;
    final difference = now.difference(start).inDays;

    if (difference < 0) {
      return const CycleContext(
        phaseLabel: CyclePhaseLabel.activePhase,
        daysIntoCycle: 0,
        isLowerEnergyPhase: false,
      );
    }

    final cycleLen = data.averageCycleLength > 0 ? data.averageCycleLength : 28;
    final daysIntoCycle = (difference % cycleLen) + 1; // 1-indexed for user display

    CyclePhaseLabel label;
    bool lowerEnergy;

    if (daysIntoCycle <= 5) {
      // Days 1-5: Rest & Recovery phase
      label = CyclePhaseLabel.restAndRecovery;
      lowerEnergy = true;
    } else if (daysIntoCycle <= 13) {
      // Days 6-13: Active Phase
      label = CyclePhaseLabel.activePhase;
      lowerEnergy = false;
    } else if (daysIntoCycle <= 16) {
      // Days 14-16: Peak Energy phase
      label = CyclePhaseLabel.peakEnergy;
      lowerEnergy = false;
    } else {
      // Days 17-28+: Wind Down phase
      label = CyclePhaseLabel.windDown;
      // Days 22+ are typically lower energy in this phase
      lowerEnergy = daysIntoCycle >= 22;
    }

    return CycleContext(
      phaseLabel: label,
      daysIntoCycle: daysIntoCycle,
      isLowerEnergyPhase: lowerEnergy,
    );
  }

  /// Friendly display strings for cycle phase labels.
  static String getLabelString(CyclePhaseLabel label) {
    switch (label) {
      case CyclePhaseLabel.restAndRecovery:
        return 'Rest & Recovery';
      case CyclePhaseLabel.activePhase:
        return 'Active Phase';
      case CyclePhaseLabel.peakEnergy:
        return 'Peak Energy';
      case CyclePhaseLabel.windDown:
        return 'Wind Down';
    }
  }

  /// Phase-specific wellness advice.
  static String getPhaseAdvice(CyclePhaseLabel label) {
    switch (label) {
      case CyclePhaseLabel.restAndRecovery:
        return 'Prioritize gentle stretching, iron-rich foods, and extra hydration. Your body benefits most from recovery right now.';
      case CyclePhaseLabel.activePhase:
        return 'Energy levels are rising. This is an excellent window for consistent cardiovascular activity and building fresh habits.';
      case CyclePhaseLabel.peakEnergy:
        return 'Physical stamina is at its seasonal peak. Great time for high-intensity movement or challenging wellness goals.';
      case CyclePhaseLabel.windDown:
        return 'Your body is beginning to conserve energy. Emphasize mindfulness, restful sleep, and gentle recovery options.';
    }
  }
}
