import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalshield_ai/features/checkin/domain/models/daily_checkin_model.dart';
import 'package:vitalshield_ai/features/predictions/domain/models/prediction_model.dart';
import 'package:vitalshield_ai/features/assistant/domain/services/response_generator.dart';
import 'package:vitalshield_ai/features/assistant/domain/services/assistant_engine.dart';
import 'package:vitalshield_ai/features/assistant/domain/models/conversation_model.dart';
import 'package:vitalshield_ai/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:vitalshield_ai/features/assistant/data/conversation_storage.dart';

class FakeCheckinStorage {
  DailyCheckinModel? latest;
  Future<DailyCheckinModel?> getLatestCheckin() async => latest;
}

class FakePredictionStorage {
  PredictionSnapshotModel? latest;
  Future<PredictionSnapshotModel?> getLatestPrediction() async => latest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Assistant System Tests', () {
    late ResponseGenerator generator;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      generator = ResponseGenerator();
    });

    test('ResponseGenerator matches query types and routes correctly', () {
      final context = {
        'hasCheckinData': true,
        'hasPredictonData': true,
        'userProfile': {
          'name': 'Nitisha',
          'age': 22,
          'ageCategory': 'Adult',
          'gender': 'Female',
        },
        'prediction': {
          'overallScore': 82,
          'primaryInsight': 'Your metrics are looking stable.',
          'categories': [
            {
              'title': 'Sleep Wellness',
              'score': 85,
              'trend': 'stable',
              'insight': 'Consistent 8 hours.',
            },
            {
              'title': 'Activity Wellness',
              'score': 60,
              'trend': 'needsAttention',
              'insight': 'Step count is below target.',
            }
          ]
        }
      };

      // Test sleep query
      final sleepResponse = generator.generate('how was my sleep last night?', context);
      expect(sleepResponse, contains('sleep wellness'));
      expect(sleepResponse, contains('85'));

      // Test activity query
      final activityResponse = generator.generate('What about my steps/activity?', context);
      expect(
        activityResponse.contains('activity wellness') ||
        activityResponse.contains('needsAttention') ||
        activityResponse.contains('attention') ||
        activityResponse.contains('movement'),
        isTrue,
      );

      // Test general wellness score query
      final scoreResponse = generator.generate('what is my wellness score?', context);
      expect(scoreResponse, contains('82'));

      // Test greeting
      final helloResponse = generator.generate('hello', context);
      expect(helloResponse, contains('Hello'));
      expect(helloResponse, isNot(contains('82')));

      // Test multi-intent query (greeting + wellness question)
      final multiIntentResponse = generator.generate('hello How can I sleep better? What should I improve first?', context);
      expect(multiIntentResponse, contains('sleep wellness'));
      expect(multiIntentResponse, contains('85'));
    });

    test('ResponseGenerator handles empty/missing data context gracefully', () {
      final emptyContext = {
        'hasCheckinData': false,
        'hasPredictonData': false,
        'prediction': null,
        'checkin': null,
        'userProfile': null,
      };

      final response = generator.generate('Explain my sleep trend', emptyContext);
      expect(response, contains('Complete a daily check-in'));
    });

    test('ResponseGenerator personalizes advice for senior citizens', () {
      final seniorContext = {
        'hasCheckinData': true,
        'hasPredictonData': true,
        'userProfile': {
          'name': 'Margaret',
          'age': 68,
          'ageCategory': 'Senior Citizen',
          'gender': 'Female',
        },
        'prediction': {
          'overallScore': 75,
          'primaryInsight': 'Stable trends.',
          'categories': [
            {
              'title': 'Activity Wellness',
              'score': 55,
              'trend': 'needsAttention',
              'insight': 'Step count below target.',
            }
          ]
        }
      };

      final scoreResponse = generator.generate('what is my overall score?', seniorContext);
      // Senior-specific: stability-focused language
      expect(scoreResponse.toLowerCase(), contains('maintaining'));

      // Activity response should NOT contain aggressive exercise language
      final activityResponse = generator.generate('How is my activity?', seniorContext);
      expect(activityResponse, isNot(contains('enhance cardiovascular')));
    });

    test('AssistantEngine correctly processes messages and outputs tags', () async {
      final engine = AssistantEngine();
      final message = await engine.processMessage('How was my sleep?');

      expect(message.sender, MessageSender.assistant);
      expect(message.content, isNotEmpty);
      expect(message.contextTag, 'sleep');
    });

    test('Regression Tests for improvement and comparison queries', () {
      final context = {
        'hasCheckinData': true,
        'hasPredictonData': true,
        'userProfile': {
          'name': 'Sarah',
          'age': 25,
          'ageCategory': 'Adult',
          'gender': 'Female',
        },
        'prediction': {
          'overallScore': 37,
          'primaryInsight': 'Your sleep duration is slightly lower than your baseline.',
          'categories': [
            {
              'title': 'Sleep Wellness',
              'score': 50,
              'trend': 'needsAttention',
              'insight': 'Sleep is below target.',
              'recommendation': 'Prioritize aiming for 8+ hours of sleep.'
            },
            {
              'title': 'Activity Wellness',
              'score': 55,
              'trend': 'needsAttention',
              'insight': 'Step count is below target.',
              'recommendation': 'Try incorporating a short walk.'
            },
            {
              'title': 'Blood Pressure Wellness',
              'score': 65,
              'trend': 'needsAttention',
              'insight': 'Diastolic BP is slightly elevated.',
              'recommendation': 'Mindful hydration and relaxation.'
            }
          ]
        },
        'checkin': {
          'sleepHours': 4.0,
          'steps': 2900,
          'systolic': 111,
          'diastolic': 90,
          'glucose': 88.0,
          'heartRate': 75,
          'timestamp': '2026-05-30T18:03:01Z'
        },
        'historyCheckins': [
          {
            'sleepHours': 7.5,
            'steps': 8500,
            'systolic': 118,
            'diastolic': 78,
            'glucose': 92.0,
            'heartRate': 72,
            'timestamp': '2026-05-27T13:49:36Z'
          },
          {
            'sleepHours': 4.0,
            'steps': 2900,
            'systolic': 111,
            'diastolic': 90,
            'glucose': 88.0,
            'heartRate': 75,
            'timestamp': '2026-05-30T18:03:01Z'
          }
        ],
        'historyPredictions': [
          {
            'overallScore': 100,
            'timestamp': '2026-05-27T19:36:18Z'
          },
          {
            'overallScore': 37,
            'timestamp': '2026-05-30T12:33:03Z'
          }
        ]
      };

      // Test "What should I improve first?"
      final improveResponse = generator.generate('What should I improve first?', context);
      expect(improveResponse, contains("suggest prioritizing your **sleep** first"));
      expect(improveResponse, contains('sleep'));
      expect(improveResponse, contains('Physical activity'));
      expect(improveResponse, contains('Blood pressure'));
      expect(improveResponse, isNot(contains('I am here to support your wellness journey in an emotionally safe')));

      // Test "Compare my May 27 and May 30 check-ins"
      final compareResponse = generator.generate('Compare my May 27 and May 30 check-ins', context);
      expect(compareResponse, contains('Comparing check-ins from **May 27** and **May 30**'));

      expect(compareResponse, contains('Wellness Score**: 100 vs 37'));
      expect(compareResponse, contains('Sleep**: 7.5h vs 4.0h'));
      expect(compareResponse, contains('Steps**: 8500 vs 2900'));
      expect(compareResponse, contains('118/78 vs 111/90'));
      expect(compareResponse, contains('92.0 vs 88.0 mg/dL'));
      expect(compareResponse, contains('72 vs 75 BPM'));
      expect(compareResponse, contains('Wellness Score declined by 63 points'));
    });

    test('Crisis query detection matches all medical and mental health crisis inputs', () {
      final crisisQueries = [
        "I have severe chest pain",
        "I can't breathe",
        "I think I'm having a heart attack",
        "I collapsed",
        "I am bleeding heavily",
        "I want to kill myself",
        "I want to end my life",
        "I am suicidal",
        "I want to hurt myself"
      ];

      for (final query in crisisQueries) {
        expect(ResponseGenerator.isEmergencyQuery(query), isTrue,
            reason: 'Query "$query" should be detected as emergency');
      }

      final nonCrisisQueries = [
        "How was my sleep?",
        "what is my overall score?",
        "Compare my check-ins",
        "hello"
      ];

      for (final query in nonCrisisQueries) {
        expect(ResponseGenerator.isEmergencyQuery(query), isFalse,
            reason: 'Query "$query" should NOT be detected as emergency');
      }
    });

    test('Regional crisis response formats correctly for known and unknown locales', () {
      final usResponse = ResponseGenerator.getRegionalCrisisResponse('en_US');
      expect(usResponse, contains('911'));
      expect(usResponse, contains('988'));

      final inResponse = ResponseGenerator.getRegionalCrisisResponse('en_IN');
      expect(inResponse, contains('112'));
      expect(inResponse, contains('14416'));

      final unknownResponse = ResponseGenerator.getRegionalCrisisResponse('fr_FR');
      expect(unknownResponse, contains('Contact your local emergency services'));
      expect(unknownResponse, isNot(contains('911')));
      expect(unknownResponse, isNot(contains('988')));
    });

    test('Regional crisis response handles exception fallbacks, empty, malformed, and unknown locales correctly', () {
      // 1. Locale detection exception (should return neutral response when 'unknown' is passed)
      final fallbackResponse = ResponseGenerator.getRegionalCrisisResponse('unknown');
      expect(fallbackResponse, contains('Contact your local emergency services'));
      expect(fallbackResponse, isNot(contains('911')));
      expect(fallbackResponse, isNot(contains('988')));
      expect(fallbackResponse, isNot(contains('999')));
      expect(fallbackResponse, isNot(contains('112')));

      // 2. Empty locale string
      final emptyResponse = ResponseGenerator.getRegionalCrisisResponse('');
      expect(emptyResponse, contains('Contact your local emergency services'));
      expect(emptyResponse, isNot(contains('911')));
      expect(emptyResponse, isNot(contains('988')));
      expect(emptyResponse, isNot(contains('999')));
      expect(emptyResponse, isNot(contains('112')));

      // 3. Malformed locale strings
      final malformedResponse = ResponseGenerator.getRegionalCrisisResponse('invalid-locale-format');
      expect(malformedResponse, contains('Contact your local emergency services'));
      expect(malformedResponse, isNot(contains('911')));
      expect(malformedResponse, isNot(contains('988')));
      expect(malformedResponse, isNot(contains('999')));
      expect(malformedResponse, isNot(contains('112')));

      // 4. Unknown locale values
      final unknownValueResponse = ResponseGenerator.getRegionalCrisisResponse('xyz_ABC');
      expect(unknownValueResponse, contains('Contact your local emergency services'));
      expect(unknownValueResponse, isNot(contains('911')));
      expect(unknownValueResponse, isNot(contains('988')));
      expect(unknownValueResponse, isNot(contains('999')));
      expect(unknownValueResponse, isNot(contains('112')));
    });
  });

  group('AssistantNotifier & Provider Tests', () {
    late MockAssistantEngine mockEngine;
    late ConversationStorage storage;
    late AssistantNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockEngine = MockAssistantEngine();
      storage = ConversationStorage();
      notifier = AssistantNotifier(engine: mockEngine, storage: storage);
    });

    test('normal message flow works through engine', () async {
      await notifier.sendMessage('how was my sleep?');
      expect(mockEngine.processCalls, 1);
      expect(notifier.state.messages.length, 2); // User + Assistant response
      expect(notifier.state.messages[1].contextTag, 'sleep');
      expect(notifier.state.messages[1].content, isNot(contains('CRITICAL SAFETY NOTICE')));
    });

    test('crisis query is intercepted immediately, bypassing engine', () async {
      await notifier.sendMessage('I have severe chest pain');
      expect(mockEngine.processCalls, 0); // Bypassed!
      expect(notifier.state.messages.length, 2); // User + Assistant safety response
      expect(notifier.state.messages[1].contextTag, 'safety');
      expect(notifier.state.messages[1].content, contains('CRITICAL SAFETY NOTICE'));
    });

    test('engine failure for normal query falls back to error message', () async {
      mockEngine.shouldThrow = true;
      await notifier.sendMessage('how was my sleep?');
      expect(mockEngine.processCalls, 1);
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].contextTag, 'error');
      expect(notifier.state.messages[1].content, contains("I wasn't able to process that right now"));
    });

    test('engine failure for crisis query still displays safety notice', () async {
      mockEngine.shouldThrow = true;
      // Even if it somehow gets to the engine (or catch block), it should show the safety notice
      await notifier.sendMessage('I want to hurt myself');
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].contextTag, 'safety');
      expect(notifier.state.messages[1].content, contains('CRITICAL SAFETY NOTICE'));
    });
  });
}

class MockAssistantEngine extends AssistantEngine {
  bool shouldThrow = false;
  int processCalls = 0;

  @override
  Future<ConversationMessage> processMessage(String userMessage) async {
    processCalls++;
    if (shouldThrow) {
      throw Exception("Simulated engine failure");
    }
    return super.processMessage(userMessage);
  }
}

