import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:tray_manager/tray_manager.dart';

class TrayService extends GetxService with TrayListener {
  final _isPaused = false.obs;
  final _isAvailable = false.obs;

  bool get isPaused => _isPaused.value;
  bool get isAvailable => _isAvailable.value;

  VoidCallback? onOpenRequested;
  VoidCallback? onQuitRequested;

  String _getIconPath() {
    if (kDebugMode) {
      return 'assets/icons/app_icon.png';
    }
    // In release mode, the icon is in data/flutter_assets/
    final exeDir = path.dirname(Platform.resolvedExecutable);
    return path.join(
      exeDir,
      'data',
      'flutter_assets',
      'assets',
      'icons',
      'app_icon.png',
    );
  }

  Future<TrayService> init() async {
    try {
      trayManager.addListener(this);

      await trayManager.setIcon(_getIconPath());
      await trayManager.setToolTip('Nostr Notifications');

      // Sur Linux/AppIndicator, on DOIT avoir un menu pour interagir
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Ouvrir'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Quitter'),
          ],
        ),
      );

      _isAvailable.value = true;
    } on MissingPluginException catch (e) {
      debugPrint('Tray manager not available: $e');
      _isAvailable.value = false;
    } catch (e) {
      debugPrint('Tray manager error: $e');
      _isAvailable.value = false;
    }

    return this;
  }

  void togglePause() {
    _isPaused.value = !_isPaused.value;
  }

  @override
  void onTrayIconMouseDown() {
    // Sur Linux, les clics directs ne fonctionnent pas avec AppIndicator
    // On garde pour Windows/macOS
    onOpenRequested?.call();
  }

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        onOpenRequested?.call();
        break;
      case 'quit':
        onQuitRequested?.call();
        break;
    }
  }

  @override
  void onClose() {
    if (_isAvailable.value) {
      trayManager.removeListener(this);
      trayManager.destroy();
    }
    super.onClose();
  }
}
