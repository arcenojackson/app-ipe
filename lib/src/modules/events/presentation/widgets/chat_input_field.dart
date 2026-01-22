import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import '../../../auth/models/user.dart';
import '../../../../shared/utils/platform_utils.dart';
import 'quoted_message_preview.dart';

class ChatInputField extends StatefulWidget {
  const ChatInputField({
    super.key,
    required this.onSend,
    required this.availableUsers,
    this.quotedMessage,
    this.onCancelQuote,
  });

  final Function(String text, List<String> mentionedUserIds) onSend;
  final List<UserModel> availableUsers;
  final QuotedMessage? quotedMessage;
  final VoidCallback? onCancelQuote;

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showMentionList = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final cursorPosition = _controller.selection.baseOffset;
    if (cursorPosition == -1) {
      setState(() => _showMentionList = false);
      return;
    }

    // Verificar se o usuário está digitando uma menção
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      // Verificar se não há espaço entre @ e cursor
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ')) {
        setState(() {
          _mentionStartIndex = lastAtIndex;
          _mentionQuery = textAfterAt.toLowerCase();
          _showMentionList = true;
        });
        return;
      }
    }

    setState(() => _showMentionList = false);
  }

  void _insertMention(UserModel user) {
    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;

    // Substituir @query pelo @nomeUsuario
    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterCursor = text.substring(cursorPosition);
    final newText = '$beforeMention@${user.name} $afterCursor';

    _controller.value = TextEditingValue(
      text: newText,
                      selection: TextSelection.collapsed(
                        offset: _mentionStartIndex + user.name.length + 2, // @nome + espaço
                      ),
    );

    setState(() {
      _showMentionList = false;
      _mentionQuery = '';
    });
  }

  void _insertTodosMention() {
    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;

    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterCursor = text.substring(cursorPosition);
    final newText = '$beforeMention@todos $afterCursor';

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _mentionStartIndex + 7, // @todos + espaço
      ),
    );

    setState(() {
      _showMentionList = false;
      _mentionQuery = '';
    });
  }

  // Normaliza string removendo acentos para comparação
  String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Extrair menções do texto
    final mentionedIds = <String>[];
    final todosRegex = RegExp(r'@todos\b', caseSensitive: false);
    
    if (todosRegex.hasMatch(text)) {
      mentionedIds.addAll(widget.availableUsers.map((u) => u.id));
    } else {
      // Regex melhorado que captura até encontrar espaço ou fim da string
      // Aceita caracteres acentuados, letras, números e underscore
      final mentionRegex = RegExp(r'@([^\s@]+)', caseSensitive: false);
      final matches = mentionRegex.allMatches(text);
      
      for (final match in matches) {
        final mentionedNameRaw = match.group(1) ?? '';
        final mentionedNameNormalized = _normalize(mentionedNameRaw);
        
        // Tentar encontrar usuário que corresponde
        UserModel? matchedUser;
        
        for (final user in widget.availableUsers) {
          final userNameNormalized = _normalize(user.name);
          
          // Comparar se o nome mencionado está no início do nome do usuário
          // ou se o nome completo do usuário está no texto mencionado
          if (userNameNormalized == mentionedNameNormalized ||
              userNameNormalized.startsWith(mentionedNameNormalized) ||
              mentionedNameNormalized == _normalize(user.name.split(' ').first)) {
            matchedUser = user;
            break;
          }
        }
        
        if (matchedUser != null && matchedUser.id.isNotEmpty && !mentionedIds.contains(matchedUser.id)) {
          mentionedIds.add(matchedUser.id);
        }
      }
    }

    widget.onSend(text, mentionedIds);
    _controller.clear();
    if (widget.onCancelQuote != null) {
      widget.onCancelQuote!();
    }
  }

  List<UserModel> get _filteredUsers {
    if (_mentionQuery.isEmpty) {
      return widget.availableUsers;
    }
    return widget.availableUsers.where((user) {
      return user.name.toLowerCase().contains(_mentionQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    // Padding específico por plataforma
    double bottomPadding;
    if (PlatformUtils.isAndroid) {
      final androidBottomPadding = PlatformUtils.getModalBottomPadding(context);
      bottomPadding = keyboardHeight + androidBottomPadding;
    } else {
      // iOS: safe area + padding extra mínimo quando teclado não está aberto
      final iosSafeArea = mediaQuery.padding.bottom;
      final iosExtraPadding = keyboardHeight == 0 ? 16.0 : 0.0; // Padding extra quando teclado fechado
      bottomPadding = keyboardHeight + iosSafeArea + iosExtraPadding;
    }
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.quotedMessage != null)
            QuotedMessagePreview(
              quotedMessage: widget.quotedMessage!,
              onCancel: widget.onCancelQuote,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_showMentionList) _buildMentionList(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onTextChanged,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Digite uma mensagem...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.7),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionList() {
    final users = _filteredUsers;
    final showTodos = 'todos'.contains(_mentionQuery);

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (showTodos)
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('@todos'),
              subtitle: const Text('Mencionar todos'),
              onTap: _insertTodosMention,
            ),
          ...users.take(10).map((user) => ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(user.name),
                onTap: () => _insertMention(user),
              )),
        ],
      ),
    );
  }
}
