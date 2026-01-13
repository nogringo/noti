class AppSettings {
  final bool launchAtStartup;
  final bool startMinimized;

  AppSettings({this.launchAtStartup = false, this.startMinimized = true});

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      launchAtStartup: json['launchAtStartup'] as bool? ?? false,
      startMinimized: json['startMinimized'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'launchAtStartup': launchAtStartup,
      'startMinimized': startMinimized,
    };
  }

  AppSettings copyWith({bool? launchAtStartup, bool? startMinimized}) {
    return AppSettings(
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      startMinimized: startMinimized ?? this.startMinimized,
    );
  }
}
