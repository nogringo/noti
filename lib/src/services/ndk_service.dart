import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_widgets/nostr_widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_cache_manager/sembast_cache_manager.dart';
import 'package:sembast_web/sembast_web.dart';

class NdkService extends GetxService {
  late Ndk _ndk;

  Ndk get ndk => _ndk;

  Future<NdkService> init() async {
    final dbName = kDebugMode ? 'ndk_cache_dev.db' : 'ndk_cache.db';

    late Database db;
    if (kIsWeb) {
      db = await databaseFactoryWeb.openDatabase(dbName);
    } else {
      final appDir = await getApplicationSupportDirectory();
      db = await databaseFactoryIo.openDatabase(join(appDir.path, dbName));
    }

    final cacheManager = SembastCacheManager(db);

    _ndk = Ndk(
      NdkConfig(
        eventVerifier: Bip340EventVerifier(),
        cache: cacheManager,
        bootstrapRelays: [
          "wss://nostr-01.yakihonne.com",
          "wss://relay.damus.io",
          "wss://relay.primal.net",
          "wss://nostr-01.uid.ovh",
          "wss://nostr-02.uid.ovh",
        ],
      ),
    );

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
