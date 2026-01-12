import 'dart:async';
import 'dart:developer' as dev;

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
  final Map<String, StreamSubscription> _dmSubscriptions = {};
  final Map<String, NotificationSettings> _settings = {};

  // Event kinds (NIP-17 for DMs)
  static const int kindGiftWrap = 1059;
  static const int kindDmRelayList = 10050;
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

    final since = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    dev.log('[NostrService] Subscribing for account ${account.id}, relays: ${account.relays}');

    // Subscribe to DMs on DM relays (NIP-17)
    if (settings.dm) {
      await _subscribeToDms(account, ndk, since);
    }

    // Subscribe to other events on general relays
    final kinds = <int>[];
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
      since: since,
    );

    final response = ndk.requests.subscription(
      filter: filter,
      explicitRelays: account.relays,
    );

    final subscription = response.stream.listen((event) {
      dev.log('[NostrService] Event received: kind=${event.kind}, id=${event.id.substring(0, 8)}, from=${event.pubKey.substring(0, 8)}');
      _handleEvent(account, event);
    });

    _subscriptions[account.id] = subscription;
  }

  Future<void> _subscribeToDms(NotifyAccount account, Ndk ndk, int since) async {
    // Fetch DM relay list (kind 10050) for NIP-17 from user's general relays
    List<String> dmRelays = await _fetchDmRelays(ndk, account.pubkey, account.relays);

    // Fallback to general relays if no DM relays found
    if (dmRelays.isEmpty) {
      dev.log('[NostrService] No DM relays found (kind 10050), using general relays');
      dmRelays = account.relays;
    } else {
      dev.log('[NostrService] DM relays (kind 10050): $dmRelays');
    }

    final dmFilter = Filter(
      kinds: [kindGiftWrap], // NIP-17 uses gift wraps (kind 1059)
      pTags: [account.pubkey],
      since: since,
    );

    final dmResponse = ndk.requests.subscription(
      filter: dmFilter,
      explicitRelays: dmRelays,
    );

    final dmSubscription = dmResponse.stream.listen((event) {
      dev.log('[NostrService] DM Event received: kind=${event.kind}, id=${event.id.substring(0, 8)}, from=${event.pubKey.substring(0, 8)}');
      _handleEvent(account, event);
    });

    _dmSubscriptions[account.id] = dmSubscription;
  }

  Future<List<String>> _fetchDmRelays(Ndk ndk, String pubkey, List<String> userRelays) async {
    try {
      final response = ndk.requests.query(
        filter: Filter(
          kinds: [kindDmRelayList],
          authors: [pubkey],
          limit: 1,
        ),
        explicitRelays: userRelays,
      );

      await for (final event in response.stream) {
        // Extract relay URLs from 'relay' tags
        final relays = <String>[];
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'relay' && tag.length >= 2) {
            relays.add(tag[1]);
          }
        }
        if (relays.isNotEmpty) {
          return relays;
        }
      }
    } catch (_) {}
    return [];
  }

  void _handleEvent(NotifyAccount account, Nip01Event event) {
    if (_trayService.isPaused) {
      dev.log('[NostrService] Event ignored: notifications paused');
      return;
    }

    final settings = _settings[account.id];
    if (settings == null) {
      dev.log('[NostrService] Event ignored: no settings for account');
      return;
    }

    // Don't notify for own events
    if (event.pubKey == account.pubkey) {
      dev.log('[NostrService] Event ignored: own event');
      return;
    }

    final fromName = _shortenPubkey(event.pubKey);

    switch (event.kind) {
      case kindGiftWrap:
        // NIP-17 DM (gift wrapped)
        if (settings.dm) {
          dev.log('[NostrService] Notification: DM from ${event.pubKey.substring(0, 8)}');
          _notificationService.showDmNotification(
            accountId: account.id,
            fromPubkey: event.pubKey,
          );
        }
        break;

      case kindNote:
        if (settings.mention && _isMention(event, account.pubkey)) {
          dev.log('[NostrService] Notification: Mention from $fromName');
          _notificationService.showMentionNotification(
            accountId: account.id,
            fromName: fromName,
            eventId: event.id,
          );
        }
        break;

      case kindRepost:
        if (settings.repost) {
          dev.log('[NostrService] Notification: Repost from $fromName');
          _notificationService.showRepostNotification(
            accountId: account.id,
            fromName: fromName,
          );
        }
        break;

      case kindReaction:
        if (settings.reaction) {
          dev.log('[NostrService] Notification: Reaction "${event.content}" from $fromName');
          _notificationService.showReactionNotification(
            accountId: account.id,
            fromName: fromName,
            reaction: event.content,
          );
        }
        break;

      case kindZapReceipt:
        if (settings.zap) {
          final amount = _parseZapAmount(event);
          dev.log('[NostrService] Notification: Zap $amount sats from $fromName');
          _notificationService.showZapNotification(
            accountId: account.id,
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

  /// Fetch relay list for a specific pubkey using any available NDK instance
  Future<List<String>?> fetchRelaysForPubkey(String pubkey) async {
    if (_ndkInstances.isEmpty) return null;

    final ndk = _ndkInstances.values.first;
    try {
      final userRelayList = await ndk.userRelayLists.getSingleUserRelayList(pubkey);
      if (userRelayList != null && userRelayList.urls.isNotEmpty) {
        return userRelayList.urls.toList();
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
    await _dmSubscriptions[accountId]?.cancel();
    _dmSubscriptions.remove(accountId);
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
