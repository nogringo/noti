import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService extends GetxService with TrayListener {
  final _isPaused = false.obs;
  final _isAvailable = false.obs;

  bool get isPaused => _isPaused.value;
  bool get isAvailable => _isAvailable.value;

  VoidCallback? onOpenRequested;
  VoidCallback? onQuitRequested;

  Future<TrayService> init() async {
    try {
      trayManager.addListener(this);

      await trayManager.setIcon('assets/icons/app_icon.png');
      await trayManager.setToolTip('Nostr Notifications');

      await _updateMenu();
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

  Future<void> _updateMenu() async {
    if (!_isAvailable.value) return;

    try {
      final menu = Menu(
        items: [
          MenuItem(
            key: 'open',
            label: 'Open',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'pause',
            label: _isPaused.value ? 'Resume notifications' : 'Pause notifications',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Quit',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('Failed to update tray menu: $e');
    }
  }

  void togglePause() {
    _isPaused.value = !_isPaused.value;
    _updateMenu();
  }

  @override
  void onTrayIconMouseDown() {
    onOpenRequested?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        onOpenRequested?.call();
        break;
      case 'pause':
        togglePause();
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
