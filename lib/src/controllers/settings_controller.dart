import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'accounts_controller.dart';

class SettingsController extends GetxController {
  final DatabaseService _db = Get.find();
  final NostrService _nostr = Get.find();
  final NdkService _ndkService = Get.find();
  final AccountsController _accounts = Get.find();

  final settings = Rxn<NotificationSettings>();
  final nip65Relays = <String>[].obs;
  final dmRelays = <String>[].obs;
  final isLoadingRelays = false.obs;

  Worker? _loadingWorker;

  @override
  void onInit() {
    super.onInit();
    // Listen to account changes
    ever(_accounts.selectedAccount, _onAccountChanged);
    // Handle initial account loading
    _initAccountSettings();
  }

  void _initAccountSettings() {
    if (!_accounts.isLoading.value && _accounts.selectedAccount.value != null) {
      _onAccountChanged(_accounts.selectedAccount.value);
    } else if (_accounts.isLoading.value) {
      // Wait for loading to complete
      _loadingWorker = ever(_accounts.isLoading, (isLoading) {
        if (!isLoading && _accounts.selectedAccount.value != null) {
          _onAccountChanged(_accounts.selectedAccount.value);
          _loadingWorker?.dispose();
          _loadingWorker = null;
        }
      });
    }
  }

  Future<void> _onAccountChanged(Account? account) async {
    if (account == null) {
      settings.value = null;
      nip65Relays.clear();
      dmRelays.clear();
      return;
    }

    settings.value = await _db.getOrCreateNotificationSettings(account.pubkey);
    await _loadRelays(account.pubkey);
  }

  Future<void> _loadRelays(String pubkey) async {
    isLoadingRelays.value = true;
    nip65Relays.clear();
    dmRelays.clear();

    try {
      // Fetch NIP-65 relays
      final nip65 = await _nostr.fetchRelaysForPubkey(pubkey);
      if (nip65 != null) {
        nip65Relays.assignAll(nip65);
      }

      // Fetch DM relays (kind 10050)
      final dm = await _fetchDmRelays(pubkey);
      dmRelays.assignAll(dm);
    } finally {
      isLoadingRelays.value = false;
    }
  }

  Future<List<String>> _fetchDmRelays(String pubkey) async {
    final ndk = _ndkService.ndk;
    try {
      final response = ndk.requests.query(
        filter: Filter(kinds: [10050], authors: [pubkey], limit: 1),
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

  Future<void> loadSettings(String pubkey) async {
    settings.value = await _db.getOrCreateNotificationSettings(pubkey);
  }

  Future<void> toggleDm() async {
    await _updateSetting((s) => s.copyWith(dm: !s.dm));
  }

  Future<void> toggleMention() async {
    await _updateSetting((s) => s.copyWith(mention: !s.mention));
  }

  Future<void> toggleZap() async {
    await _updateSetting((s) => s.copyWith(zap: !s.zap));
  }

  Future<void> toggleRepost() async {
    await _updateSetting((s) => s.copyWith(repost: !s.repost));
  }

  Future<void> toggleReaction() async {
    await _updateSetting((s) => s.copyWith(reaction: !s.reaction));
  }

  Future<void> _updateSetting(
    NotificationSettings Function(NotificationSettings) updater,
  ) async {
    final current = settings.value;
    if (current == null) return;

    final updated = updater(current);
    await _db.saveNotificationSettings(updated);
    settings.value = updated;

    // Reconnect to apply new filter
    final account = _accounts.selectedAccount.value;
    if (account != null) {
      await _nostr.disconnectAccount(account.pubkey);
      await _nostr.connectAccountFromNdk(account, updated);
    }
  }

  @override
  void onClose() {
    _loadingWorker?.dispose();
    super.onClose();
  }
}
