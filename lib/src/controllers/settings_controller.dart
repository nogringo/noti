import 'package:get/get.dart';

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

  Future<void> _onAccountChanged(NotifyAccount? account) async {
    if (account == null) {
      settings.value = null;
      return;
    }

    settings.value = await _db.getOrCreateNotificationSettings(account.id);
  }

  Future<void> loadSettings(String accountId) async {
    settings.value = await _db.getOrCreateNotificationSettings(accountId);
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

  Future<void> _updateSetting(NotificationSettings Function(NotificationSettings) updater) async {
    final current = settings.value;
    if (current == null) return;

    final updated = updater(current);
    await _db.saveNotificationSettings(updated);
    await _nostr.updateSettings(current.accountId, updated);
    settings.value = updated;
  }
}
