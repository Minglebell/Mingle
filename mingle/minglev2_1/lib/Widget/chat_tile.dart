import 'package:flutter/material.dart';
import 'package:minglev2_1/Services/navigation_services.dart';

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
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(name[0], style: TextStyle(color: Colors.white)),
          ),
          if (hasUnreadMessages)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 1 ? unreadCount.toString() : '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
          Text(time, style: TextStyle(fontSize: 14, color: Colors.grey)),
          if (hasUnreadMessages)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
