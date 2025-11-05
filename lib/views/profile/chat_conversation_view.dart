import 'package:flutter/material.dart';

class ChatConversationView extends StatefulWidget {
  final String chatId;
  final String userName;
  final String? userImage;
  final bool isOnline;

  const ChatConversationView({
    super.key,
    required this.chatId,
    required this.userName,
    this.userImage,
    this.isOnline = false,
  });

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: Implementar carga de mensajes desde Firestore
    // Por ahora, mostramos datos de ejemplo
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _messages = [
        {
          'id': '1',
          'text': 'Hola, tengo una pregunta sobre el producto',
          'senderId': 'other',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'isRead': true,
        },
        {
          'id': '2',
          'text': '¡Hola! Claro, ¿en qué te puedo ayudar?',
          'senderId': 'me',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2, minutes: 1)),
          'isRead': true,
        },
        {
          'id': '3',
          'text': '¿El producto está disponible para entrega inmediata?',
          'senderId': 'other',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
          'isRead': true,
        },
        {
          'id': '4',
          'text': 'Sí, tenemos stock disponible. ¿Cuántas unidades necesitas?',
          'senderId': 'me',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 25)),
          'isRead': true,
        },
        {
          'id': '5',
          'text': 'Necesito 5 unidades',
          'senderId': 'other',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
          'isRead': true,
        },
        {
          'id': '6',
          'text': 'Perfecto, puedo preparar tu pedido. ¿Dónde realizo la entrega?',
          'senderId': 'me',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 25)),
          'isRead': true,
        },
        {
          'id': '7',
          'text': 'Gracias por la compra, ¿todo bien con el producto?',
          'senderId': 'other',
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
          'isRead': false,
        },
      ];
      _isLoading = false;
    });

    // Scroll al final después de cargar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Agregar mensaje localmente
    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'senderId': 'me',
      'timestamp': DateTime.now(),
      'isRead': false,
    };

    setState(() {
      _messages.add(newMessage);
    });

    _messageController.clear();

    // Scroll al final
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // TODO: Enviar mensaje a Firestore
    // await ChatService.sendMessage(widget.chatId, text);
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else {
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      final year = timestamp.year.toString();
      return '$day/$month/$year';
    }
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;

    final currentDate = _messages[index]['timestamp'] as DateTime;
    final previousDate = _messages[index - 1]['timestamp'] as DateTime;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF115213).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF115213),
                    size: 20,
                  ),
                ),
                if (widget.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    widget.isOnline ? 'En línea' : 'Desconectado',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay mensajes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Envía un mensaje para comenzar la conversación',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['senderId'] == 'me';
                          final text = message['text'] as String;
                          final timestamp = message['timestamp'] as DateTime;
                          final isRead = message['isRead'] as bool;

                          return Column(
                            children: [
                              if (_shouldShowDateSeparator(index))
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 16),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              Row(
                                mainAxisAlignment:
                                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF115213).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Color(0xFF115213),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF115213)
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                                          bottomRight: Radius.circular(isMe ? 4 : 20),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(timestamp),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  isRead ? Icons.done_all : Icons.done,
                                                  size: 14,
                                                  color: isRead
                                                      ? Colors.blue[300]
                                                      : Colors.white70,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) const SizedBox(width: 8),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
          ),

          // Campo de texto y botón de enviar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF115213),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

