import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_widgets/nostr_widgets.dart';

class NdkService extends GetxService {
  late Ndk _ndk;

  Ndk get ndk => _ndk;

  Future<NdkService> init() async {
    _ndk = Ndk(NdkConfig(
      eventVerifier: Bip340EventVerifier(),
      cache: MemCacheManager(),
    ));

    // Restore accounts from local storage (includes signers)
    await nRestoreAccounts(_ndk);

    return this;
  }

  /// Save account state after login/logout
  Future<void> saveAccountState() async {
    await nSaveAccountsState(_ndk);
  }

  /// Check if user is logged in
  bool get isLoggedIn => _ndk.accounts.isLoggedIn;

  /// Get logged account
  Account? get loggedAccount => _ndk.accounts.getLoggedAccount();
}
