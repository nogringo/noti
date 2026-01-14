import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/models.dart';
import '../services/services.dart';

class AppSettingsController extends GetxController {
  final DatabaseService _db = Get.find();

  final settings = Rx<AppSettings>(AppSettings());
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    isLoading.value = true;
    settings.value = await _db.getAppSettings();
    if (!kIsWeb) {
      await _setupLaunchAtStartup();
    }
    isLoading.value = false;
  }

  Future<void> _setupLaunchAtStartup() async {
    if (kIsWeb) return;

    final packageInfo = await PackageInfo.fromPlatform();

    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      args: settings.value.startMinimized ? ['--minimized'] : [],
    );
  }

  Future<void> toggleLaunchAtStartup() async {
    if (kIsWeb) return;

    final newValue = !settings.value.launchAtStartup;

    if (newValue) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }

    settings.value = settings.value.copyWith(launchAtStartup: newValue);
    await _db.saveAppSettings(settings.value);
  }

  Future<void> toggleStartMinimized() async {
    if (kIsWeb) return;

    final newValue = !settings.value.startMinimized;
    settings.value = settings.value.copyWith(startMinimized: newValue);
    await _db.saveAppSettings(settings.value);

    // Re-setup launch_at_startup with new args
    await _setupLaunchAtStartup();

    // If autostart is enabled, re-enable to update the args
    if (settings.value.launchAtStartup) {
      await launchAtStartup.enable();
    }
  }
}
