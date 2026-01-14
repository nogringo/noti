import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:nostr_widgets/l10n/app_localizations.dart' as nostr_widgets;
import 'package:system_theme/system_theme.dart';

import 'src/bindings/app_bindings.dart';
import 'src/ui/pages/pages.dart';

class NotiApp extends StatelessWidget {
  const NotiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = SystemTheme.accentColor.accent;

    return GetMaterialApp(
      title: 'Noti',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        nostr_widgets.AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Get.deviceLocale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      initialBinding: AppBindings(),
      home: const HomePage(),
    );
  }
}
