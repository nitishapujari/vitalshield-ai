import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/utils/web_loader_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  runApp(
    const ProviderScope(
      child: VitalShieldApp(),
    ),
  );

  // Clean up the web loading splash screen as soon as the first frame is rendered
  WidgetsBinding.instance.addPostFrameCallback((_) {
    removeWebLoader();
  });
}