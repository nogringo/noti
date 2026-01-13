import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'accounts_controller.dart';

class SettingsController extends GetxController {
  final DatabaseService _db = Get.find();
  final NostrService _nostr = Get.find();
  final AccountsController _accounts = Get.find();

  final settings = Rxn<NotificationSettings>();

  @override
  void onInit() {
    super.onInit();
    // Listen to account changes
    ever(_accounts.selectedAccount, _onAccountChanged);
  }

  Future<void> _onAccountChanged(Account? account) async {
    if (account == null) {
      settings.value = null;
      return;
    }

    settings.value = await _db.getOrCreateNotificationSettings(account.pubkey);
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
}
