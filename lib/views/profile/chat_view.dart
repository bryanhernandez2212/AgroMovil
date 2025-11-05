import 'package:flutter/material.dart';
import 'package:agromarket/views/profile/chat_conversation_view.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: Implementar carga de chats desde Firestore
    // Por ahora, mostramos datos de ejemplo
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _chats = [
        {
          'id': '1',
          'userId': 'user1',
          'userName': 'Juan Pérez',
          'userImage': null,
          'lastMessage': 'Gracias por la compra, ¿todo bien con el producto?',
          'unreadCount': 2,
          'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
          'isOnline': true,
        },
        {
          'id': '2',
          'userId': 'user2',
          'userName': 'María González',
          'userImage': null,
          'lastMessage': 'El producto llegó en perfecto estado, muchas gracias',
          'unreadCount': 0,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'isOnline': false,
        },
        {
          'id': '3',
          'userId': 'user3',
          'userName': 'Carlos Ramírez',
          'userImage': null,
          'lastMessage': '¿Tienes disponibilidad para mañana?',
          'unreadCount': 1,
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
          'isOnline': true,
        },
        {
          'id': '4',
          'userId': 'user4',
          'userName': 'Ana Martínez',
          'userImage': null,
          'lastMessage': 'Perfecto, gracias por todo',
          'unreadCount': 0,
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
          'isOnline': false,
        },
      ];
      _isLoading = false;
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }

  void _openChat(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationView(
          chatId: chat['id'] as String,
          userName: chat['userName'] as String,
          userImage: chat['userImage'] as String?,
          isOnline: chat['isOnline'] as bool,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1A1A1A)),
            onPressed: () {
              // TODO: Implementar búsqueda de chats
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF115213)),
              ),
            )
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay conversaciones',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tus conversaciones aparecerán aquí',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  color: const Color(0xFF115213),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      final userName = chat['userName'] as String;
                      final lastMessage = chat['lastMessage'] as String;
                      final timestamp = chat['timestamp'] as DateTime;
                      final unreadCount = chat['unreadCount'] as int;
                      final isOnline = chat['isOnline'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[200]!,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openChat(chat),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF115213).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: const Color(0xFF115213),
                                        size: 28,
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                                color: const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(timestamp),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (unreadCount > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF115213),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

