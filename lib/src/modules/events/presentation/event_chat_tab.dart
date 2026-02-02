import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../people/data/people_repository.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/event.dart';
import '../../../core/config/firebase_config.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/message_search_bar.dart';

class EventChatTab extends StatefulWidget {
  const EventChatTab({
    super.key,
    required this.eventId,
    required this.event,
    this.initialMessageId,
  });

  final String eventId;
  final EventModel event;
  final String? initialMessageId; // ID da mensagem para scrollar inicialmente

  @override
  State<EventChatTab> createState() => _EventChatTabState();
}

class _EventChatTabState extends State<EventChatTab> {
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository();

  bool _isSearching = false;
  String _searchQuery = '';
  List<ChatMessageModel> _allMessages = [];
  List<ChatMessageModel> _filteredMessages = [];
  List<UserModel> _availableUsers = [];
  ChatMessageModel? _quotedMessage;
  bool _isLoading = true;
  String? _currentUserId;
  bool _isAdmin = false;
  bool _hasScrolledToInitialMessage = false;
  bool _hasPerformedInitialScroll =
      false; // Controla se o scroll inicial foi feito
  final GlobalKey _initialMessageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseConfig.auth.currentUser?.uid;
    _loadUsers();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final allUsers = await peopleRepository.fetchAll();

      // Obter IDs de usuários do evento
      final eventUserIds = widget.event.people.allPeopleIds.toSet();

      // Filtrar apenas usuários vinculados ao evento
      setState(() {
        _availableUsers = allUsers
            .where((user) => eventUserIds.contains(user.id))
            .toList();
      });
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

  Future<void> _checkAdminStatus() async {
    if (_currentUserId == null) return;

    try {
      final userDoc = await FirebaseConfig.firestore
          .collection('users')
          .doc(_currentUserId!)
          .get();

      setState(() {
        _isAdmin =
            userDoc.data()?['is_admin'] == true ||
            userDoc.data()?['isAdmin'] == true;
      });
    } catch (e) {
      // Ignorar erro
    }
  }

