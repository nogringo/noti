import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import '../models/models.dart';

class DatabaseService extends GetxService {
  late Database _db;

  final _accountsStore = stringMapStoreFactory.store('accounts');
  final _settingsStore = stringMapStoreFactory.store('notification_settings');
  final _notificationsStore = stringMapStoreFactory.store('notifications');

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

  // Notification History
  Future<void> saveNotification(NotificationHistory notification) async {
    await _notificationsStore.record(notification.id).put(_db, notification.toJson());
  }

  Future<List<NotificationHistory>> getNotifications({String? accountId, int? limit}) async {
    final finder = Finder(
      sortOrders: [SortOrder('createdAt', false)],
      limit: limit,
      filter: accountId != null ? Filter.equals('accountId', accountId) : null,
    );
    final records = await _notificationsStore.find(_db, finder: finder);
    return records.map((r) => NotificationHistory.fromJson(r.value)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final record = await _notificationsStore.record(id).get(_db);
    if (record != null) {
      final notification = NotificationHistory.fromJson(record);
      await _notificationsStore.record(id).put(_db, notification.copyWith(read: true).toJson());
    }
  }

  Future<void> markAllNotificationsRead({String? accountId}) async {
    final finder = Finder(
      filter: accountId != null
          ? Filter.and([
              Filter.equals('accountId', accountId),
              Filter.equals('read', false),
            ])
          : Filter.equals('read', false),
    );
    final records = await _notificationsStore.find(_db, finder: finder);
    for (final record in records) {
      final notification = NotificationHistory.fromJson(record.value);
      await _notificationsStore.record(record.key).put(_db, notification.copyWith(read: true).toJson());
    }
  }

  Future<void> deleteNotification(String id) async {
    await _notificationsStore.record(id).delete(_db);
  }

  Future<void> clearNotifications({String? accountId}) async {
    if (accountId != null) {
      final finder = Finder(filter: Filter.equals('accountId', accountId));
      await _notificationsStore.delete(_db, finder: finder);
    } else {
      await _notificationsStore.delete(_db);
    }
  }

  Future<int> getUnreadCount({String? accountId}) async {
    final finder = Finder(
      filter: accountId != null
          ? Filter.and([
              Filter.equals('accountId', accountId),
              Filter.equals('read', false),
            ])
          : Filter.equals('read', false),
    );
    final records = await _notificationsStore.find(_db, finder: finder);
    return records.length;
  }
}
