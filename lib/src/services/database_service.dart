import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/models.dart';

class DatabaseService extends GetxService {
  late Database _db;

  final _accountsStore = stringMapStoreFactory.store('accounts');
  final _settingsStore = stringMapStoreFactory.store('notification_settings');

  Future<DatabaseService> init() async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = join(appDir.path, 'nostr_notify.db');
    _db = await databaseFactoryIo.openDatabase(dbPath);
    return this;
  }

  // Accounts
  Future<List<NotifyAccount>> getAccounts() async {
    final records = await _accountsStore.find(_db);
    return records.map((r) => NotifyAccount.fromJson(r.value)).toList();
  }

  Future<NotifyAccount?> getAccount(String id) async {
    final record = await _accountsStore.record(id).get(_db);
    return record != null ? NotifyAccount.fromJson(record) : null;
  }

  Future<void> saveAccount(NotifyAccount account) async {
    await _accountsStore.record(account.id).put(_db, account.toJson());
  }

  Future<void> deleteAccount(String id) async {
    await _accountsStore.record(id).delete(_db);
    await _settingsStore.record(id).delete(_db);
  }

  // Notification Settings
  Future<NotificationSettings?> getNotificationSettings(String accountId) async {
    final record = await _settingsStore.record(accountId).get(_db);
    return record != null ? NotificationSettings.fromJson(record) : null;
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    await _settingsStore.record(settings.accountId).put(_db, settings.toJson());
  }

  Future<NotificationSettings> getOrCreateNotificationSettings(String accountId) async {
    var settings = await getNotificationSettings(accountId);
    if (settings == null) {
      settings = NotificationSettings(accountId: accountId);
      await saveNotificationSettings(settings);
    }
    return settings;
  }
}
