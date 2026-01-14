import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'src/services/services.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if another instance is already running
  if (!await FlutterSingleInstance().isFirstInstance()) {
    // Focus the existing window and exit
    await FlutterSingleInstance().focus();
    exit(0);
  }

  // Check if app should start minimized
  final startMinimized = args.contains('--minimized');

  // Load system accent color
  await SystemTheme.accentColor.load();

  // Initialize window manager for Linux desktop
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(600, 400),
    center: true,
    title: 'Noti',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (!startMinimized) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  // Initialize services
  await _initServices();

  runApp(const NotiApp());
}

Future<void> _initServices() async {
  // Database first
  await Get.putAsync(() => DatabaseService().init());

  // Notifications
  await Get.putAsync(() => NotificationService().init());

  // Tray
  final trayService = await Get.putAsync(() => TrayService().init());

  // Configure tray callbacks
  trayService.onOpenRequested = () async {
    await windowManager.show();
    await windowManager.focus();
  };

  trayService.onQuitRequested = () {
    exit(0);
  };

  // NDK service (shared instance with signer)
  await Get.putAsync(() => NdkService().init());

  // Nostr service
  await Get.putAsync(() => NostrService().init());
}
