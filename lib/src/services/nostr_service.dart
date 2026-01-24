import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../models/models.dart';
import '../utils/nostr_utils.dart';
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
      authenticateAs: [account],
    );

    final subscription = response.stream.listen((event) {
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
    // Fetch DM relay list (kind 10050) for NIP-17 from user's general relays
    List<String> dmRelays = await _fetchDmRelays(ndk, account, relays);

    // Fallback to general relays if no DM relays found
    if (dmRelays.isEmpty) {
      dmRelays = relays;
    }

    // Wait for relay connections and AUTH handshake to complete
    await Future.delayed(const Duration(seconds: 2));

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
      authenticateAs: [account],
    );

    final dmSubscription = dmResponse.stream.listen((event) {
      _handleEvent(account, event);
    });

    _dmSubscriptions[account.pubkey] = dmSubscription;
  }

  Future<List<String>> _fetchDmRelays(
    Ndk ndk,
    Account account,
    List<String> userRelays,
  ) async {
    try {
      final response = ndk.requests.query(
        filter: Filter(
          kinds: [kindDmRelayList],
          authors: [account.pubkey],
          limit: 1,
        ),
        explicitRelays: userRelays,
        authenticateAs: [account],
      );

      // Wait for all relays and take the most recent event
      Nip01Event? latestEvent;
      await for (final event in response.stream.timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) => sink.close(),
      )) {
        if (latestEvent == null || event.createdAt > latestEvent.createdAt) {
          latestEvent = event;
        }
      }

      if (latestEvent != null) {
        // Extract relay URLs from 'relay' tags
        final relays = <String>[];
        for (final tag in latestEvent.tags) {
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
    if (_trayService?.isPaused ?? false) return;

    final settings = _settings[account.pubkey];
    if (settings == null) return;

    // Don't notify for own events
    if (event.pubKey == account.pubkey) return;

    // Check if event was already processed
    if (await _db.isEventProcessed(event.id)) return;

    // Mark as processed
    await _db.markEventProcessed(event.id);

    // Save timestamp for missed notifications recovery
    await _db.saveLastSeenTimestamp(account.pubkey, event.createdAt);

    switch (event.kind) {
      case kindGiftWrap:
        // NIP-17 DM (gift wrapped)
        if (settings.dm) {
          await _handleGiftWrap(account, event);
        }
        break;

      case kindNote:
        if (settings.mention && _isMention(event, account.pubkey)) {
          final senderName = await _getDisplayName(event.pubKey);
          _notificationService.showMentionNotification(
            accountId: account.pubkey,
            fromPubkey: event.pubKey,
            fromName: senderName,
            eventId: event.id,
            fullContent: event.content,
            rawEvent: jsonEncode(Nip01EventModel.fromEntity(event).toJson()),
          );
        }
        break;

      case kindRepost:
        if (settings.repost) {
          final senderName = await _getDisplayName(event.pubKey);
          _notificationService.showRepostNotification(
            accountId: account.pubkey,
            fromName: senderName,
          );
        }
        break;

      case kindReaction:
        if (settings.reaction) {
          final senderName = await _getDisplayName(event.pubKey);
          _notificationService.showReactionNotification(
            accountId: account.pubkey,
            fromName: senderName,
            reaction: event.content,
          );
        }
        break;

      case kindZapReceipt:
        if (settings.zap) {
          final senderName = await _getDisplayName(event.pubKey);
          final amount = _parseZapAmount(event);
          _notificationService.showZapNotification(
            accountId: account.pubkey,
            fromName: senderName,
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
      // Unwrap the gift wrap using the specific account's signer
      final rumor = await _unwrapGiftWrap(account, giftWrapEvent);

      final senderPubkey = rumor.pubKey;
      final fullContent = rumor.content;
      final messagePreview = fullContent.length > 50
          ? '${fullContent.substring(0, 50)}...'
          : fullContent;

      // Don't notify for own messages
      if (senderPubkey == account.pubkey) return;

      final senderName = await _getDisplayName(senderPubkey);

      final rawEvent = jsonEncode(
        Nip01EventModel.fromEntity(giftWrapEvent).toJson(),
      );

      _notificationService.showDmNotification(
        accountId: account.pubkey,
        fromPubkey: senderPubkey,
        fromName: senderName,
        preview: messagePreview,
        fullContent: fullContent,
        rawEvent: rawEvent,
      );
    } catch (_) {
      // Fallback: show generic notification
      _notificationService.showDmNotification(
        accountId: account.pubkey,
        fromPubkey: giftWrapEvent.pubKey,
      );
    }
  }

  /// Unwrap a gift wrap (NIP-17) using the specific account's signer
  Future<Nip01Event> _unwrapGiftWrap(
    Account account,
    Nip01Event giftWrap,
  ) async {
    // Step 1: Decrypt the gift wrap to get the seal
    final decryptedSealJson = await account.signer.decryptNip44(
      ciphertext: giftWrap.content,
      senderPubKey: giftWrap.pubKey,
    );

    if (decryptedSealJson == null) {
      throw Exception('Failed to decrypt gift wrap');
    }

    final sealEvent = Nip01EventModel.fromJson(jsonDecode(decryptedSealJson));

    // Step 2: Decrypt the seal to get the rumor
    final decryptedRumorJson = await account.signer.decryptNip44(
      ciphertext: sealEvent.content,
      senderPubKey: sealEvent.pubKey,
    );

    if (decryptedRumorJson == null) {
      throw Exception('Failed to decrypt seal');
    }

    final rumor = Nip01EventModel.fromJson(jsonDecode(decryptedRumorJson));
    return rumor;
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

  Future<String> _getDisplayName(String pubkey) async {
    try {
      final metadata = await _ndkService.ndk.metadata.loadMetadata(pubkey);
      if (metadata != null) {
        final name = metadata.displayName ?? metadata.name;
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    // Fallback: shortened npub
    return shortenNpub(pubkey);
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

  /// Fetch relay list (NIP-65 kind 10002) for a specific pubkey
  Future<List<String>?> fetchRelaysForPubkey(String pubkey) async {
    final ndk = _ndkService.ndk;
    try {
      final response = ndk.requests.query(
        filter: Filter(kinds: [10002], authors: [pubkey], limit: 1),
      );

      Nip01Event? latestEvent;
      await for (final event in response.stream.timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) => sink.close(),
      )) {
        if (latestEvent == null || event.createdAt > latestEvent.createdAt) {
          latestEvent = event;
        }
      }

      if (latestEvent != null) {
        final relays = <String>[];
        for (final tag in latestEvent.tags) {
          if (tag.isNotEmpty && tag[0] == 'r' && tag.length >= 2) {
            relays.add(tag[1]);
          }
        }
        if (relays.isNotEmpty) {
          return relays;
        }
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
