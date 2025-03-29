import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    final now = FieldValue.serverTimestamp();
    final messageData = {
      'text': message,
      'senderId': currentUser.uid,
      'timestamp': now,
      'read': false,
      'createdAt': now,
    };

    // Add message to chat
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Update last message in chat document
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': message,
      'lastMessageTime': now,
      'lastMessageSenderId': currentUser.uid,
      'hasUnreadMessages': true,
      'lastReadBy': {
        currentUser.uid: now,
      },
    });
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

    // First check if there are any unread messages
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    
    // If chat doesn't have unread messages, return early
    if (chatData?['hasUnreadMessages'] != true) {
      print('Debug: No unread messages in chat $chatId');
      return;
    }

    // Get all unread messages from other users
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .get();

    if (messages.docs.isEmpty) {
      print('Debug: No unread messages found in chat $chatId');
      // Update chat document to reflect no unread messages
      await _firestore.collection('chats').doc(chatId).update({
        'hasUnreadMessages': false,
        'lastReadBy': {
          currentUser.uid: FieldValue.serverTimestamp(),
        },
      });
      return;
    }

    print('Debug: Found ${messages.docs.length} unread messages in chat $chatId');

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    // Update chat document to indicate no unread messages
    batch.update(_firestore.collection('chats').doc(chatId), {
      'hasUnreadMessages': false,
      'lastReadBy': {
        currentUser.uid: FieldValue.serverTimestamp(),
      },
    });

    await batch.commit();
    print('Debug: Successfully marked messages as read in chat $chatId');
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
      print('Debug: Fetching match details for chat $chatId');
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      
      if (chatData == null) {
        print('Debug: Chat data is null for chat $chatId');
        throw Exception('Chat not found');
      }

      print('Debug: Raw chat data: $chatData');
      
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
      
      print('Debug: Processed match details: $details');
      return details;
    } catch (e) {
      print('Error fetching match details: $e');
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
      print('Debug: Updating match details for chat $chatId');
      final updates = <String, dynamic>{};
      
      if (category != null) updates['category'] = category;
      if (place != null) updates['place'] = place;
      if (schedule != null) updates['schedule'] = schedule;
      if (matchDate != null) updates['matchDate'] = Timestamp.fromDate(matchDate);
      
      print('Debug: Updates to apply: $updates');
      
      await _firestore.collection('chats').doc(chatId).update(updates);
      print('Debug: Successfully updated match details');
    } catch (e) {
      print('Error updating match details: $e');
      rethrow;
    }
  }

  // Unmatch with a user
  Future<void> unmatch(String chatId) async {
    try {
      print('Debug: Unmatching chat $chatId');
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
      print('Debug: Successfully unmatched chat $chatId');
    } catch (e) {
      print('Error unmatching: $e');
      rethrow;
    }
  }
} 