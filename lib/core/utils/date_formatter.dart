import 'package:intl/intl.dart';

/// Date formatting utilities for premium UI presentations.
class DateFormatter {
  /// Returns a friendly date string (e.g. "Today", "Yesterday", or "May 20, 2026").
  static String formatFriendly(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (compareDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  /// Returns time string (e.g. "8:30 AM")
  static String formatTime(DateTime date) {
    return DateFormat('jm').format(date);
  }
}
