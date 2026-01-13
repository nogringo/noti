import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';
import 'package:nostr_widgets/nostr_widgets.dart';

import '../../controllers/controllers.dart';
import '../../services/services.dart';

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final NdkService _ndkService = Get.find();

  Ndk get _ndk => _ndkService.ndk;

  Future<void> _onLoggedIn() async {
    // Save NDK account state (preserves signer for AUTH)
    await _ndkService.saveAccountState();

    // Reload accounts from NDK
    final accountsController = Get.find<AccountsController>();
    await accountsController.loadAccounts();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                  child: NLogin(ndk: _ndk, onLoggedIn: _onLoggedIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
