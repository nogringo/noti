import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:get/get.dart';
import 'package:ndk/ndk.dart';

import '../../models/notification_history.dart';
import '../../services/ndk_service.dart';

class NotificationDetailDialog extends StatefulWidget {
  final NotificationHistory notification;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailDialog> createState() =>
      _NotificationDetailDialogState();
}

class _NotificationDetailDialogState extends State<NotificationDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Metadata? _senderMetadata;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.notification.rawEvent != null ? 2 : 1,
      vsync: this,
    );
    _loadSenderMetadata();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderMetadata() async {
    final pubkey = widget.notification.fromPubkey;
    if (pubkey == null) return;

    try {
      final ndk = Get.find<NdkService>().ndk;
      final metadata = await ndk.metadata.loadMetadata(pubkey);
      if (mounted) {
        setState(() => _senderMetadata = metadata);
      }
    } catch (_) {}
  }

  String _formatJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return jsonString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final hasRawEvent = notification.rawEvent != null;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tabs
            if (hasRawEvent)
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Content'),
                  Tab(text: 'Raw Event'),
                ],
              ),
            // Content
            Flexible(
              child: hasRawEvent
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildContentTab(context),
                        _buildRawEventTab(context),
                      ],
                    )
                  : _buildContentTab(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab(BuildContext context) {
    final notification = widget.notification;
    final content = notification.fullContent ?? notification.body;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.fromPubkey != null) ...[
            Text(
              'From',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final npub = Nip19.encodePubKey(notification.fromPubkey!);
                final fallbackLetters = npub.substring(npub.length - 2).toUpperCase();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _senderMetadata?.picture != null
                          ? NetworkImage(_senderMetadata!.picture!)
                          : null,
                      child: _senderMetadata?.picture == null
                          ? Text(
                              fallbackLetters,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _senderMetadata?.displayName ??
                            _senderMetadata?.name ??
                            npub,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Message',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Received',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDateTime(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRawEventTab(BuildContext context) {
    final rawEvent = widget.notification.rawEvent;
    if (rawEvent == null) return const SizedBox.shrink();

    final formattedJson = _formatJson(rawEvent);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HighlightView(
              formattedJson,
              language: 'json',
              theme: Theme.of(context).brightness == Brightness.dark
                  ? a11yDarkTheme
                  : a11yLightTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formattedJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
