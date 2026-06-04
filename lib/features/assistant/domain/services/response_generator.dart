import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Generates calm, contextual, wellness-oriented responses.
/// Uses structured context from ContextBuilder to produce relevant answers.
/// Adapts tone subtly based on age, gender, and cycle rhythm context without explicit references.
/// Designed to be replaceable with Gemini/OpenAI API in a future phase.
class ResponseGenerator {
  static String getSafeLocale() {
    if (kIsWeb) {
      try {
        return ui.PlatformDispatcher.instance.locale.toString();
      } catch (_) {
        return 'unknown';
      }
    }
    try {
      return Platform.localeName;
    } catch (_) {
      return 'unknown';
    }
  }

  static bool isEmergencyQuery(String msg) {
    final lowerMsg = msg.toLowerCase().trim();
    // Patterns covering chest pain, breathing difficulties, stroke symptoms, suicide, self harm, and medical emergency.
    final emergencyPatterns = [
      r'\bsuicid(e|al)\b', r'\bkill\s+myself\b', r'\bself[\s-]*harm\b', r'\bend\s+my\s+life\b',
      r'\bwant\s+to\s+die\b', r'\bbetter\s+off\s+dead\b',
      r'\bchest\s+pain\b', r'\bheart\s+attack\b', r'\bpain\s+in\s+chest\b', r'\bchest\s+pressure\b',
      r'\bleft\s+arm\s+pain\b',
      r"can't\s+breathe", r"cant\s+breathe", r'\bdifficulty\s+breathing\b',
      r'\bshort(ness)?\s+of\s+breath\b', r'\bsuffocat(ing|e)?\b', r'\bgasping\s+for\s+air\b',
      r'\bstroke\b', r'\bface\s+droop(ing)?\b', r'\barm\s+weakness\b', r'\bspeech\s+slur(red)?\b',
      r'\bslur(red)?\s+speech\b',
      r'\bmedical\s+emergency\b', r'\bcall\s+(an\s+)?ambulance\b', r'\bcall\s+911\b',
      r'\bpoisoned\b', r'\bsevere\s+allergic\s+reaction\b', r'\banaphylaxis\b',
      r'\blost\s+consciousness\b', r'\bpassed\s+out\b',
      r'\bcollaps(e|ed)\b', r'\bbleed(ing)?\b', r'\b(hurt|harm)\s+my(self|\s+self)\b'
    ];

    for (final pattern in emergencyPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerMsg)) {
        return true;
      }
    }
    return false;
  }

  static String getRegionalCrisisResponse(String locale) {
    final parts = locale.replaceAll('-', '_').split('_');
    final country = parts.length > 1 ? parts[1].toUpperCase() : parts[0].toUpperCase();
    
    String emergencyNumber = 'your local emergency services (like 911, 999, or 112)';
    String crisisNumber = '';
    
    if (country == 'US') {
      emergencyNumber = '911';
      crisisNumber = '\n• Call or text the Suicide & Crisis Lifeline at **988** (available 24/7, free, and confidential).';
    } else if (country == 'CA') {
      emergencyNumber = '911';
      crisisNumber = '\n• Call or text the Suicide Crisis Helpline at **988** (available 24/7, free, and confidential).';
    } else if (country == 'GB' || country == 'UK') {
      emergencyNumber = '999';
      crisisNumber = '\n• Call the Samaritans at **116 123** or call NHS **111** for mental health support.';
    } else if (country == 'IN') {
      emergencyNumber = '112';
      crisisNumber = '\n• Call the Tele-MANAS mental health helpline at **14416** or **1800 891 4416** (available 24/7, free, and confidential).';
    } else if (country == 'AU') {
      emergencyNumber = '000';
      crisisNumber = '\n• Call Lifeline at **13 11 14** for mental health and crisis support.';
    } else {
      return "🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
          "If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
          "thoughts of self-harm, or any other life-threatening medical emergency, "
          "**please seek immediate medical assistance.**\n\n"
          "• **Contact your local emergency services, emergency medical provider, crisis hotline, or trusted emergency contact immediately.**\n"
          "• Go to the nearest Emergency Room (ER) or hospital.\n\n"
          "VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**";
    }

    return "🚨 **CRITICAL SAFETY NOTICE** 🚨\n\n"
        "If you are experiencing chest pain, difficulty breathing, stroke-like symptoms, "
        "thoughts of self-harm, or any other life-threatening medical emergency, "
        "**please seek immediate medical assistance.**\n\n"
        "• **Call $emergencyNumber** immediately.\n"
        "• Go to the nearest Emergency Room (ER) or hospital.$crisisNumber\n\n"
        "VitalShield AI is an educational wellness companion and **cannot provide medical diagnosis, emergency triage, or crisis intervention.**";
  }

  /// Generates a response based on the user's message and available context.
  String generate(String userMessage, Map<String, dynamic> context) {
    final lowerMessage = userMessage.toLowerCase().trim();

    if (isEmergencyQuery(lowerMessage)) {
      return getRegionalCrisisResponse(getSafeLocale());
    }

    // Safety check: Intercept wellness optimization requests during critical emergencies
    final checkin = context['checkin'] as Map?;
    final prediction = context['prediction'] as Map?;
    bool hasCriticalEmergency = false;
    if (checkin != null) {
      final sys = checkin['systolic'] as int?;
      final dia = checkin['diastolic'] as int?;
      final glucose = (checkin['glucose'] as num?)?.toDouble();
      if ((sys != null && sys >= 180) || (dia != null && dia >= 120)) {
        hasCriticalEmergency = true;
      } else if (glucose != null && (glucose < 55.0 || glucose > 300.0)) {
        hasCriticalEmergency = true;
      }
    }
    if (!hasCriticalEmergency && prediction != null) {
      final categories = prediction['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['severity'] == 'Critical' || c['recommendationPriority'] == 'Critical')) {
            hasCriticalEmergency = true;
            break;
          }
        }
      }
    }

    if (hasCriticalEmergency) {
      bool isWellnessOptimizationQuery(String msg) {
        final wellnessKeywords = [
          r'\bexercise\b',
          r'\bworkout(s)?\b',
          r'\brun(ning)?\b',
          r'\btrain(ing)?\b',
          r'\bsleep\s+optimiz(e|ation)\b',
          r'\bnutrition\s+optimiz(e|ation)\b',
          r'\boptimize\s+(sleep|nutrition|diet)\b'
        ];
        return wellnessKeywords.any((pattern) => RegExp(pattern).hasMatch(msg));
      }

      if (isWellnessOptimizationQuery(lowerMessage)) {
        return "🚨 **SAFETY INTERCEPTION** 🚨\n\n"
            "I noticed that your latest vital readings indicate a potential health crisis. "
            "Before focusing on daily wellness routines, workouts, or optimization activities, "
            "please seek medical attention or consult your doctor immediately.";
      }
    }

    if (lowerMessage.isEmpty) {
      final profile = context['userProfile'] as Map?;
      final name = profile?['name'] ?? 'Sarah';
      return 'Hello $name. I am here to support your wellness journey in an emotionally safe, encouraging space. How can I help you understand your resting patterns, movement, or daily vitals today?';
    }

    // Extract user profile for subtle personalization
    final profile = context['userProfile'] as Map<String, dynamic>?;
    final ageCategory = profile?['ageCategory'] as String?;
    final gender = profile?['gender'] as String?;
    final cycleContext = context['cycleContext'] as Map<String, dynamic>?;

    // Route to the appropriate response handler
    if (_matchesSleepQuery(lowerMessage)) {
      return _sleepResponse(context, ageCategory: ageCategory, gender: gender, cycleContext: cycleContext);
    }
    if (_matchesActivityQuery(lowerMessage)) {
      return _activityResponse(context, ageCategory: ageCategory, gender: gender, cycleContext: cycleContext);
    }
    if (_matchesHeartQuery(lowerMessage)) {
      return _heartResponse(context);
    }
    if (_matchesBloodPressureQuery(lowerMessage)) {
      return _bloodPressureResponse(context);
    }
    if (_matchesGlucoseQuery(lowerMessage)) {
      return _glucoseResponse(context);
    }
    if (_matchesImprovementQuery(lowerMessage)) {
      return _improvementResponse(context, ageCategory: ageCategory, gender: gender, cycleContext: cycleContext);
    }
    if (_matchesComparisonQuery(lowerMessage)) {
      return _comparisonResponse(context, lowerMessage);
    }
    if (_matchesScoreQuery(lowerMessage)) {
      return _scoreResponse(context, ageCategory: ageCategory, gender: gender, cycleContext: cycleContext);
    }
    if (_matchesInsightQuery(lowerMessage)) {
      return _insightResponse(context);
    }
    if (_matchesGreeting(lowerMessage)) {
      return _greetingResponse(context);
    }

    return _generalResponse(context);
  }


  bool _matchKeywords(String msg, List<String> keywords) {
    return keywords.any((k) {
      final pattern = RegExp('\\b${RegExp.escape(k)}\\b', caseSensitive: false);
      return pattern.hasMatch(msg);
    });
  }

  bool _matchesSleepQuery(String msg) =>
      _matchKeywords(msg, const ['sleep', 'rest', 'night']);

  bool _matchesActivityQuery(String msg) =>
      _matchKeywords(msg, const ['activity', 'step', 'steps', 'walk', 'exercise', 'move', 'movement']);

  bool _matchesHeartQuery(String msg) =>
      _matchKeywords(msg, const ['heart', 'pulse', 'bpm']);

  bool _matchesBloodPressureQuery(String msg) =>
      _matchKeywords(msg, const ['blood pressure', 'bp', 'systolic', 'diastolic']);

  bool _matchesGlucoseQuery(String msg) =>
      _matchKeywords(msg, const ['glucose', 'sugar', 'blood sugar']);

  bool _matchesScoreQuery(String msg) =>
      _matchKeywords(msg, const ['score', 'wellness score', 'overall']);

  bool _matchesInsightQuery(String msg) =>
      _matchKeywords(msg, const ['insight', 'trend', 'prediction', 'summary']);

  bool _matchesGreeting(String msg) =>
      _matchKeywords(msg, const ['hello', 'hi', 'hey', 'hiii', 'hii', 'hiiii', 'yo', 'greetings', 'how are you']);

  bool _matchesImprovementQuery(String msg) =>
      _matchKeywords(msg, const ['improvement', 'improve', 'better', 'optimize', 'opportunity', 'opportunities', 'fix', 'stable', 'recommendation', 'recommendations']);

  bool _matchesComparisonQuery(String msg) =>
      _matchKeywords(msg, const ['compare', 'comparison', 'vs', 'difference', 'diff', 'yesterday', 'previous', 'last']);

  // ── Personalization Helper ──

  /// Subtly adjusts advice phrasing based on age and gender context.
  /// Never references demographics explicitly in the returned text.
  String _personalizeAdvice(String base, {String? ageCategory, String? gender, Map<String, dynamic>? cycleContext}) {
    final isSenior = ageCategory == 'Senior' || ageCategory == 'Senior Citizen';
    final isFemale = gender?.toLowerCase() == 'female';

    String advice = base;

    if (isSenior) {
      // Restorative, stability-focused language
      advice = advice
          .replaceAll('improve energy and recovery', 'support long-term vitality')
          .replaceAll('boost your energy', 'sustain your wellbeing')
          .replaceAll('Try incorporating a 15-minute walk', 'A gentle daily walk may help')
          .replaceAll('build consistency', 'maintain your rhythm')
          .replaceAll('stable trends', 'maintaining stable trends')
          .replaceAll('Stable trends', 'Maintaining stable trends')
          .replaceAll('Stable Trends', 'Maintaining stable trends');
    } else if (isFemale) {
      // Slightly softer recovery and balance phrasing
      advice = advice
          .replaceAll('enhance cardiovascular wellness', 'support energy balance and recovery')
          .replaceAll('improve energy and recovery', 'support overall balance and recovery');
    }

    // Subtly inject cycle-aware recovery/sleep adjustments if user is in lower-energy cycle phase
    if (cycleContext != null && cycleContext['isLowerEnergyPhase'] == true) {
      advice += '\n\nSince your monthly rhythm indicates a rest phase, prioritizing gentle recovery and warm hydration supports natural stamina.';
    }

    return advice;
  }

  // ── Response Generators ──

  bool _isNewSession(Map<String, dynamic> context) {
    final history = context['conversation_history'] as List?;
    return history == null || history.isEmpty;
  }

  String _greetingResponse(Map<String, dynamic> context) {
    final profile = context['userProfile'] as Map?;
    final name = profile?['name'] ?? 'Sarah';
    final isNew = _isNewSession(context);

    if (isNew) {
      return 'Hello $name! I\'m your wellness companion. How can I help you support your wellness journey today?';
    } else {
      return 'Hello! How can I help you support your wellness journey today?';
    }
  }

  Map? _findCategory(Map<String, dynamic> context, String title) {
    final prediction = context['prediction'];
    if (prediction == null) return null;
    final categories = prediction['categories'] as List?;
    if (categories == null) return null;
    for (final c in categories) {
      if (c is Map && c['title'] == title) {
        return c;
      }
    }
    return null;
  }

  String _sleepResponse(Map<String, dynamic> context, {String? ageCategory, String? gender, Map<String, dynamic>? cycleContext}) {
    final pred = context['prediction'] as Map?;
    if (pred != null) {
      final categories = pred['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['title'] == 'Sleep Wellness' || c['categoryTitle'] == 'Sleep Wellness')) {
            return 'Based on your latest sleep wellness snapshot (Score: ${c['score']}), ${c['insight']}\n\nTo optimize this: ${c['recommendation']}';
          }
        }
      }
    }
    return 'Complete a daily check-in with your sleep hours and I\'ll be able to share personalized sleep insights.';
  }

  String _activityResponse(Map<String, dynamic> context, {String? ageCategory, String? gender, Map<String, dynamic>? cycleContext}) {
    final pred = context['prediction'] as Map?;
    if (pred != null) {
      final categories = pred['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['title'] == 'Activity Wellness' || c['categoryTitle'] == 'Activity Wellness')) {
            return 'Based on your latest activity wellness snapshot (Score: ${c['score']}), ${c['insight']}\n\nTo optimize this: ${c['recommendation']}';
          }
        }
      }
    }
    return 'Complete a daily check-in with your step count to unlock activity insights.';
  }

  String _heartResponse(Map<String, dynamic> context) {
    final pred = context['prediction'] as Map?;
    if (pred != null) {
      final categories = pred['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['title'] == 'Heart Wellness' || c['categoryTitle'] == 'Heart Wellness')) {
            return 'Based on your latest heart wellness snapshot (Score: ${c['score']}), ${c['insight']}\n\nTo optimize this: ${c['recommendation']}';
          }
        }
      }
    }
    return 'Complete a daily check-in with your heart rate to unlock heart wellness insights.';
  }

  String _bloodPressureResponse(Map<String, dynamic> context) {
    final pred = context['prediction'] as Map?;
    if (pred != null) {
      final categories = pred['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['title'] == 'Blood Pressure Wellness' || c['categoryTitle'] == 'Blood Pressure Wellness')) {
            return 'Based on your latest blood pressure wellness snapshot (Score: ${c['score']}), ${c['insight']}\n\nTo optimize this: ${c['recommendation']}';
          }
        }
      }
    }
    return 'Complete a daily check-in with your blood pressure readings to unlock insights.';
  }

  String _glucoseResponse(Map<String, dynamic> context) {
    final pred = context['prediction'] as Map?;
    if (pred != null) {
      final categories = pred['categories'] as List?;
      if (categories != null) {
        for (final c in categories) {
          if (c is Map && (c['title'] == 'Glucose Wellness' || c['categoryTitle'] == 'Glucose Wellness')) {
            return 'Based on your latest glucose wellness snapshot (Score: ${c['score']}), ${c['insight']}\n\nTo optimize this: ${c['recommendation']}';
          }
        }
      }
    }
    return 'Complete a daily check-in with your glucose readings to unlock insights.';
  }

  String _mapCategoryTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('sleep')) return 'sleep';
    if (t.contains('activity')) return 'Physical activity';
    if (t.contains('pressure')) return 'Blood pressure';
    if (t.contains('heart')) return 'Heart rate';
    if (t.contains('glucose')) return 'Fasting glucose';
    return title;
  }

  String _scoreResponse(Map<String, dynamic> context, {String? ageCategory, String? gender, Map<String, dynamic>? cycleContext}) {
    final prediction = context['prediction'] as Map?;
    if (prediction == null) {
      return 'Your wellness score will be available after completing a few daily check-ins. Each check-in helps build a clearer picture of your overall wellness.';
    }
    final score = prediction['overallScore'] ?? 70;
    final insight = prediction['primaryInsight'] ?? '';
    final base = 'Your overall wellness score is $score. $insight';
    return _personalizeAdvice(base, ageCategory: ageCategory, gender: gender, cycleContext: cycleContext);
  }

  String _insightResponse(Map<String, dynamic> context) {
    final prediction = context['prediction'] as Map?;
    if (prediction == null) {
      return 'Wellness insights become available after completing daily check-ins. Each entry helps identify patterns and trends in your data.';
    }
    final categories = prediction['categories'] as List?;
    if (categories == null || categories.isEmpty) {
      return 'Your prediction data is being processed. Check back after your next daily check-in.';
    }
    final buffer = StringBuffer('Here\'s a summary of your recent wellness trends:\n\n');
    for (final cat in categories) {
      final title = cat['title'] ?? cat['categoryTitle'];
      final score = cat['score'];
      final status = cat['status'] ?? '';
      final insight = cat['insight'] ?? '';
      buffer.writeln('• **$title**: $score ($status) - $insight');
    }
    final highest = prediction['highestImpactOpportunity'] as Map?;
    if (highest != null) {
      buffer.writeln('\n**Highest Impact Opportunity**: ${highest['categoryTitle']} (Improvement: +${(highest['scoreImprovementEstimate'] as num).toStringAsFixed(1)} pts)\n${highest['recommendation']}');
    }
    return buffer.toString().trim();
  }

  String _improvementResponse(Map<String, dynamic> context, {String? ageCategory, String? gender, Map<String, dynamic>? cycleContext}) {
    final prediction = context['prediction'] as Map?;
    if (prediction == null) {
      return "I don't have enough wellness data to make specific recommendations yet. Complete a few daily check-ins so we can identify areas to improve first!";
    }
    
    var highest = prediction['highestImpactOpportunity'] as Map?;
    var secondary = prediction['secondaryOpportunity'] as Map?;
    var stable = prediction['stableMetrics'] != null ? List<String>.from(prediction['stableMetrics']) : <String>[];
    List<Map> otherSubOptimal = [];

    // Fallback/backward compatibility logic if highest is missing but categories are present
    if (highest == null && prediction['categories'] != null) {
      final categories = prediction['categories'] as List;
      final subOptimal = <Map>[];
      final stableTemp = <String>[];
      for (final c in categories) {
        if (c is Map) {
          final priority = c['recommendationPriority'] ?? c['severity'] ?? c['trend'] ?? '';
          if (priority == 'Critical' || priority == 'Warning' || priority == 'needsAttention') {
            subOptimal.add(c);
          } else {
            stableTemp.add((c['categoryTitle'] ?? c['title'] ?? '') as String);
          }
        }
      }

      // Sort subOptimal: scoreImprovementEstimate descending, then score ascending
      subOptimal.sort((a, b) {
        final aEst = a['scoreImprovementEstimate'] as num? ?? 0.0;
        final bEst = b['scoreImprovementEstimate'] as num? ?? 0.0;
        if (aEst != bEst) {
          return bEst.compareTo(aEst);
        }
        final aScore = a['score'] as num? ?? 100;
        final bScore = b['score'] as num? ?? 100;
        return aScore.compareTo(bScore);
      });

      if (subOptimal.isNotEmpty) {
        final first = subOptimal[0];
        highest = {
          'categoryTitle': first['categoryTitle'] ?? first['title'],
          'insight': first['insight'],
          'recommendation': first['recommendation'],
          'recommendationPriority': first['recommendationPriority'] ?? first['severity'] ?? first['trend'],
          'impactLevel': first['impactLevel'] ?? 'High',
          'scoreImprovementEstimate': (first['scoreImprovementEstimate'] as num?)?.toDouble() ?? 15.0,
        };
      }
      if (subOptimal.length > 1) {
        final second = subOptimal[1];
        secondary = {
          'categoryTitle': second['categoryTitle'] ?? second['title'],
          'insight': second['insight'],
          'recommendation': second['recommendation'],
          'recommendationPriority': second['recommendationPriority'] ?? second['severity'] ?? second['trend'],
          'impactLevel': second['impactLevel'] ?? 'Medium',
          'scoreImprovementEstimate': (second['scoreImprovementEstimate'] as num?)?.toDouble() ?? 10.0,
        };
      }
      if (subOptimal.length > 2) {
        otherSubOptimal = subOptimal.sublist(2).cast<Map>();
      }

      stable = stableTemp;
    }

    if (highest == null) {
      return "Your wellness categories are all in the optimal range (Score 85+)! You are doing fantastic. Maintain your current sleep, movement, and nutrition habits to sustain this balance.";
    }

    final buffer = StringBuffer();
    final highestTitle = _mapCategoryTitle(highest['categoryTitle'] as String);
    buffer.writeln("Looking at your recent check-in, I suggest prioritizing your **$highestTitle** first (Impact: ${highest['impactLevel']}, Estimate: +${(highest['scoreImprovementEstimate'] as num).toStringAsFixed(1)} points).\n${highest['insight']}\nTo support this: ${highest['recommendation']}");
    
    if (secondary != null) {
      final secondaryTitle = _mapCategoryTitle(secondary['categoryTitle'] as String);
      buffer.writeln("\nSecondary opportunity to optimize: **$secondaryTitle** (Impact: ${secondary['impactLevel']}, Estimate: +${(secondary['scoreImprovementEstimate'] as num).toStringAsFixed(1)} points).\n${secondary['insight']}\nTo support this: ${secondary['recommendation']}");
    }
    
    if (otherSubOptimal.isNotEmpty) {
      for (final other in otherSubOptimal) {
        final otherTitle = _mapCategoryTitle((other['categoryTitle'] ?? other['title'] ?? '') as String);
        buffer.writeln("\nOther area to monitor: **$otherTitle** (Impact: ${other['impactLevel'] ?? 'Low'}, Estimate: +${((other['scoreImprovementEstimate'] ?? 0.0) as num).toStringAsFixed(1)} points).\n${other['insight']}\nTo support this: ${other['recommendation']}");
      }
    }

    if (stable.isNotEmpty) {
      final stableClean = stable.map((s) => _mapCategoryTitle(s)).join(', ');
      buffer.writeln("\nStable metrics currently in optimal ranges: $stableClean");
    }
    return buffer.toString().trim();
  }

  String _comparisonResponse(Map<String, dynamic> context, String message) {
    final historyCheckins = context['historyCheckins'] as List?;
    final historyPredictions = context['historyPredictions'] as List?;

    if (historyCheckins == null || historyCheckins.length < 2) {
      return "You need at least two daily check-ins to perform a comparison. Complete another check-in tomorrow so we can track changes over time!";
    }

    final List<Map<String, dynamic>> checkins = [];
    for (final c in historyCheckins) {
      if (c is Map<String, dynamic>) {
        checkins.add(c);
      }
    }
    checkins.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp'] as String);
      final bTime = DateTime.parse(b['timestamp'] as String);
      return aTime.compareTo(bTime);
    });

    final List<Map<String, dynamic>> matched = [];
    final List<String> monthNames = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    final List<String> monthShorts = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

    for (final c in checkins) {
      final dt = DateTime.parse(c['timestamp'] as String);
      final day = dt.day.toString();
      final monthLong = monthNames[dt.month - 1];
      final monthShort = monthShorts[dt.month - 1];

      final pattern1 = "$monthLong $day";
      final pattern2 = "$monthShort $day";

      if (message.contains(pattern1) || message.contains(pattern2)) {
        matched.add(c);
      }
    }

    Map<String, dynamic> c1;
    Map<String, dynamic> c2;

    if (matched.length >= 2) {
      c1 = matched[matched.length - 2];
      c2 = matched[matched.length - 1];
    } else {
      c1 = checkins[checkins.length - 2];
      c2 = checkins[checkins.length - 1];
    }

    final dt1 = DateTime.parse(c1['timestamp'] as String);
    final dt2 = DateTime.parse(c2['timestamp'] as String);

    final months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    final d1Str = "${months[dt1.month - 1]} ${dt1.day}";
    final d2Str = "${months[dt2.month - 1]} ${dt2.day}";

    int? s1;
    int? s2;

    if (historyPredictions != null) {
      for (final p in historyPredictions) {
        if (p is Map<String, dynamic>) {
          final pTime = DateTime.parse(p['timestamp'] as String);
          if (pTime.year == dt1.year && pTime.month == dt1.month && pTime.day == dt1.day) {
            s1 = p['overallScore'] as int?;
          }
          if (pTime.year == dt2.year && pTime.month == dt2.month && pTime.day == dt2.day) {
            s2 = p['overallScore'] as int?;
          }
        }
      }
    }

    final p1Score = s1 != null ? s1.toString() : 'N/A';
    final p2Score = s2 != null ? s2.toString() : 'N/A';

    final sleep1 = c1['sleepHours'] as double? ?? 0.0;
    final sleep2 = c2['sleepHours'] as double? ?? 0.0;
    final sleepDiff = sleep2 - sleep1;
    final sleepInd = sleepDiff > 0 ? '↑' : (sleepDiff < 0 ? '↓' : 'stable');
    final sleepDiffStr = sleepDiff != 0 ? ' (${sleepDiff >= 0 ? "+" : ""}${sleepDiff.toStringAsFixed(1)}h)' : ' (no change)';

    final steps1 = c1['steps'] as int? ?? 0;
    final steps2 = c2['steps'] as int? ?? 0;
    final stepsDiff = steps2 - steps1;
    final stepsInd = stepsDiff > 0 ? '↑' : (stepsDiff < 0 ? '↓' : 'stable');
    final stepsDiffStr = stepsDiff != 0 ? ' (${stepsDiff >= 0 ? "+" : ""}$stepsDiff)' : ' (no change)';

    final hr1 = c1['heartRate'] as int? ?? 0;
    final hr2 = c2['heartRate'] as int? ?? 0;
    final hrDiff = hr2 - hr1;
    final hrInd = hrDiff > 0 ? '↑' : (hrDiff < 0 ? '↓' : 'stable');
    final hrDiffStr = hrDiff != 0 ? ' (${hrDiff >= 0 ? "+" : ""}$hrDiff BPM)' : ' (no change)';

    final gluc1 = c1['glucose'] as double? ?? 0.0;
    final gluc2 = c2['glucose'] as double? ?? 0.0;
    final glucDiff = gluc2 - gluc1;
    final glucInd = glucDiff > 0 ? '↑' : (glucDiff < 0 ? '↓' : 'stable');
    final glucDiffStr = glucDiff != 0 ? ' (${glucDiff >= 0 ? "+" : ""}${glucDiff.toStringAsFixed(1)} mg/dL)' : ' (no change)';

    final sys1 = c1['systolic'] as int? ?? 0;
    final dia1 = c1['diastolic'] as int? ?? 0;
    final sys2 = c2['systolic'] as int? ?? 0;
    final dia2 = c2['diastolic'] as int? ?? 0;
    final sysDiff = sys2 - sys1;
    final diaDiff = dia2 - dia1;
    final bp1Str = '$sys1/$dia1';
    final bp2Str = '$sys2/$dia2';
    final bpInd = (sysDiff != 0 || diaDiff != 0) ? 'changed' : 'stable';
    final bpDiffStr = ' (Systolic: ${sysDiff >= 0 ? "+" : ""}$sysDiff, Diastolic: ${diaDiff >= 0 ? "+" : ""}$diaDiff)';

    String scoreDiffStr = '';
    String scoreInd = '';
    int? sdiff;
    if (s1 != null && s2 != null) {
      sdiff = s2 - s1;
      scoreInd = sdiff > 0 ? '↑' : (sdiff < 0 ? '↓' : 'stable');
      scoreDiffStr = ' (${sdiff >= 0 ? "+" : ""}$sdiff)';
    }

    final List<Map<String, dynamic>> changes = [];
    if (sleep1 > 0) {
      changes.add({
        'name': 'Sleep Duration',
        'rel': (sleepDiff.abs() / sleep1),
        'diff': sleepDiff,
        'label': '${sleepDiff.abs().toStringAsFixed(1)} hours',
        'isImprovement': sleepDiff > 0
      });
    }
    if (steps1 > 0) {
      changes.add({
        'name': 'Physical Activity',
        'rel': (stepsDiff.abs() / steps1),
        'diff': stepsDiff,
        'label': '${stepsDiff.abs()} steps',
        'isImprovement': stepsDiff > 0
      });
    }
    if (hr1 > 0) {
      changes.add({
        'name': 'Resting Heart Rate',
        'rel': (hrDiff.abs() / hr1),
        'diff': hrDiff,
        'label': '${hrDiff.abs()} BPM',
        'isImprovement': hrDiff < 0
      });
    }
    if (gluc1 > 0) {
      changes.add({
        'name': 'Fasting Glucose',
        'rel': (glucDiff.abs() / gluc1),
        'diff': glucDiff,
        'label': '${glucDiff.abs().toStringAsFixed(1)} mg/dL',
        'isImprovement': (gluc2 - 85).abs() < (gluc1 - 85).abs()
      });
    }

    changes.sort((a, b) => (b['rel'] as double).compareTo(a['rel'] as double));

    String sigChangeSummary = '';
    if (s1 != null && s2 != null && s1 != s2) {
      final scoreChangeText = s2 > s1 ? 'improved' : 'declined';
      sigChangeSummary = 'The most notable trend is that your overall Wellness Score $scoreChangeText by ${sdiff!.abs()} points (from $s1 to $s2).';
    } else if (changes.isNotEmpty) {
      final metricName = changes.first['name'];
      final rel = changes.first['rel'] as double;
      final rawDiff = changes.first['diff'] as num;
      final diffLabel = changes.first['label'];
      final isImprovementBool = changes.first['isImprovement'] as bool;
      final trendDirection = rawDiff > 0 ? 'increase' : 'decrease';
      final impactText = isImprovementBool ? 'positive development' : 'change that needs attention';
      sigChangeSummary = 'The most significant metric change is in **$metricName**, which showed a $trendDirection of $diffLabel (a ${(rel * 100).toStringAsFixed(1)}% shift), representing a $impactText.';
    } else {
      sigChangeSummary = 'There are no significant metric changes between these check-ins.';
    }

    return 'Comparing check-ins from **$d1Str** and **$d2Str**:\n\n'
        '• **Wellness Score**: $p1Score vs $p2Score $scoreInd$scoreDiffStr\n'
        '• **Sleep**: ${sleep1.toStringAsFixed(1)}h vs ${sleep2.toStringAsFixed(1)}h $sleepInd$sleepDiffStr\n'
        '• **Steps**: $steps1 vs $steps2 $stepsInd$stepsDiffStr\n'
        '• **Blood Pressure**: $bp1Str vs $bp2Str $bpInd$bpDiffStr\n'
        '• **Fasting Glucose**: ${gluc1.toStringAsFixed(1)} vs ${gluc2.toStringAsFixed(1)} mg/dL $glucInd$glucDiffStr\n'
        '• **Heart Rate**: $hr1 vs $hr2 BPM $hrInd$hrDiffStr\n\n'
        '$sigChangeSummary';
  }

  String _generalResponse(Map<String, dynamic> context) {
    return 'I want to make sure I give you the best support possible, but I\'m not quite sure how to help with that topic. '
        'As your wellness companion, I can help you understand your sleep, steps, heart rate, blood pressure, fasting glucose, or cycle rhythms, and even compare check-ins. '
        'Is there one of those areas you\'d like to check on today?';
  }
}

