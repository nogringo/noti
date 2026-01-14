import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool webNotificationsGranted = false;

Future<void> initWebNotifications() async {
  final permission = web.Notification.permission;
  if (permission == 'granted') {
    webNotificationsGranted = true;
  } else if (permission != 'denied') {
    final result = await web.Notification.requestPermission().toDart;
    webNotificationsGranted = result.toDart == 'granted';
  }
}

void showWebNotification({required String title, required String body}) {
  if (!webNotificationsGranted) return;

  web.Notification(
    title,
    web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
  );
}
