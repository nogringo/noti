import 'package:flutter/material.dart';
import 'package:ndk/ndk.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? displayName;
  final String? picture;

  const AccountTile({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    this.displayName,
    this.picture,
  });

  String _shortenPubkey(String pubkey) {
    if (pubkey.length > 12) {
      return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
    }
    return pubkey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: picture != null ? NetworkImage(picture!) : null,
          child: picture == null ? const Icon(Icons.person) : null,
        ),
        title: Text(displayName ?? _shortenPubkey(account.pubkey)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
