import 'package:flutter/material.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;

  const ChatTile({
    Key? key,
    required this.name,
    required this.message,
    required this.time,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: name, 
        );
      },
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(name[0], style: TextStyle(color: Colors.white)),
      ),
      title: Text(
        name,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        message,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
      trailing: Text(time, style: TextStyle(fontSize: 14, color: Colors.grey)),
    );
  }
}
