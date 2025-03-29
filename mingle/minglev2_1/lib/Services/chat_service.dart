import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:minglev2_1/utils/logger.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger('ChatService');

  // Get chat stream
  Stream<QuerySnapshot> getChatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Send message
  Future<void> sendMessage(String chatId, String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    try {
      final now = FieldValue.serverTimestamp();
      final messageData = {
        'text': message,
        'senderId': currentUser.uid,
        'timestamp': now,
        'read': false,
        'createdAt': now,
      };

      // Start a batch write
      final batch = _firestore.batch();

      // Add message to chat
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, messageData);

      // Get current chat document to check existing unread count and active users
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final currentData = chatDoc.data() ?? {};
      final currentUnreadCount = currentData['unreadCount'] ?? 0;
      final activeUsers = List<String>.from(currentData['activeUsers'] ?? []);
      final recipientId = (currentData['participants'] as List).firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      // Check if recipient is currently in the chat page
      final isRecipientInChat = activeUsers.contains(recipientId);
      
      _logger.info('Sending message to chat $chatId - Recipient in chat: $isRecipientInChat');

      // Update chat document
      final chatRef = _firestore.collection('chats').doc(chatId);
      final updates = {
        'lastMessage': message,
        'lastMessageTime': now,
        'lastMessageSenderId': currentUser.uid,
        'lastReadBy': {
          currentUser.uid: now,
        },
      };

      if (isRecipientInChat) {
        // If recipient is in chat, mark message as read immediately
        updates['hasUnreadMessages'] = false;
        updates['unreadCount'] = currentUnreadCount;
        batch.update(messageRef, {'read': true});
      } else {
        // If recipient is not in chat, increment unread count
        updates['hasUnreadMessages'] = true;
        updates['unreadCount'] = currentUnreadCount + 1;
      }

      batch.update(chatRef, updates);
      await batch.commit();
      
      _logger.info('Successfully sent message with unread count: ${updates['unreadCount']}');
    } catch (e) {
      _logger.severe('Error sending message: $e');
      rethrow;
    }
  }

  // Get user's chats
  Stream<QuerySnapshot> getUserChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Get chat participants
  Future<Map<String, dynamic>> getChatParticipants(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final participants = chatDoc.data()?['participants'] as List<dynamic>;
    
    final participantsData = <String, dynamic>{};
    
    for (var participantId in participants) {
      final userDoc = await _firestore.collection('users').doc(participantId).get();
      final userData = userDoc.data();
      if (userData != null) {
        participantsData[participantId] = {
          'name': userData['name'],
          'profileImage': userData['profileImage'],
        };
      }
    }
    
    return participantsData;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    try {
      _logger.info('Starting to mark messages as read in chat $chatId');
      
      // Get all unread messages from other users
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      if (messages.docs.isEmpty) {
        _logger.info('No unread messages found in chat $chatId');
        // Update chat document to reflect no unread messages
        await _firestore.collection('chats').doc(chatId).update({
          'hasUnreadMessages': false,
          'unreadCount': 0,
          'lastReadBy': {
            currentUser.uid: FieldValue.serverTimestamp(),
          },
        });
        return;
      }

      _logger.info('Found ${messages.docs.length} unread messages in chat $chatId');

      final batch = _firestore.batch();
      
      // Mark all unread messages as read
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      // Update chat document to indicate no unread messages
      batch.update(_firestore.collection('chats').doc(chatId), {
        'hasUnreadMessages': false,
        'unreadCount': 0,
        'lastReadBy': {
          currentUser.uid: FieldValue.serverTimestamp(),
        },
      });

      await batch.commit();
      _logger.info('Successfully marked messages as read in chat $chatId');
    } catch (e) {
      _logger.severe('Error marking messages as read: $e');
      rethrow;
    }
  }

  // Sync unread status
  Future<void> syncUnreadStatus(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    try {
      _logger.info('Syncing unread status for chat $chatId');
      
      // Get all unread messages
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .get();

      final unreadCount = messages.docs.length;
      _logger.info('Found $unreadCount unread messages');

      // Update chat document with current unread status
      await _firestore.collection('chats').doc(chatId).update({
        'hasUnreadMessages': unreadCount > 0,
        'unreadCount': unreadCount,
        'lastReadBy': {
          currentUser.uid: FieldValue.serverTimestamp(),
        },
      });

      _logger.info('Successfully synced unread status');
    } catch (e) {
      _logger.severe('Error syncing unread status: $e');
      rethrow;
    }
  }

  // Get unread message count
  Stream<int> getUnreadMessageCount(String chatId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user');

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get match details
  Future<Map<String, dynamic>> getMatchDetails(String chatId) async {
    try {
      _logger.info('Fetching match details for chat $chatId');
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      
      if (chatData == null) {
        _logger.warning('Chat data is null for chat $chatId');
        throw Exception('Chat not found');
      }

      _logger.fine('Raw chat data: $chatData');
      
      // Access the nested matchDetails object
      final matchDetails = chatData['matchDetails'] as Map<String, dynamic>? ?? {};
      
      final details = {
        'category': matchDetails['category'] ?? '',
        'place': matchDetails['place'] ?? '',
        'schedule': matchDetails['scheduledTime'] ?? '',
        'matchDate': chatData['createdAt'] != null 
            ? (chatData['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
            : '',
      };
      
      _logger.info('Processed match details: $details');
      return details;
    } catch (e) {
      _logger.severe('Error fetching match details: $e');
      return {
        'category': '',
        'place': '',
        'schedule': '',
        'matchDate': '',
      };
    }
  }

  // Update match details
  Future<void> updateMatchDetails(String chatId, {
    String? category,
    String? place,
    String? schedule,
    DateTime? matchDate,
  }) async {
    try {
      logger.info('Updating match details for chat $chatId');
      final updates = <String, dynamic>{};
      
      if (category != null) updates['category'] = category;
      if (place != null) updates['place'] = place;
      if (schedule != null) updates['schedule'] = schedule;
      if (matchDate != null) updates['matchDate'] = Timestamp.fromDate(matchDate);
      
      logger.info('Updates to apply: $updates');
      
      await _firestore.collection('chats').doc(chatId).update(updates);
      logger.info('Successfully updated match details');
    } catch (e) {
      logger.severe('Error updating match details: $e');
      rethrow;
    }
  }

  // Unmatch with a user
  Future<void> unmatch(String chatId) async {
    try {
      logger.info('Unmatching chat $chatId');
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      // Get the chat document
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) throw Exception('Chat not found');

      final chatData = chatDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // Remove chat reference from both users' documents
      await Future.wait([
        _firestore.collection('users').doc(participants[0]).update({
          'chats': FieldValue.arrayRemove([chatId])
        }),
        _firestore.collection('users').doc(participants[1]).update({
          'chats': FieldValue.arrayRemove([chatId])
        })
      ]);

      // Delete the chat document and all its messages
      await _firestore.collection('chats').doc(chatId).delete();
      logger.info('Successfully unmatched chat $chatId');
    } catch (e) {
      logger.severe('Error unmatching: $e');
      rethrow;
    }
  }

  // Update active users in chat
  Future<void> updateActiveUsers(String chatId, String userId, bool isActive) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      if (isActive) {
        await chatRef.update({
          'activeUsers': FieldValue.arrayUnion([userId])
        });
      } else {
        await chatRef.update({
          'activeUsers': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      logger.severe('Error updating active users: $e');
    }
  }
} 
