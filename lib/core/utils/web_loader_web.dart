// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

@JS('removeMaxLoader')
external void _removeMaxLoader();

/// Web implementation. Calls the global JS function `removeMaxLoader` using modern JS interop.
void removeWebLoader() {
  try {
    _removeMaxLoader();
  } catch (e) {
    // Avoid throwing errors during tests or in unexpected web environments
  }
}
