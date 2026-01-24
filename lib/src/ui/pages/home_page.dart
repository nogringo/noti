import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:window_manager/window_manager.dart';

import '../../../l10n/app_localizations.dart';
import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../utils/nostr_utils.dart';
import '../widgets/widgets.dart';
import 'add_account_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WindowListener {
  late TabController _tabController;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!kIsWeb) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((value) {
        setState(() => _isMaximized = value);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (!kIsWeb) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accountsController = Get.find<AccountsController>();
    final settingsController = Get.find<SettingsController>();
    final historyController = Get.find<NotificationHistoryController>();

    final scaffold = Scaffold(
      appBar: AppBar(
        title: kIsWeb
            ? Text(l.appTitle)
            : DragToMoveArea(child: Text(l.appTitle)),
        flexibleSpace: kIsWeb
            ? null
            : const DragToMoveArea(child: SizedBox.expand()),
        actions: [
          if (!kIsWeb) ...[
            WindowCaptionButton.minimize(
              brightness: Theme.of(context).brightness,
              onPressed: windowManager.minimize,
            ),
            if (_isMaximized)
              WindowCaptionButton.unmaximize(
                brightness: Theme.of(context).brightness,
                onPressed: windowManager.unmaximize,
              )
            else
              WindowCaptionButton.maximize(
                brightness: Theme.of(context).brightness,
                onPressed: windowManager.maximize,
              ),
            WindowCaptionButton.close(
              brightness: Theme.of(context).brightness,
              onPressed: () => windowManager.hide(),
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          // Left panel - Accounts
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.accounts,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: l.addAccount,
                        onPressed: () => _showAddAccountDialog(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    if (accountsController.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (accountsController.accounts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(l.noAccounts),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddAccountDialog(context),
                              icon: const Icon(Icons.add),
                              label: Text(l.addAccount),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: accountsController.accounts.length,
                      itemBuilder: (context, index) {
                        final account = accountsController.accounts[index];
                        return Obx(
                          () => AccountTile(
                            account: account,
                            isSelected:
                                accountsController
                                    .selectedAccount
                                    .value
                                    ?.pubkey ==
                                account.pubkey,
                            onTap: () =>
                                accountsController.selectAccount(account),
                            onDelete: () =>
                                _confirmDeleteAccount(context, account),
                            displayName: accountsController.getAccountName(
                              account.pubkey,
                            ),
                            picture: accountsController.getAccountPicture(
                              account.pubkey,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel - Tabs (History / Settings)
          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Obx(
                      () => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.history),
                            if (historyController.unreadCount.value > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${historyController.unreadCount.value}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Tab(text: l.settings),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // History tab
                      _buildHistoryPanel(context, l, historyController),
                      // Settings tab
                      Obx(() {
                        final account =
                            accountsController.selectedAccount.value;
                        final settings = settingsController.settings.value;

                        if (account == null || settings == null) {
                          return Center(child: Text(l.selectAccountToConfig));
                        }

                        return _buildSettingsPanel(
                          context,
                          l,
                          account,
                          settings,
                          settingsController,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (kIsWeb) {
      return scaffold;
    }
    return DragToResizeArea(child: scaffold);
  }

  Widget _buildHistoryPanel(
    BuildContext context,
    AppLocalizations l,
    NotificationHistoryController controller,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => controller.markAllAsRead(),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(l.markAllRead),
              ),
              TextButton.icon(
                onPressed: () => _confirmClearHistory(context, l, controller),
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: Text(l.clear),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_off,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(l.noNotificationsYet),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: controller.notifications.length,
              itemBuilder: (context, index) {
                final notification = controller.notifications[index];
                return NotificationTile(
                  notification: notification,
                  onTap: () {
                    controller.markAsRead(notification.id);
                    showDialog(
                      context: context,
                      builder: (context) =>
                          NotificationDetailDialog(notification: notification),
                    );
                  },
                  onDismiss: () =>
                      controller.deleteNotification(notification.id),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _confirmClearHistory(
    BuildContext context,
    AppLocalizations l,
    NotificationHistoryController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.clearHistoryTitle),
        content: Text(l.clearHistoryContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              controller.clearAll();
              Navigator.of(context).pop();
            },
            child: Text(l.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(
    BuildContext context,
    AppLocalizations l,
    Account account,
    NotificationSettings settings,
    SettingsController controller,
  ) {
    final accountsController = Get.find<AccountsController>();
    final appSettingsController = Get.find<AppSettingsController>();
    final name = accountsController.getAccountName(account.pubkey);
    final picture = accountsController.getAccountPicture(account.pubkey);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: picture != null ? NetworkImage(picture) : null,
              child: picture == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Text(
              name ?? shortenNpub(account.pubkey),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l.notifications, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              NotificationToggle(
                title: l.directMessages,
                subtitle: l.directMessagesDesc,
                icon: Icons.mail,
                value: settings.dm,
                onChanged: (_) => controller.toggleDm(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: l.mentions,
                subtitle: l.mentionsDesc,
                icon: Icons.alternate_email,
                value: settings.mention,
                onChanged: (_) => controller.toggleMention(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: l.zaps,
                subtitle: l.zapsDesc,
                icon: Icons.bolt,
                value: settings.zap,
                onChanged: (_) => controller.toggleZap(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: l.reposts,
                subtitle: l.repostsDesc,
                icon: Icons.repeat,
                value: settings.repost,
                onChanged: (_) => controller.toggleRepost(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: l.reactions,
                subtitle: l.reactionsDesc,
                icon: Icons.favorite,
                value: settings.reaction,
                onChanged: (_) => controller.toggleReaction(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Relays', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Obx(() {
          if (controller.isLoadingRelays.value) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'NIP-65 (${controller.nip65Relays.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (controller.nip65Relays.isEmpty)
                    Text(
                      'No relays found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    ...controller.nip65Relays.map(
                      (relay) => Padding(
                        padding: const EdgeInsets.only(left: 26, bottom: 4),
                        child: Text(
                          relay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.mail, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'DM Relays (${controller.dmRelays.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (controller.dmRelays.isEmpty)
                    Text(
                      'No DM relays found (kind 10050)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else
                    ...controller.dmRelays.map(
                      (relay) => Padding(
                        padding: const EdgeInsets.only(left: 26, bottom: 4),
                        child: Text(
                          relay,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        if (!kIsWeb) ...[
          const SizedBox(height: 24),
          Text(l.application, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Obx(
            () => Card(
              child: Column(
                children: [
                  NotificationToggle(
                    title: l.launchAtStartup,
                    subtitle: l.launchAtStartupDesc,
                    icon: Icons.power_settings_new,
                    value: appSettingsController.settings.value.launchAtStartup,
                    onChanged: (_) =>
                        appSettingsController.toggleLaunchAtStartup(),
                  ),
                  const Divider(height: 1),
                  NotificationToggle(
                    title: l.startMinimized,
                    subtitle: l.startMinimizedDesc,
                    icon: Icons.visibility_off,
                    value: appSettingsController.settings.value.startMinimized,
                    onChanged: (_) =>
                        appSettingsController.toggleStartMinimized(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => exit(0),
            icon: const Icon(Icons.power_settings_new),
            label: Text(l.quitApp),
          ),
        ],
      ],
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAccountDialog(),
    );
  }

  void _confirmDeleteAccount(BuildContext context, Account account) {
    final l = AppLocalizations.of(context)!;
    final accountsController = Get.find<AccountsController>();
    final displayName =
        accountsController.getAccountName(account.pubkey) ??
        shortenNpub(account.pubkey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAccountTitle),
        content: Text(l.deleteAccountContent(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              Get.find<AccountsController>().removeAccount(account.pubkey);
              Navigator.of(context).pop();
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}
