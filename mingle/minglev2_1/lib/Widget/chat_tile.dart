import 'package:flutter/material.dart';
import 'package:minglev2_1/Services/navigation_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String chatId;
  final String partnerId;
  final bool hasUnreadMessages;
  final int unreadCount;

  const ChatTile({
    Key? key,
    required this.name,
    required this.message,
    required this.time,
    required this.chatId,
    required this.partnerId,
    this.hasUnreadMessages = false,
    this.unreadCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        NavigationService().navigateToChat(chatId, name, partnerId);
      },
      leading: Stack(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(partnerId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(name[0], style: const TextStyle(color: Colors.white)),
                );
              }

              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final profileImage = userData?['profileImage'];

              return CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: profileImage != null
                    ? MemoryImage(base64Decode(profileImage))
                    : null,
                child: profileImage == null
                    ? Text(name[0], style: const TextStyle(color: Colors.white))
                    : null,
              );
            },
          ),
        ],
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: hasUnreadMessages ? Colors.black : Colors.grey,
          fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          if (hasUnreadMessages)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withAlpha(56),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
