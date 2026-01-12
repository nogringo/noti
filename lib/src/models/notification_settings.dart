class NotificationSettings {
  final String accountId;
  final bool dm;
  final bool mention;
  final bool zap;
  final bool repost;
  final bool reaction;

  NotificationSettings({
    required this.accountId,
    this.dm = true,
    this.mention = true,
    this.zap = true,
    this.repost = false,
    this.reaction = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      accountId: json['accountId'] as String,
      dm: json['dm'] as bool? ?? true,
      mention: json['mention'] as bool? ?? true,
      zap: json['zap'] as bool? ?? true,
      repost: json['repost'] as bool? ?? false,
      reaction: json['reaction'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'dm': dm,
      'mention': mention,
      'zap': zap,
      'repost': repost,
      'reaction': reaction,
    };
  }

  NotificationSettings copyWith({
    String? accountId,
    bool? dm,
    bool? mention,
    bool? zap,
    bool? repost,
    bool? reaction,
  }) {
    return NotificationSettings(
      accountId: accountId ?? this.accountId,
      dm: dm ?? this.dm,
      mention: mention ?? this.mention,
      zap: zap ?? this.zap,
      repost: repost ?? this.repost,
      reaction: reaction ?? this.reaction,
    );
  }
}
