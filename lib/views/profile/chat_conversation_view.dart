import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:agromarket/controllers/auth_controller.dart';
import 'package:agromarket/models/chat_message_model.dart';
import 'package:agromarket/services/chat_service.dart';

class ChatConversationView extends StatefulWidget {
  final String chatId;
  final String userName;
  final String otherUserId;
  final String orderId;
  final String? userImage;
  final bool isOnline;

  const ChatConversationView({
    super.key,
    required this.chatId,
    required this.userName,
    required this.otherUserId,
    required this.orderId,
    this.userImage,
    this.isOnline = false,
  });

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _presenceSubscription;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSendingImage = false;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeenAt;
  String? _currentUserId;
  String? _errorMessage;
  late final bool _hasOrderId;

  @override
  void initState() {
    super.initState();
    _isOtherUserOnline = widget.isOnline;
    _hasOrderId = widget.orderId.isNotEmpty && widget.orderId != 'legacy';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _presenceSubscription?.cancel();
    if (_currentUserId != null) {
      ChatService.updatePresence(userId: _currentUserId!, isOnline: false);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUser = authController.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Debes iniciar sesión para enviar mensajes.';
      });
      return;
    }

    _currentUserId = currentUser.id;

    try {
      if (_hasOrderId) {
        await ChatService.ensureChat(
          orderId: widget.orderId,
          currentUserId: currentUser.id,
          otherUserId: widget.otherUserId,
          currentUserName: currentUser.nombre,
          otherUserName: widget.userName,
        );
      }

      await ChatService.updatePresence(
        userId: currentUser.id,
        isOnline: true,
      );

      _listenToMessages();
      _listenToPresence();

      await ChatService.markMessagesAsRead(
        chatId: widget.chatId,
        userId: currentUser.id,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar la conversación: $e';
      });
    }
  }

  void _listenToMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription =
        ChatService.streamChatMessages(widget.chatId).listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _messages = messages;
          _isLoading = false;
          _errorMessage = null;
        });
        _scrollToBottom();
        if (_currentUserId != null) {
          ChatService.markMessagesAsRead(
            chatId: widget.chatId,
            userId: _currentUserId!,
          );
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando mensajes: ${error.toString()}';
        });
      },
    );
  }

  void _listenToPresence() {
    _presenceSubscription?.cancel();
    _presenceSubscription = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final isOnline = data['isOnline'] == true;
      final lastSeenRaw = data['lastSeenAt'];
      DateTime? lastSeen;
      if (lastSeenRaw is Timestamp) {
        lastSeen = lastSeenRaw.toDate();
      } else if (lastSeenRaw is DateTime) {
        lastSeen = lastSeenRaw;
      }

      if (!mounted) return;
      setState(() {
        _isOtherUserOnline = isOnline;
        _otherUserLastSeenAt = lastSeen;
      });
    });
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        senderId: _currentUserId!,
        text: text,
      );

      _messageController.clear();
      FocusScope.of(context).unfocus();
      await ChatService.markMessagesAsRead(
        chatId: widget.chatId,
        userId: _currentUserId!,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_currentUserId == null || _isSendingImage) return;

    final picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _isSendingImage = true;
      });

      await ChatService.sendImageMessage(
        chatId: widget.chatId,
        senderId: _currentUserId!,
        imageFile: File(pickedFile.path),
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la imagen: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingImage = false;
        });
      }
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 300,
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    final currentDate = _messages[index].createdAt;
    final previousDate = _messages[index - 1].createdAt;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  String _presenceStatusText() {
    if (_isOtherUserOnline) {
      return 'En línea';
    }
    if (_otherUserLastSeenAt != null) {
      final lastSeen = _otherUserLastSeenAt!;
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) {
        return 'Última vez hace un momento';
      }
      if (diff.inMinutes < 60) {
        return 'Última vez hace ${diff.inMinutes} min';
      }
      if (diff.inHours < 24) {
        return 'Última vez a las ${_formatTime(lastSeen)}';
      }
      return 'Última vez ${_formatDate(lastSeen)} a las ${_formatTime(lastSeen)}';
    }
    return 'Desconectado';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: widget.userImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            widget.userImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                ),
                if (_isOtherUserOnline)
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color,
                    ),
                  ),
                  Text(
                    _presenceStatusText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
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
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay mensajes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Envía un mensaje para comenzar la conversación',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
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
                              final isMe = message.senderId == _currentUserId;
                              final text = message.text ?? '';
                              final isImage = message.type == 'image' && (message.imageUrl?.isNotEmpty ?? false);
                              final timestamp = message.createdAt;
                              final isReadByOther = message.isReadBy(widget.otherUserId);

                              return Column(
                                children: [
                                  if (_shouldShowDateSeparator(index))
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDate(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    mainAxisAlignment: isMe
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe) ...[
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.75,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? Theme.of(context).colorScheme.primary
                                                : (isDark ? Theme.of(context).cardColor : Colors.white),
                                            borderRadius: BorderRadius.only(
                                              topLeft:
                                                  const Radius.circular(20),
                                              topRight:
                                                  const Radius.circular(20),
                                              bottomLeft: Radius.circular(
                                                  isMe ? 20 : 4),
                                              bottomRight: Radius.circular(
                                                  isMe ? 4 : 20),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(isDark ? 0.3 : 0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (isImage) ...[
                                                GestureDetector(
                                                  onTap: () {
                                                    if (message.imageUrl != null) {
                                                      _showImagePreview(message.imageUrl!);
                                                    }
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: Image.network(
                                                      message.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return SizedBox(
                                                          width: 200,
                                                          height: 200,
                                                          child: Center(
                                                            child: CircularProgressIndicator(
                                                              value: loadingProgress.expectedTotalBytes != null
                                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                                      loadingProgress.expectedTotalBytes!
                                                                  : null,
                                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                                isMe ? Colors.white : const Color(0xFF115213),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        width: 200,
                                                        height: 200,
                                                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ] else ...[
                                                Text(
                                                  text,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTime(timestamp),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isMe
                                                          ? Colors.white70
                                                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      isReadByOther
                                                          ? Icons.done_all
                                                          : Icons.done,
                                                      size: 14,
                                                      color: isReadByOther
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSendingImage
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                              ),
                            )
                          : Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.primary),
                      onPressed: _isSendingImage ? null : _pickAndSendImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) {
                          if (!_isSending) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
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
