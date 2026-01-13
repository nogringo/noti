import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nostr_widgets/l10n/app_localizations.dart';
import 'package:system_theme/system_theme.dart';

import 'src/bindings/app_bindings.dart';
import 'src/ui/pages/pages.dart';

class NostrNotifyApp extends StatelessWidget {
  const NostrNotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = SystemTheme.accentColor.accent;

    return GetMaterialApp(
      title: 'Nostr Notifications',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialBinding: AppBindings(),
      home: const HomePage(),
    );
  }
}
