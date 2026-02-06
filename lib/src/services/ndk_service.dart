import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_cache_manager/sembast_cache_manager.dart';
import 'package:sembast_web/sembast_web.dart';

class NdkService extends GetxService {
  late Ndk _ndk;
  late NdkFlutter _ndkFlutter;

  Ndk get ndk => _ndk;
  NdkFlutter get ndkFlutter => _ndkFlutter;

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

    _ndkFlutter = NdkFlutter(ndk: _ndk);

    // Restore accounts from local storage (includes signers)
    await _ndkFlutter.restoreAccountsState();

    return this;
  }

  /// Save account state after login/logout
  Future<void> saveAccountState() async {
    await _ndkFlutter.saveAccountsState();
  }

  /// Check if user is logged in
  bool get isLoggedIn => _ndk.accounts.isLoggedIn;

  /// Get logged account
  Account? get loggedAccount => _ndk.accounts.getLoggedAccount();
}
