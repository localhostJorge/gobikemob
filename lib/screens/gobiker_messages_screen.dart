import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:intl/intl.dart';

import '../core/gobiker_messages.dart';
import '../widgets/app_toast.dart';
import 'patient/app_colors.dart';

/// The GoBiker's conversation with the Go Bike admin: their messages and the
/// admin's replies, oldest first, with a send bar at the bottom.
class GobikerMessagesScreen extends StatefulWidget {
  const GobikerMessagesScreen({super.key});

  @override
  State<GobikerMessagesScreen> createState() => _GobikerMessagesScreenState();
}

class _GobikerMessagesScreenState extends State<GobikerMessagesScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  static const int _maxChars = 300;

  @override
  void initState() {
    super.initState();
    GobikerMessages.instance.refresh();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      AppToast.show(context, 'Please type a message first.',
          type: ToastType.error);
      return;
    }
    setState(() => _sending = true);

    final error = await GobikerMessages.instance.send(text);

    if (!mounted) return;
    setState(() {
      _sending = false;
      _ctrl.clear();
    });

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
      return;
    }

    // Show the message that just arrived at the bottom of the thread.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = context.pal;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Messages'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: GobikerMessages.instance,
                builder: (context, _) {
                  final conversation = GobikerMessages.instance.conversation;

                  if (GobikerMessages.instance.loading &&
                      conversation.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (conversation.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Send the admin a report or question below. '
                              'Their reply will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: pal.muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: conversation.length,
                    itemBuilder: (context, index) => _ThreadEntry(
                      message: conversation[index],
                    ),
                  );
                },
              ),
            ),
            _SendBar(
              controller: _ctrl,
              sending: _sending,
              maxChars: _maxChars,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// One exchange in the thread: the GoBiker's message, and the admin's reply
/// under it when there is one.
class _ThreadEntry extends StatelessWidget {
  const _ThreadEntry({required this.message});

  final GobikerMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = context.pal;
    final sent = DateFormat('MMM d · h:mm a').format(message.sentAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The GoBiker's message: right-aligned, brand blue.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: Radius.circular(message.hasReply ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sent,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // The admin's reply: left-aligned, card-colored with a brand edge.
          if (message.hasReply) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: pal.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            message.repliedBy ?? 'Go Bike Admin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: pal.brand,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.reply!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: pal.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (message.repliedAt != null)
                      Text(
                        DateFormat('MMM d · h:mm a').format(message.repliedAt!),
                        style: TextStyle(fontSize: 10, color: pal.muted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar at the bottom of the thread: a message field and a send button.
class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.controller,
    required this.sending,
    required this.maxChars,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final int maxChars;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.pal.card,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: maxChars,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 14, color: pal.ink),
                  decoration: InputDecoration(
                    hintText: 'Message the admin…',
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: context.pal.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: pal.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.blue),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: ElevatedButton(
                onPressed: sending ? null : onSend,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.blue.withValues(
                    alpha: 0.6,
                  ),
                ),
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
