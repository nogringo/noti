import 'package:get/get.dart';

import '../models/models.dart';
import '../services/services.dart';

class NotificationHistoryController extends GetxController {
  final DatabaseService _db = Get.find();

  final notifications = <NotificationHistory>[].obs;
  final unreadCount = 0.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications({String? accountId}) async {
    isLoading.value = true;
    try {
      final loaded = await _db.getNotifications(accountId: accountId, limit: 100);
      notifications.assignAll(loaded);
      await _updateUnreadCount(accountId: accountId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateUnreadCount({String? accountId}) async {
    unreadCount.value = await _db.getUnreadCount(accountId: accountId);
  }

  Future<void> markAsRead(String id) async {
    await _db.markNotificationRead(id);
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(read: true);
    }
    await _updateUnreadCount();
  }

  Future<void> markAllAsRead({String? accountId}) async {
    await _db.markAllNotificationsRead(accountId: accountId);
    for (var i = 0; i < notifications.length; i++) {
      if (!notifications[i].read) {
        notifications[i] = notifications[i].copyWith(read: true);
      }
    }
    unreadCount.value = 0;
  }

  Future<void> deleteNotification(String id) async {
    await _db.deleteNotification(id);
    notifications.removeWhere((n) => n.id == id);
    await _updateUnreadCount();
  }

  Future<void> clearAll({String? accountId}) async {
    await _db.clearNotifications(accountId: accountId);
    notifications.clear();
    unreadCount.value = 0;
  }

  @override
  Future<void> refresh({String? accountId}) async {
    await loadNotifications(accountId: accountId);
  }
}
