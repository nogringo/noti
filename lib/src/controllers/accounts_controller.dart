import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../services/services.dart';

class AccountsController extends GetxController {
  final DatabaseService _db = Get.find();
  final NostrService _nostr = Get.find();
  final NdkService _ndkService = Get.find();

  final accounts = <Account>[].obs;
  final selectedAccount = Rxn<Account>();
  final isLoading = false.obs;
  final error = Rxn<String>();

  // Metadata cache: pubkey -> (name, picture)
  final metadata = <String, ({String? name, String? picture})>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    isLoading.value = true;
    try {
      final ndk = _ndkService.ndk;
      final ndkAccounts = ndk.accounts.accounts.values.toList();
      accounts.assignAll(ndkAccounts);

      // Connect all accounts for notifications
      for (final account in ndkAccounts) {
        final settings = await _db.getOrCreateNotificationSettings(
          account.pubkey,
        );
        await _nostr.connectAccountFromNdk(account, settings);
      }

      if (accounts.isNotEmpty && selectedAccount.value == null) {
        selectedAccount.value = accounts.first;
      }

      // Load metadata for all accounts
      _loadAllMetadata();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadAllMetadata() async {
    final ndk = _ndkService.ndk;
    for (final account in accounts) {
      try {
        final meta = await ndk.metadata.loadMetadata(account.pubkey);
        if (meta != null) {
          metadata[account.pubkey] = (
            name: meta.displayName ?? meta.name,
            picture: meta.picture,
          );
        }
      } catch (_) {
        // Ignore metadata fetch errors
      }
    }
  }

  String? getAccountName(String pubkey) => metadata[pubkey]?.name;
  String? getAccountPicture(String pubkey) => metadata[pubkey]?.picture;

  Future<void> removeAccount(String pubkey) async {
    final ndk = _ndkService.ndk;
    await _nostr.disconnectAccount(pubkey);
    ndk.accounts.removeAccount(pubkey: pubkey);
    await _ndkService.saveAccountState();
    accounts.removeWhere((a) => a.pubkey == pubkey);
    metadata.remove(pubkey);

    if (selectedAccount.value?.pubkey == pubkey) {
      selectedAccount.value = accounts.isNotEmpty ? accounts.first : null;
    }
  }

  void selectAccount(Account account) {
    selectedAccount.value = account;
  }
}
