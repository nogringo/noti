import 'package:flutter/material.dart';

import '../../models/account.dart';

class AccountTile extends StatelessWidget {
  final NotifyAccount account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const AccountTile({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shortPubkey = account.pubkey.length > 16
        ? '${account.pubkey.substring(0, 8)}...${account.pubkey.substring(account.pubkey.length - 8)}'
        : account.pubkey;

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: account.picture != null ? NetworkImage(account.picture!) : null,
          child: account.picture == null ? const Icon(Icons.person) : null,
        ),
        title: Text(account.name ?? shortPubkey),
        subtitle: account.name != null ? Text(shortPubkey) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: account.active,
              onChanged: (_) => onToggleActive(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
