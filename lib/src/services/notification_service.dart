import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../controllers/notification_history_controller.dart';
import '../models/models.dart';
import 'database_service.dart';

class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  late final DatabaseService _db;
  NotificationHistoryController? _historyController;

  Future<NotificationService> init() async {
    _db = Get.find<DatabaseService>();

    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
      defaultIcon: AssetsLinuxIcon('assets/icons/app_icon.png'),
    );

    final initSettings = InitializationSettings(linux: linuxSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    return this;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - could open the app or specific conversation
  }

  Future<void> _saveAndNotifyHistory(NotificationHistory notification) async {
    await _db.saveNotification(notification);

    // Update the history controller if it's registered
    _historyController ??= Get.isRegistered<NotificationHistoryController>()
        ? Get.find<NotificationHistoryController>()
        : null;

    if (_historyController != null) {
      _historyController!.notifications.insert(0, notification);
      _historyController!.unreadCount.value++;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
      category: LinuxNotificationCategory.imReceived,
    );

    const details = NotificationDetails(linux: linuxDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showDmNotification({
    required String accountId,
    required String fromPubkey,
  }) async {
    const title = 'New DM';
    const body = 'You received a new message';

    final notification = NotificationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: NotificationType.dm,
      title: title,
      body: body,
      fromPubkey: fromPubkey,
      createdAt: DateTime.now(),
    );

    await _saveAndNotifyHistory(notification);
    await showNotification(title: title, body: body, payload: 'dm:$fromPubkey');
  }

  Future<void> showMentionNotification({
    required String accountId,
    required String fromName,
    required String eventId,
  }) async {
    final title = 'Mention';
    final body = '$fromName mentioned you';

    final notification = NotificationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: NotificationType.mention,
      title: title,
      body: body,
      eventId: eventId,
      createdAt: DateTime.now(),
    );

    await _saveAndNotifyHistory(notification);
    await showNotification(title: title, body: body, payload: 'mention:$eventId');
  }

  Future<void> showZapNotification({
    required String accountId,
    required String fromName,
    required int amount,
  }) async {
    final title = 'Zap received';
    final body = '$fromName zapped you ${amount > 0 ? '$amount sats' : ''}';

    final notification = NotificationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: NotificationType.zap,
      title: title,
      body: body,
      zapAmount: amount,
      createdAt: DateTime.now(),
    );

    await _saveAndNotifyHistory(notification);
    await showNotification(title: title, body: body, payload: 'zap');
  }

  Future<void> showRepostNotification({
    required String accountId,
    required String fromName,
  }) async {
    final title = 'Repost';
    final body = '$fromName reposted your note';

    final notification = NotificationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: NotificationType.repost,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );

    await _saveAndNotifyHistory(notification);
    await showNotification(title: title, body: body, payload: 'repost');
  }

  Future<void> showReactionNotification({
    required String accountId,
    required String fromName,
    required String reaction,
  }) async {
    final title = 'Reaction';
    final body = '$fromName reacted $reaction';

    final notification = NotificationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: accountId,
      type: NotificationType.reaction,
      title: title,
      body: body,
      reaction: reaction,
      createdAt: DateTime.now(),
    );

    await _saveAndNotifyHistory(notification);
    await showNotification(title: title, body: body, payload: 'reaction');
  }
}
