import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final BleService _bleService = BleService();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _bleService.messages.addListener(_onMessagesChanged);
  }

  @override
  void dispose() {
    _bleService.messages.removeListener(_onMessagesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (_bleService.messages.value.length != _lastMessageCount) {
      _lastMessageCount = _bleService.messages.value.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _cleanEsp32Message(String msg) {
    if (msg.startsWith('RX: ')) {
      return msg.substring(4);
    }
    if (msg.startsWith('OK: ')) {
      return msg.substring(4);
    }
    if (msg.startsWith('TX: ')) {
      return msg.substring(4);
    }
    return msg;
  }

  String _getMessageType(String msg) {
    if (msg.toLowerCase().contains('sos') || msg.toLowerCase().contains('yaral')) {
      return 'SOS';
    }
    if (msg.toLowerCase().contains('güven') || msg.toLowerCase().contains('yardım')) {
      return 'Durum';
    }
    return 'Normal';
  }

  Color _getMessageTypeColor(String type) {
    switch (type) {
      case 'SOS':
        return AppColors.danger;
      case 'Durum':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Mesajlar'),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // TODO: Add filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Filtreleme yakında eklenecek'),
                ),
              );
            },
            tooltip: 'Filtrele',
          ),
        ],
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: _bleService.messages,
        builder: (context, messages, _) {
          if (messages.isEmpty) {
            return EmptyState(
              icon: Icons.message_outlined,
              title: 'Henüz mesaj yok',
              description: 'Gönderilen ve alınan mesajlar burada görünecek',
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isFromMe = msg.startsWith('ME: ');
              final displayMsg = isFromMe
                  ? msg.substring(4)
                  : _cleanEsp32Message(
                      msg.startsWith('ESP32: ') ? msg.substring(7) : msg,
                    );
              final messageType = _getMessageType(displayMsg);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment:
                      isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isFromMe) ...[
                      // Message type pill for received messages
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getMessageTypeColor(messageType).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          messageType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getMessageTypeColor(messageType),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isFromMe
                              ? AppColors.primary
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isFromMe ? 16 : 4),
                            bottomRight: Radius.circular(isFromMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayMsg,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // TODO: Add timestamp
                                Text(
                                  'Az önce', // Placeholder
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                if (isFromMe) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
