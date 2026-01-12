import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../widgets/widgets.dart';
import 'add_account_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getAccountDisplayName(NotifyAccount account) {
    return account.name ?? 'Nostr Account';
  }

  @override
  Widget build(BuildContext context) {
    final accountsController = Get.find<AccountsController>();
    final settingsController = Get.find<SettingsController>();
    final historyController = Get.find<NotificationHistoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nostr Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.minimize),
            tooltip: 'Minimize to tray',
            onPressed: () {
              // TODO: Implement minimize to tray
            },
          ),
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
                        'Accounts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Add account',
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
                            const Text('No accounts'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddAccountDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add account'),
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
                        return Obx(() => AccountTile(
                              account: account,
                              isSelected: accountsController.selectedAccount.value?.id == account.id,
                              onTap: () => accountsController.selectAccount(account),
                              onToggleActive: () => accountsController.toggleAccountActive(account.id),
                              onDelete: () => _confirmDeleteAccount(context, account),
                            ));
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
                    Obx(() => Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('History'),
                              if (historyController.unreadCount.value > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${historyController.unreadCount.value}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                    const Tab(text: 'Settings'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // History tab
                      _buildHistoryPanel(context, historyController),
                      // Settings tab
                      Obx(() {
                        final account = accountsController.selectedAccount.value;
                        final settings = settingsController.settings.value;

                        if (account == null || settings == null) {
                          return const Center(
                            child: Text('Select an account to configure notifications'),
                          );
                        }

                        return _buildSettingsPanel(context, account, settings, settingsController);
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
  }

  Widget _buildHistoryPanel(BuildContext context, NotificationHistoryController controller) {
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
                label: const Text('Mark all read'),
              ),
              TextButton.icon(
                onPressed: () => _confirmClearHistory(context, controller),
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Clear'),
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
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No notifications yet'),
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
                  onTap: () => controller.markAsRead(notification.id),
                  onDismiss: () => controller.deleteNotification(notification.id),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context, NotificationHistoryController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will delete all notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.clearAll();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(
    BuildContext context,
    NotifyAccount account,
    NotificationSettings settings,
    SettingsController controller,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: account.picture != null ? NetworkImage(account.picture!) : null,
              child: account.picture == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Text(
              _getAccountDisplayName(account),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              NotificationToggle(
                title: 'Direct Messages',
                subtitle: 'NIP-04 and NIP-44 encrypted DMs',
                icon: Icons.mail,
                value: settings.dm,
                onChanged: (_) => controller.toggleDm(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: 'Mentions',
                subtitle: 'When someone mentions you in a note',
                icon: Icons.alternate_email,
                value: settings.mention,
                onChanged: (_) => controller.toggleMention(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: 'Zaps',
                subtitle: 'Lightning payments received',
                icon: Icons.bolt,
                value: settings.zap,
                onChanged: (_) => controller.toggleZap(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: 'Reposts',
                subtitle: 'When someone reposts your notes',
                icon: Icons.repeat,
                value: settings.repost,
                onChanged: (_) => controller.toggleRepost(),
              ),
              const Divider(height: 1),
              NotificationToggle(
                title: 'Reactions',
                subtitle: 'Likes and other reactions',
                icon: Icons.favorite,
                value: settings.reaction,
                onChanged: (_) => controller.toggleReaction(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Relays',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ...account.relays.map((relay) => ListTile(
                    leading: const Icon(Icons.dns),
                    title: Text(relay),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final newRelays = List<String>.from(account.relays)..remove(relay);
                        Get.find<AccountsController>().updateAccountRelays(account.id, newRelays);
                      },
                    ),
                  )),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add relay'),
                onTap: () => _showAddRelayDialog(context, account),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAccountDialog(),
    );
  }

  void _confirmDeleteAccount(BuildContext context, NotifyAccount account) {
    final displayName = _getAccountDisplayName(account);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove $displayName from notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.find<AccountsController>().removeAccount(account.id);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRelayDialog(BuildContext context, NotifyAccount account) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add relay'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Relay URL',
            hintText: 'wss://relay.example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newRelays = [...account.relays, controller.text];
                Get.find<AccountsController>().updateAccountRelays(account.id, newRelays);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
