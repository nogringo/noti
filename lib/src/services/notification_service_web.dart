import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool webNotificationsGranted = false;
bool _faviconListenerAdded = false;

const _defaultFavicon = 'favicon.ico';
const _notificationFavicon = 'favicon-notification.ico';

Future<void> initWebNotifications() async {
  final permission = web.Notification.permission;
  if (permission == 'granted') {
    webNotificationsGranted = true;
  } else if (permission != 'denied') {
    final result = await web.Notification.requestPermission().toDart;
    webNotificationsGranted = result.toDart == 'granted';
  }

  // Reset favicon when window gets focus
  if (!_faviconListenerAdded) {
    web.window.addEventListener(
      'focus',
      ((web.Event e) => _setFavicon(_defaultFavicon)).toJS,
    );
    _faviconListenerAdded = true;
  }
}

void showWebNotification({required String title, required String body}) {
  // Change favicon to notification icon
  _setFavicon(_notificationFavicon);

  if (!webNotificationsGranted) return;

  web.Notification(
    title,
    web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
  );
}

void _setFavicon(String href) {
  final link =
      web.document.querySelector('link[rel="icon"]') as web.HTMLLinkElement?;
  if (link != null) {
    link.href = href;
  }
}
