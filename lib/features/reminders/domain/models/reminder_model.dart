class ReminderSettings {
  final bool isMuted;
  
  final bool checkInEnabled;
  final int checkInHour;
  final int checkInMinute;

  final bool hydrationEnabled;
  final int hydrationIntervalHours;

  final bool sleepEnabled;
  final int sleepHour;
  final int sleepMinute;

  final bool rhythmEnabled;
  final int rhythmHour;
  final int rhythmMinute;

  final bool movementEnabled;
  final int movementIntervalHours;

  const ReminderSettings({
    this.isMuted = false,
    this.checkInEnabled = true,
    this.checkInHour = 9,
    this.checkInMinute = 0,
    this.hydrationEnabled = false,
    this.hydrationIntervalHours = 2,
    this.sleepEnabled = false,
    this.sleepHour = 22,
    this.sleepMinute = 0,
    this.rhythmEnabled = false,
    this.rhythmHour = 10,
    this.rhythmMinute = 0,
    this.movementEnabled = false,
    this.movementIntervalHours = 3,
  });

  ReminderSettings copyWith({
    bool? isMuted,
    bool? checkInEnabled,
    int? checkInHour,
    int? checkInMinute,
    bool? hydrationEnabled,
    int? hydrationIntervalHours,
    bool? sleepEnabled,
    int? sleepHour,
    int? sleepMinute,
    bool? rhythmEnabled,
    int? rhythmHour,
    int? rhythmMinute,
    bool? movementEnabled,
    int? movementIntervalHours,
  }) {
    return ReminderSettings(
      isMuted: isMuted ?? this.isMuted,
      checkInEnabled: checkInEnabled ?? this.checkInEnabled,
      checkInHour: checkInHour ?? this.checkInHour,
      checkInMinute: checkInMinute ?? this.checkInMinute,
      hydrationEnabled: hydrationEnabled ?? this.hydrationEnabled,
      hydrationIntervalHours: hydrationIntervalHours ?? this.hydrationIntervalHours,
      sleepEnabled: sleepEnabled ?? this.sleepEnabled,
      sleepHour: sleepHour ?? this.sleepHour,
      sleepMinute: sleepMinute ?? this.sleepMinute,
      rhythmEnabled: rhythmEnabled ?? this.rhythmEnabled,
      rhythmHour: rhythmHour ?? this.rhythmHour,
      rhythmMinute: rhythmMinute ?? this.rhythmMinute,
      movementEnabled: movementEnabled ?? this.movementEnabled,
      movementIntervalHours: movementIntervalHours ?? this.movementIntervalHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isMuted': isMuted,
      'checkInEnabled': checkInEnabled,
      'checkInHour': checkInHour,
      'checkInMinute': checkInMinute,
      'hydrationEnabled': hydrationEnabled,
      'hydrationIntervalHours': hydrationIntervalHours,
      'sleepEnabled': sleepEnabled,
      'sleepHour': sleepHour,
      'sleepMinute': sleepMinute,
      'rhythmEnabled': rhythmEnabled,
      'rhythmHour': rhythmHour,
      'rhythmMinute': rhythmMinute,
      'movementEnabled': movementEnabled,
      'movementIntervalHours': movementIntervalHours,
    };
  }

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      isMuted: json['isMuted'] as bool? ?? false,
      checkInEnabled: json['checkInEnabled'] as bool? ?? true,
      checkInHour: json['checkInHour'] as int? ?? 9,
      checkInMinute: json['checkInMinute'] as int? ?? 0,
      hydrationEnabled: json['hydrationEnabled'] as bool? ?? false,
      hydrationIntervalHours: json['hydrationIntervalHours'] as int? ?? 2,
      sleepEnabled: json['sleepEnabled'] as bool? ?? false,
      sleepHour: json['sleepHour'] as int? ?? 22,
      sleepMinute: json['sleepMinute'] as int? ?? 0,
      rhythmEnabled: json['rhythmEnabled'] as bool? ?? false,
      rhythmHour: json['rhythmHour'] as int? ?? 10,
      rhythmMinute: json['rhythmMinute'] as int? ?? 0,
      movementEnabled: json['movementEnabled'] as bool? ?? false,
      movementIntervalHours: json['movementIntervalHours'] as int? ?? 3,
    );
  }
}
