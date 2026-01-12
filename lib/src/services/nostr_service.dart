import 'dart:async';

import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../models/models.dart';
import 'notification_service.dart';
import 'tray_service.dart';

class NostrService extends GetxService {
  final NotificationService _notificationService = Get.find();
  final TrayService _trayService = Get.find();

  final Map<String, Ndk> _ndkInstances = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, NotificationSettings> _settings = {};

  // Event kinds
  static const int kindDm = 4;
  static const int kindGiftWrap = 1059;
  static const int kindNote = 1;
  static const int kindRepost = 6;
  static const int kindReaction = 7;
  static const int kindZapReceipt = 9735;

  Future<NostrService> init() async {
    return this;
  }

  Future<String?> connectAccount(NotifyAccount account, NotificationSettings settings) async {
    try {
      // Create NDK instance
      // Note: NIP-46 signer setup depends on NDK version
      // For now, we'll use a basic setup - adjust based on actual NDK API
      final ndk = Ndk(
        NdkConfig(
          eventVerifier: Bip340EventVerifier(),
          cache: MemCacheManager(),
        ),
      );

      _ndkInstances[account.id] = ndk;
      _settings[account.id] = settings;

      // Start subscriptions
      await _subscribeToEvents(account);

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _subscribeToEvents(NotifyAccount account) async {
    final ndk = _ndkInstances[account.id];
    final settings = _settings[account.id];
    if (ndk == null || settings == null) return;

    final kinds = <int>[];

    if (settings.dm) {
      kinds.addAll([kindDm, kindGiftWrap]);
    }
    if (settings.mention) {
      kinds.add(kindNote);
    }
    if (settings.repost) {
      kinds.add(kindRepost);
    }
    if (settings.reaction) {
      kinds.add(kindReaction);
    }
    if (settings.zap) {
      kinds.add(kindZapReceipt);
    }

    if (kinds.isEmpty) return;

    final filter = Filter(
      kinds: kinds,
      pTags: [account.pubkey],
      since: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final response = ndk.requests.subscription(
      filter: filter,
      explicitRelays: account.relays,
    );

    final subscription = response.stream.listen((event) {
      _handleEvent(account, event);
    });

    _subscriptions[account.id] = subscription;
  }

  void _handleEvent(NotifyAccount account, Nip01Event event) {
    if (_trayService.isPaused) return;

    final settings = _settings[account.id];
    if (settings == null) return;

    // Don't notify for own events
    if (event.pubKey == account.pubkey) return;

    final fromName = _shortenPubkey(event.pubKey);

    switch (event.kind) {
      case kindDm:
      case kindGiftWrap:
        if (settings.dm) {
          _notificationService.showDmNotification(
            fromName: fromName,
            fromPubkey: event.pubKey,
          );
        }
        break;

      case kindNote:
        if (settings.mention && _isMention(event, account.pubkey)) {
          _notificationService.showMentionNotification(
            fromName: fromName,
            eventId: event.id,
          );
        }
        break;

      case kindRepost:
        if (settings.repost) {
          _notificationService.showRepostNotification(fromName: fromName);
        }
        break;

      case kindReaction:
        if (settings.reaction) {
          _notificationService.showReactionNotification(
            fromName: fromName,
            reaction: event.content,
          );
        }
        break;

      case kindZapReceipt:
        if (settings.zap) {
          final amount = _parseZapAmount(event);
          _notificationService.showZapNotification(
            fromName: fromName,
            amount: amount,
          );
        }
        break;
    }
  }

  bool _isMention(Nip01Event event, String pubkey) {
    return event.tags.any((tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey);
  }

  int _parseZapAmount(Nip01Event event) {
    try {
      final bolt11Tag = event.tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'bolt11',
        orElse: () => [],
      );
      if (bolt11Tag.isNotEmpty) {
        // Simple parsing - in production use a proper bolt11 decoder
        return 0;
      }
    } catch (_) {}
    return 0;
  }

  String _shortenPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }

  /// Fetch metadata for a specific pubkey using any available NDK instance
  Future<({String? name, String? picture})?> fetchMetadataForPubkey(String pubkey) async {
    if (_ndkInstances.isEmpty) return null;

    final ndk = _ndkInstances.values.first;
    try {
      final metadata = await ndk.metadata.loadMetadata(pubkey);
      if (metadata != null) {
        return (
          name: metadata.displayName ?? metadata.name,
          picture: metadata.picture,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateSettings(String accountId, NotificationSettings settings) async {
    _settings[accountId] = settings;
  }

  Future<void> disconnectAccount(String accountId) async {
    await _subscriptions[accountId]?.cancel();
    _subscriptions.remove(accountId);
    _ndkInstances.remove(accountId);
    _settings.remove(accountId);
  }

  Future<void> disconnectAll() async {
    for (final id in _ndkInstances.keys.toList()) {
      await disconnectAccount(id);
    }
  }

  @override
  void onClose() {
    disconnectAll();
    super.onClose();
  }
}
