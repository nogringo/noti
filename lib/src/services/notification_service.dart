import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<NotificationService> init() async {
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
    required String fromName,
    required String fromPubkey,
  }) async {
    await showNotification(
      title: 'New DM',
      body: 'Message from $fromName',
      payload: 'dm:$fromPubkey',
    );
  }

  Future<void> showMentionNotification({
    required String fromName,
    required String eventId,
  }) async {
    await showNotification(
      title: 'Mention',
      body: '$fromName mentioned you',
      payload: 'mention:$eventId',
    );
  }

  Future<void> showZapNotification({
    required String fromName,
    required int amount,
  }) async {
    await showNotification(
      title: 'Zap received',
      body: '$fromName zapped you $amount sats',
      payload: 'zap',
    );
  }

  Future<void> showRepostNotification({
    required String fromName,
  }) async {
    await showNotification(
      title: 'Repost',
      body: '$fromName reposted your note',
      payload: 'repost',
    );
  }

  Future<void> showReactionNotification({
    required String fromName,
    required String reaction,
  }) async {
    await showNotification(
      title: 'Reaction',
      body: '$fromName reacted $reaction',
      payload: 'reaction',
    );
  }
}