  Future<void> _markMessagesAsViewed() async {
    if (_currentUserId == null) return;

    try {
      // Marcar todas as mensagens como visualizadas
      await _chatRepository.markAllMessagesAsViewed(widget.eventId);

      // Atualizar última mensagem lida quando houver mensagens não deletadas
      final nonDeletedMessages = _allMessages
          .where((m) => !m.isDeleted)
          .toList();
      if (nonDeletedMessages.isNotEmpty) {
        // Ordenar por timestamp para pegar a mais recente
        nonDeletedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        await _chatRepository.setLastReadMessageId(
          widget.eventId,
          nonDeletedMessages.first.id,
        );
      }
    } catch (e) {
      // Ignorar erro silenciosamente
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToInitialMessage(String messageId) {
    if (_hasScrolledToInitialMessage) return;

    // Aguardar um pouco para garantir que o ListView está renderizado
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || !_scrollController.hasClients) {
        _hasScrolledToInitialMessage = true;
        return;
      }

      final messageIndex = _filteredMessages.indexWhere(
        (msg) => msg.id == messageId && !msg.isDeleted,
      );

      if (messageIndex != -1) {
        // Tentar usar o GlobalKey para obter posição exata
        final RenderBox? renderBox =
            _initialMessageKey.currentContext?.findRenderObject() as RenderBox?;

        if (renderBox != null && _scrollController.hasClients) {
          try {
            // Obter a posição do widget no ScrollView
            final position = renderBox.localToGlobal(Offset.zero);
            final scrollViewBox = context.findRenderObject() as RenderBox?;

            if (scrollViewBox != null) {
              final scrollViewPosition = scrollViewBox.localToGlobal(
                Offset.zero,
              );
              final relativeY = position.dy - scrollViewPosition.dy;
              final currentOffset = _scrollController.offset;

              // Calcular o offset necessário para mostrar a mensagem com padding
              final targetOffset = currentOffset + relativeY - 150;

              _scrollController.animateTo(
                targetOffset.clamp(
                  0.0,
                  _scrollController.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
              );

              _hasScrolledToInitialMessage = true;
              return;
            }
          } catch (e) {
            // Se falhar, usar fallback
          }
        }

        // Fallback: usar índice estimado
        // Assumir altura média de ~100px por mensagem
        const estimatedMessageHeight = 100.0;
        final targetOffset = (messageIndex * estimatedMessageHeight) - 150;

        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );

        _hasScrolledToInitialMessage = true;
      } else {
        // Mensagem não encontrada ainda, aguardar mais um pouco
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_hasScrolledToInitialMessage) {
            // Tentar novamente ou fazer scroll para o final
            final retryIndex = _filteredMessages.indexWhere(
              (msg) => msg.id == messageId && !msg.isDeleted,
            );

            if (retryIndex != -1) {
              const estimatedMessageHeight = 100.0;
              final targetOffset = (retryIndex * estimatedMessageHeight) - 150;

              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  targetOffset.clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                );
              }
            } else {
              _scrollToBottom();
            }

            _hasScrolledToInitialMessage = true;
          }
        });
      }
    });
  }

  Future<void> _onSendMessage(
    String text,
    List<String> mentionedUserIds,
  ) async {
    if (text.trim().isEmpty) return;
    if (_currentUserId == null) return;

    try {
      await _chatRepository.sendMessage(
        widget.eventId,
        text,
        mentionedUserIds,
        quotedMessageId: _quotedMessage?.id,
      );

      // Scroll para baixo após enviar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _chatRepository.deleteMessage(widget.eventId, messageId);
      // Mensagem deletada silenciosamente - sem notificação
    } catch (e) {
      // Apenas mostrar erro se realmente houver problema
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar mensagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _quoteMessage(ChatMessageModel message) {
    setState(() {
      _quotedMessage = ChatMessageModel(
        id: message.id,
        text: message.text,
        userId: message.userId,
        userName: message.userName,
        timestamp: message.timestamp,
        quotedMessage: message.quotedMessage,
      );
    });
  }

  void _cancelQuote() {
    setState(() {
      _quotedMessage = null;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredMessages = _allMessages;
        _isSearching = false;
      } else {
        _isSearching = true;
        final queryLower = query.toLowerCase();
        _filteredMessages = _allMessages.where((msg) {
          if (msg.isDeleted) return false;
          return msg.text.toLowerCase().contains(queryLower) ||
              msg.userName.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Verificar se usuário está vinculado ao evento
    final eventUserIds = widget.event.people.allPeopleIds.toSet();
    final canAccess =
        _currentUserId != null &&
        (eventUserIds.contains(_currentUserId) || _isAdmin);

    if (!canAccess) {
      return const Center(
        child: Text(
          'Você precisa estar escalado neste evento para acessar o chat.',
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (_isSearching || _searchQuery.isNotEmpty)
            MessageSearchBar(
              onChanged: _onSearchChanged,
              hintText: 'Buscar mensagens...',
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatRepository.listenMessages(widget.eventId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _isLoading) {
                  _isLoading = false;
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar mensagens: ${snapshot.error}',
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                _allMessages = messages;

                if (_isSearching && _searchQuery.isNotEmpty) {
                  // Já foi filtrado em _onSearchChanged
                } else {
                  _filteredMessages = messages;
                }

                // Marcar mensagens como visualizadas quando o usuário visualiza o chat
                // Usar um debounce para evitar muitas chamadas
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!_isSearching && messages.isNotEmpty) {
                    // Aguardar um pouco para garantir que o scroll foi feito
                    await Future.delayed(const Duration(milliseconds: 1000));
                    if (mounted && !_isSearching) {
                      await _markMessagesAsViewed();
                    }
                  }
                });

                if (_filteredMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Nenhuma mensagem encontrada'
                              : 'Nenhuma mensagem ainda.\nSeja o primeiro a enviar!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll para mensagem inicial se especificada, senão para o final
                // IMPORTANTE: Só faz scroll automático uma vez na abertura do chat
                // para evitar forçar o scroll quando o usuário está navegando manualmente
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_isSearching && !_hasPerformedInitialScroll) {
                    if (widget.initialMessageId != null &&
                        messages.isNotEmpty) {
                      _scrollToInitialMessage(widget.initialMessageId!);
                    } else {
                      _scrollToBottom();
                    }
                    _hasPerformedInitialScroll = true;
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = _filteredMessages[index];
                    final isHighlighted =
                        _searchQuery.isNotEmpty &&
                        message.text.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );

                    // Destacar mensagem inicial se especificada
                    final isInitialMessage =
                        widget.initialMessageId != null &&
                        message.id == widget.initialMessageId &&
                        !_hasScrolledToInitialMessage;

                    return ChatMessageBubble(
                      key: isInitialMessage ? _initialMessageKey : null,
                      message: message,
                      currentUserId: _currentUserId ?? '',
                      isAdmin: _isAdmin,
                      isHighlighted: isHighlighted || isInitialMessage,
                      onDelete: () => _deleteMessage(message.id),
                      onQuote: () => _quoteMessage(message),
                      availableUsers: _availableUsers,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputField(
            onSend: _onSendMessage,
            availableUsers: _availableUsers,
            quotedMessage: _quotedMessage != null
                ? QuotedMessage(
                    messageId: _quotedMessage!.id,
                    text: _quotedMessage!.text,
                    userName: _quotedMessage!.userName,
                  )
                : null,
            onCancelQuote: _cancelQuote,
          ),
        ],
      ),
      floatingActionButton: _isSearching || _searchQuery.isEmpty
          ? null
          : FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              child: const Icon(Icons.search),
            ),
    );
  }
}
