enum NotificationType { dm, mention, zap, repost, reaction }

class NotificationHistory {
  final String id;
  final String accountId;
  final NotificationType type;
  final String title;
  final String body;
  final String? fromPubkey;
  final String? eventId;
  final int? zapAmount;
  final String? reaction;
  final DateTime createdAt;
  final bool read;

  NotificationHistory({
    required this.id,
    required this.accountId,
    required this.type,
    required this.title,
    required this.body,
    this.fromPubkey,
    this.eventId,
    this.zapAmount,
    this.reaction,
    required this.createdAt,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'type': type.name,
    'title': title,
    'body': body,
    'fromPubkey': fromPubkey,
    'eventId': eventId,
    'zapAmount': zapAmount,
    'reaction': reaction,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'read': read,
  };

  factory NotificationHistory.fromJson(Map<String, dynamic> json) {
    return NotificationHistory(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      type: NotificationType.values.byName(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      fromPubkey: json['fromPubkey'] as String?,
      eventId: json['eventId'] as String?,
      zapAmount: json['zapAmount'] as int?,
      reaction: json['reaction'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      read: json['read'] as bool? ?? false,
    );
  }

  NotificationHistory copyWith({
    String? id,
    String? accountId,
    NotificationType? type,
    String? title,
    String? body,
    String? fromPubkey,
    String? eventId,
    int? zapAmount,
    String? reaction,
    DateTime? createdAt,
    bool? read,
  }) {
    return NotificationHistory(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      fromPubkey: fromPubkey ?? this.fromPubkey,
      eventId: eventId ?? this.eventId,
      zapAmount: zapAmount ?? this.zapAmount,
      reaction: reaction ?? this.reaction,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}
