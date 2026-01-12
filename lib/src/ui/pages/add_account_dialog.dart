import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_widgets/nostr_widgets.dart';

import '../../controllers/controllers.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  late Ndk _ndk;

  @override
  void initState() {
    super.initState();
    _ndk = Ndk(NdkConfig(
      eventVerifier: Bip340EventVerifier(),
      cache: MemCacheManager(),
    ));
  }

  Future<void> _onLoggedIn() async {
    final ndkAccount = _ndk.accounts.getLoggedAccount();
    if (ndkAccount == null) return;

    final accountsController = Get.find<AccountsController>();
    final dbService = Get.find<DatabaseService>();

    // Check if account already exists
    final existingAccounts = accountsController.accounts;
    if (existingAccounts.any((a) => a.pubkey == ndkAccount.pubkey)) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Fetch user metadata (name, picture)
    String? name;
    String? picture;
    try {
      final metadata = await _ndk.metadata.loadMetadata(ndkAccount.pubkey);
      if (metadata != null) {
        name = metadata.displayName ?? metadata.name;
        picture = metadata.picture;
      }
    } catch (_) {
      // Continue without metadata if fetch fails
    }

    // Fetch user relays from NIP-65
    List<String> relays = [];
    try {
      final userRelayList = await _ndk.userRelayLists.getSingleUserRelayList(ndkAccount.pubkey);
      if (userRelayList != null && userRelayList.urls.isNotEmpty) {
        relays = userRelayList.urls.toList();
      }
    } catch (_) {
      // Continue with default relays if fetch fails
    }

    // Fallback to default relays if none found
    if (relays.isEmpty) {
      relays = [
        'wss://relay.damus.io',
        'wss://relay.nostr.band',
        'wss://nos.lol',
      ];
    }

    // Generate unique ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final account = NotifyAccount(
      id: id,
      pubkey: ndkAccount.pubkey,
      bunkerUrl: '',
      relays: relays,
      active: true,
      name: name,
      picture: picture,
    );

    // Create default notification settings
    final settings = NotificationSettings(accountId: id);

    // Save to database
    await dbService.saveAccount(account);
    await dbService.saveNotificationSettings(settings);

    // Update controller state
    accountsController.accounts.add(account);
    accountsController.selectedAccount.value = account;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Nostr Account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: NLogin(
                    ndk: _ndk,
                    onLoggedIn: _onLoggedIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
