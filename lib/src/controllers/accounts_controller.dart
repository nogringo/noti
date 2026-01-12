import 'package:get/get.dart';

import '../models/models.dart';
import '../services/services.dart';

class AccountsController extends GetxController {
  final DatabaseService _db = Get.find();
  final NostrService _nostr = Get.find();

  final accounts = <NotifyAccount>[].obs;
  final selectedAccount = Rxn<NotifyAccount>();
  final isLoading = false.obs;
  final error = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    isLoading.value = true;
    try {
      final loadedAccounts = await _db.getAccounts();
      accounts.assignAll(loadedAccounts);

      // Connect all active accounts
      for (final account in loadedAccounts.where((a) => a.active)) {
        final settings = await _db.getOrCreateNotificationSettings(account.id);
        await _nostr.connectAccount(account, settings);
      }

      if (accounts.isNotEmpty && selectedAccount.value == null) {
        selectedAccount.value = accounts.first;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> addAccount(String bunkerUrl) async {
    isLoading.value = true;
    error.value = null;

    try {
      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Parse pubkey from bunker URL
      final pubkey = _parsePubkeyFromBunkerUrl(bunkerUrl);
      if (pubkey == null) {
        return 'Invalid bunker URL';
      }

      // Default relays
      final relays = [
        'wss://relay.damus.io',
        'wss://relay.nostr.band',
        'wss://nos.lol',
      ];

      final account = NotifyAccount(
        id: id,
        pubkey: pubkey,
        bunkerUrl: bunkerUrl,
        relays: relays,
        active: true,
      );

      // Create default notification settings
      final settings = NotificationSettings(accountId: id);

      // Try to connect
      final connectError = await _nostr.connectAccount(account, settings);
      if (connectError != null) {
        return connectError;
      }

      // Save to database
      await _db.saveAccount(account);
      await _db.saveNotificationSettings(settings);

      // Update local state
      accounts.add(account);
      selectedAccount.value = account;

      return null; // Success
    } catch (e) {
      return e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  String? _parsePubkeyFromBunkerUrl(String url) {
    // bunker://<remote-signer-pubkey>?relay=...
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'bunker' && uri.host.isNotEmpty) {
        return uri.host;
      }
    } catch (_) {}
    return null;
  }

  Future<void> removeAccount(String id) async {
    await _nostr.disconnectAccount(id);
    await _db.deleteAccount(id);
    accounts.removeWhere((a) => a.id == id);

    if (selectedAccount.value?.id == id) {
      selectedAccount.value = accounts.isNotEmpty ? accounts.first : null;
    }
  }

  Future<void> toggleAccountActive(String id) async {
    final index = accounts.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final account = accounts[index];
    final updated = account.copyWith(active: !account.active);

    await _db.saveAccount(updated);
    accounts[index] = updated;

    if (updated.active) {
      final settings = await _db.getOrCreateNotificationSettings(id);
      await _nostr.connectAccount(updated, settings);
    } else {
      await _nostr.disconnectAccount(id);
    }
  }

  Future<void> updateAccountRelays(String id, List<String> relays) async {
    final index = accounts.indexWhere((a) => a.id == id);
    if (index == -1) return;

    final account = accounts[index];
    final updated = account.copyWith(relays: relays);

    await _db.saveAccount(updated);
    accounts[index] = updated;

    // Reconnect with new relays
    if (updated.active) {
      await _nostr.disconnectAccount(id);
      final settings = await _db.getOrCreateNotificationSettings(id);
      await _nostr.connectAccount(updated, settings);
    }
  }

  void selectAccount(NotifyAccount account) {
    selectedAccount.value = account;
  }
}
