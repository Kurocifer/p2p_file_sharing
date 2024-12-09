import 'package:flutter/material.dart';

/*
class NotificationPanel extends StatelessWidget {
  final int notificationCount;
  final VoidCallback onClearNotifications;

  const NotificationPanel({
    super.key,
    required this.notificationCount,
    required this.onClearNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: onClearNotifications,
        ),
        if (notificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Text(
                '$notificationCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}*/

class NotificationPanel extends StatelessWidget {
  final int notificationCount;
  final VoidCallback onClearNotifications;

  const NotificationPanel({
    super.key,
    required this.notificationCount,
    required this.onClearNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClearNotifications,
              ),
            ],
          ),
          if (notificationCount > 0)
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.blue),
              title: Text('You have $notificationCount new notifications.'),
            ),
        ],
      ),
    );
  }
}

