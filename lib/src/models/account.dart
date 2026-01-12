class NotifyAccount {
  final String id;
  final String pubkey;
  final String bunkerUrl;
  final List<String> relays;
  final bool active;
  final String? name;
  final String? picture;

  NotifyAccount({
    required this.id,
    required this.pubkey,
    required this.bunkerUrl,
    required this.relays,
    this.active = true,
    this.name,
    this.picture,
  });

  factory NotifyAccount.fromJson(Map<String, dynamic> json) {
    return NotifyAccount(
      id: json['id'] as String,
      pubkey: json['pubkey'] as String,
      bunkerUrl: json['bunkerUrl'] as String,
      relays: List<String>.from(json['relays'] as List),
      active: json['active'] as bool? ?? true,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'bunkerUrl': bunkerUrl,
      'relays': relays,
      'active': active,
      'name': name,
      'picture': picture,
    };
  }

  NotifyAccount copyWith({
    String? id,
    String? pubkey,
    String? bunkerUrl,
    List<String>? relays,
    bool? active,
    String? name,
    String? picture,
  }) {
    return NotifyAccount(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      bunkerUrl: bunkerUrl ?? this.bunkerUrl,
      relays: relays ?? this.relays,
      active: active ?? this.active,
      name: name ?? this.name,
      picture: picture ?? this.picture,
    );
  }
}
