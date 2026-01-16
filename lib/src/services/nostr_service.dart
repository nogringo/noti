import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../models/models.dart';
import 'database_service.dart';
import 'ndk_service.dart';
import 'notification_service.dart';
import 'tray_service.dart';

class NostrService extends GetxService {
  final NotificationService _notificationService = Get.find();
  final DatabaseService _db = Get.find();
  final NdkService _ndkService = Get.find();

  TrayService? get _trayService =>
      Get.isRegistered<TrayService>() ? Get.find<TrayService>() : null;

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
    // Clean old processed events on startup
    await _db.cleanOldProcessedEvents();
    return this;
  }

  Future<String?> connectAccountFromNdk(
    Account account,
    NotificationSettings settings,
  ) async {
    try {
      _settings[account.pubkey] = settings;

      // Start subscriptions using shared NDK (with signer for AUTH)
      await _subscribeToEvents(account);

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _subscribeToEvents(Account account) async {
    final ndk = _ndkService.ndk;
    final settings = _settings[account.pubkey];
    if (settings == null) return;

    // Switch to the correct account for AUTH before any requests (only if needed)
    final currentAccount = ndk.accounts.getLoggedAccount();
    if (currentAccount?.pubkey != account.pubkey) {
      dev.log(
        '[NostrService] Switching from ${currentAccount?.pubkey.substring(0, 8) ?? 'NONE'} to ${account.pubkey.substring(0, 8)}',
      );
      ndk.accounts.switchAccount(pubkey: account.pubkey);
      await _ndkService.saveAccountState();
    }

    // Fetch relays for this account
    final relays =
        await fetchRelaysForPubkey(account.pubkey) ??
        ['wss://relay.damus.io', 'wss://relay.nostr.band', 'wss://nos.lol'];

    // Load saved timestamp or use now (for missed notifications recovery)
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final savedTimestamp = await _db.getLastSeenTimestamp(account.pubkey);
    final sevenDaysAgo = now - (7 * 24 * 60 * 60);
    final since = savedTimestamp != null
        ? max(savedTimestamp, sevenDaysAgo) // Don't go back more than 7 days
        : now;

    dev.log(
      '[NostrService] Subscribing for account ${account.pubkey.substring(0, 8)}, relays: $relays, since: $since (saved: $savedTimestamp)',
    );

    // Subscribe to DMs on DM relays (NIP-17)
    if (settings.dm) {
      await _subscribeToDms(account, ndk, since, relays);
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

    final filter = Filter(kinds: kinds, pTags: [account.pubkey], since: since);

    final response = ndk.requests.subscription(
      filter: filter,
      explicitRelays: relays,
    );

    final subscription = response.stream.listen((event) {
      dev.log(
        '[NostrService] Event received: kind=${event.kind}, id=${event.id.substring(0, 8)}, from=${event.pubKey.substring(0, 8)}',
      );
      _handleEvent(account, event);
    });

    _subscriptions[account.pubkey] = subscription;
  }

  Future<void> _subscribeToDms(
    Account account,
    Ndk ndk,
    int since,
    List<String> relays,
  ) async {
    dev.log(
      '[NostrService] DM subscription for account: ${account.pubkey.substring(0, 8)}',
    );

    // Fetch DM relay list (kind 10050) for NIP-17 from user's general relays
    List<String> dmRelays = await _fetchDmRelays(ndk, account.pubkey, relays);

    // Fallback to general relays if no DM relays found
    if (dmRelays.isEmpty) {
      dev.log(
        '[NostrService] No DM relays found (kind 10050), using general relays',
      );
      dmRelays = relays;
    } else {
      dev.log('[NostrService] DM relays (kind 10050): $dmRelays');
    }

    // NIP-17: gift wrap created_at can be randomized up to 2 days in the past
    final dmSince = since - (2 * 24 * 60 * 60); // 2 days before

    final dmFilter = Filter(
      kinds: [kindGiftWrap], // NIP-17 uses gift wraps (kind 1059)
      pTags: [account.pubkey],
      since: dmSince,
    );

    final dmResponse = ndk.requests.subscription(
      filter: dmFilter,
      explicitRelays: dmRelays,
    );

    final dmSubscription = dmResponse.stream.listen((event) {
      dev.log(
        '[NostrService] DM Event received: kind=${event.kind}, id=${event.id.substring(0, 8)}, from=${event.pubKey.substring(0, 8)}',
      );
      _handleEvent(account, event);
    });

    _dmSubscriptions[account.pubkey] = dmSubscription;
  }

  Future<List<String>> _fetchDmRelays(
    Ndk ndk,
    String pubkey,
    List<String> userRelays,
  ) async {
    try {
      final response = ndk.requests.query(
        filter: Filter(kinds: [kindDmRelayList], authors: [pubkey], limit: 1),
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

  Future<void> _handleEvent(Account account, Nip01Event event) async {
    if (_trayService?.isPaused ?? false) {
      dev.log('[NostrService] Event ignored: notifications paused');
      return;
    }

    final settings = _settings[account.pubkey];
    if (settings == null) {
      dev.log('[NostrService] Event ignored: no settings for account');
      return;
    }

    // Don't notify for own events
    if (event.pubKey == account.pubkey) {
      dev.log('[NostrService] Event ignored: own event');
      return;
    }

    // Check if event was already processed
    if (await _db.isEventProcessed(event.id)) {
      dev.log('[NostrService] Event ignored: already processed');
      return;
    }

    // Mark as processed
    await _db.markEventProcessed(event.id);

    // Save timestamp for missed notifications recovery
    await _db.saveLastSeenTimestamp(account.pubkey, event.createdAt);

    final fromName = _shortenPubkey(event.pubKey);

    switch (event.kind) {
      case kindGiftWrap:
        // NIP-17 DM (gift wrapped)
        if (settings.dm) {
          await _handleGiftWrap(account, event);
        }
        break;

      case kindNote:
        if (settings.mention && _isMention(event, account.pubkey)) {
          dev.log('[NostrService] Notification: Mention from $fromName');
          _notificationService.showMentionNotification(
            accountId: account.pubkey,
            fromName: fromName,
            eventId: event.id,
          );
        }
        break;

      case kindRepost:
        if (settings.repost) {
          dev.log('[NostrService] Notification: Repost from $fromName');
          _notificationService.showRepostNotification(
            accountId: account.pubkey,
            fromName: fromName,
          );
        }
        break;

      case kindReaction:
        if (settings.reaction) {
          dev.log(
            '[NostrService] Notification: Reaction "${event.content}" from $fromName',
          );
          _notificationService.showReactionNotification(
            accountId: account.pubkey,
            fromName: fromName,
            reaction: event.content,
          );
        }
        break;

      case kindZapReceipt:
        if (settings.zap) {
          final amount = _parseZapAmount(event);
          dev.log(
            '[NostrService] Notification: Zap $amount sats from $fromName',
          );
          _notificationService.showZapNotification(
            accountId: account.pubkey,
            fromName: fromName,
            amount: amount,
          );
        }
        break;
    }
  }

  Future<void> _handleGiftWrap(
    Account account,
    Nip01Event giftWrapEvent,
  ) async {
    try {
      // Unwrap the gift wrap to get the actual message and sender
      final ndk = _ndkService.ndk;
      final rumor = await ndk.giftWrap.fromGiftWrap(giftWrap: giftWrapEvent);

      final senderPubkey = rumor.pubKey;
      final fullContent = rumor.content;
      final messagePreview = fullContent.length > 50
          ? '${fullContent.substring(0, 50)}...'
          : fullContent;

      // Don't notify for own messages
      if (senderPubkey == account.pubkey) {
        dev.log('[NostrService] DM ignored: own message');
        return;
      }

      // Try to get sender's name
      String senderName = _shortenPubkey(senderPubkey);
      try {
        final metadata = await ndk.metadata.loadMetadata(senderPubkey);
        if (metadata != null) {
          senderName = metadata.displayName ?? metadata.name ?? senderName;
        }
      } catch (_) {}

      final rawEvent = jsonEncode(giftWrapEvent.toJson());

      dev.log('[NostrService] Notification: DM from $senderName');
      _notificationService.showDmNotification(
        accountId: account.pubkey,
        fromPubkey: senderPubkey,
        fromName: senderName,
        preview: messagePreview,
        fullContent: fullContent,
        rawEvent: rawEvent,
      );
    } catch (e) {
      dev.log('[NostrService] Failed to unwrap gift wrap: $e');
      // Fallback: show generic notification
      _notificationService.showDmNotification(
        accountId: account.pubkey,
        fromPubkey: giftWrapEvent.pubKey,
      );
    }
  }

  bool _isMention(Nip01Event event, String pubkey) {
    return event.tags.any(
      (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey,
    );
  }

  int _parseZapAmount(Nip01Event event) {
    try {
      final bolt11Tag = event.tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'bolt11',
        orElse: () => [],
      );
      if (bolt11Tag.length < 2) return 0;

      final invoice = bolt11Tag[1].toLowerCase();

      // Match ln + network (bc/tb/bcrt) + amount + multiplier + "1" separator
      final regex = RegExp(r'^ln(?:bc|tb|bcrt)(\d+)([munp]?)1');
      final match = regex.firstMatch(invoice);

      if (match == null) return 0;

      final amount = int.parse(match.group(1)!);
      final multiplier = match.group(2) ?? '';

      // Convert to satoshis based on multiplier
      // 1 BTC = 100,000,000 sats
      switch (multiplier) {
        case 'm': // milli-bitcoin = 0.001 BTC = 100,000 sats
          return amount * 100000;
        case 'u': // micro-bitcoin = 0.000001 BTC = 100 sats
          return amount * 100;
        case 'n': // nano-bitcoin = 0.000000001 BTC = 0.1 sats
          return (amount * 0.1).round();
        case 'p': // pico-bitcoin = 0.000000000001 BTC = 0.0001 sats
          return (amount * 0.0001).round();
        default: // no multiplier = BTC (rare)
          return amount * 100000000;
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

  /// Fetch metadata for a specific pubkey
  Future<({String? name, String? picture})?> fetchMetadataForPubkey(
    String pubkey,
  ) async {
    final ndk = _ndkService.ndk;
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

  /// Fetch relay list for a specific pubkey
  Future<List<String>?> fetchRelaysForPubkey(String pubkey) async {
    final ndk = _ndkService.ndk;
    try {
      final userRelayList = await ndk.userRelayLists.getSingleUserRelayList(
        pubkey,
      );
      if (userRelayList != null && userRelayList.urls.isNotEmpty) {
        return userRelayList.urls.toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateSettings(
    String pubkey,
    NotificationSettings settings,
  ) async {
    _settings[pubkey] = settings;
  }

  Future<void> disconnectAccount(String pubkey) async {
    await _subscriptions[pubkey]?.cancel();
    _subscriptions.remove(pubkey);
    await _dmSubscriptions[pubkey]?.cancel();
    _dmSubscriptions.remove(pubkey);
    _settings.remove(pubkey);
  }

  Future<void> disconnectAll() async {
    for (final pubkey in _settings.keys.toList()) {
      await disconnectAccount(pubkey);
    }
  }

  @override
  void onClose() {
    disconnectAll();
    super.onClose();
  }
}
