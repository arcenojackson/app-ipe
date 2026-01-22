import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import 'quoted_message_preview.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.isAdmin,
    this.onDelete,
    this.onQuote,
    this.isHighlighted = false,
  });

  final ChatMessageModel message;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback? onDelete;
  final VoidCallback? onQuote;
  final bool isHighlighted;

  bool get isOwnMessage => message.userId == currentUserId;
  bool get canDelete => isOwnMessage || isAdmin;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedMessage(context);
    }

    return GestureDetector(
      onLongPress: canDelete || onQuote != null ? () => _showOptions(context) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment:
              isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwnMessage) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  message.userName.isNotEmpty
                      ? message.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isOwnMessage
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                    bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                  ),
                  border: isHighlighted
                      ? Border.all(
                          color: Colors.amber,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isOwnMessage) ...[
                      Text(
                        message.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isOwnMessage
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.quotedMessage != null) ...[
                      const SizedBox(height: 4),
                      QuotedMessagePreview(
                        quotedMessage: message.quotedMessage!,
                      ),
                    ],
                    _buildMessageText(context),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isOwnMessage) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  message.userName.isNotEmpty
                      ? message.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(BuildContext context) {
    final text = message.text;
    final parts = <InlineSpan>[];
    int lastIndex = 0;

    // Regex para encontrar menções @usuário
    final mentionRegex = RegExp(r'@(\w+)', caseSensitive: false);

    for (final match in mentionRegex.allMatches(text)) {
      // Adicionar texto antes da menção
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            color: isOwnMessage ? Colors.white : Colors.white,
          ),
        ));
      }

      // Adicionar menção destacada
      parts.add(TextSpan(
        text: match.group(0), // @usuário
        style: TextStyle(
          color: isOwnMessage ? Colors.amber.shade200 : Colors.amber,
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = match.end;
    }

    // Adicionar texto restante
    if (lastIndex < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: isOwnMessage ? Colors.white : Colors.white,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        children: parts.isEmpty
            ? [
                TextSpan(
                  text: text,
                  style: TextStyle(
                    color: isOwnMessage ? Colors.white : Colors.white,
                  ),
                )
              ]
            : parts,
      ),
    );
  }

  Widget _buildDeletedMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '[Mensagem deletada]',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == yesterday) {
      return 'Ontem ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('dd/MM HH:mm').format(timestamp);
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onQuote != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Citar'),
                onTap: () {
                  Navigator.pop(context);
                  onQuote?.call();
                },
              ),
            if (canDelete && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Deletar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
