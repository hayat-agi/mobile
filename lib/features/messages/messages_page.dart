import 'package:flutter/material.dart';
import '../ble/ble_service.dart';

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
    // Remove common prefixes that ESP32 might send
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Mesajlar'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: _bleService.messages,
        builder: (context, messages, _) {
          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'Henüz mesaj yok',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isFromMe = msg.startsWith('ME: ');
              final displayMsg = isFromMe
                  ? msg.substring(4) // Remove "ME: "
                  : _cleanEsp32Message(msg.startsWith('ESP32: ') 
                      ? msg.substring(7) 
                      : msg); // Remove "ESP32: " and clean

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Align(
                  alignment: isFromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isFromMe
                          ? Colors.blue
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      displayMsg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

