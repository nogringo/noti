import 'package:get/get.dart';

import '../controllers/controllers.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountsController>(() => AccountsController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<NotificationHistoryController>(
      () => NotificationHistoryController(),
    );
    Get.lazyPut<AppSettingsController>(() => AppSettingsController());
  }
}
