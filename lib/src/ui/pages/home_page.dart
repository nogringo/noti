import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../widgets/widgets.dart';
import 'add_account_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final accountsController = Get.find<AccountsController>();
    final settingsController = Get.find<SettingsController>();

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
          // Right panel - Settings
          Expanded(
            child: Obx(() {
              final account = accountsController.selectedAccount.value;
              final settings = settingsController.settings.value;

              if (account == null || settings == null) {
                return const Center(
                  child: Text('Select an account to configure notifications'),
                );
              }

              return _buildSettingsPanel(context, account, settings, settingsController);
            }),
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
        Text(
          'Notifications for ${account.name ?? account.pubkey.substring(0, 16)}...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove ${account.name ?? account.pubkey.substring(0, 16)}... from notifications?'),
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
