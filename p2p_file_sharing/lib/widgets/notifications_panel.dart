import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';
import 'package:p2p_file_sharing/utils/notificatioItem.dart';

class NotificationPanel extends StatefulWidget {
  final int notificationCount;
  final Function(String)
      onEditNotificationCounts;
  final VoidCallback onClosePanel;

  const NotificationPanel({
    super.key,
    required this.notificationCount,
    required this.onEditNotificationCounts,
    required this.onClosePanel,
  });

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {

  NotificationService notificationService = NotificationService();
  @override
  void initState() {
    super.initState();
    print(notifications);
  }

  void addNotification(String notificationMessage) {
    setState(() {
      notifications.add(NotificationItem(notificationMessage));
    });
    widget.onEditNotificationCounts("addOne");
  }

  void _removeNotification(int index) {
    setState(() {
      notifications.removeAt(index);
    });
    widget.onEditNotificationCounts("deleteOne");
    _writeNotifs();
  }

   void _writeNotifs() async {
    await notificationService.writeNotifications(notifications);
  }

  void _clearNotifications() {
    setState(() {
      notifications.clear();
    });
    widget.onEditNotificationCounts("clear");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 360,
        height: 500,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => addNotification("New notification"),
                      icon: const Icon(Icons.add),
                      color: isDarkMode ? Colors.greenAccent : Colors.green,
                    ),
                    IconButton(
                      tooltip: 'clear all notifications',
                      onPressed: _clearNotifications,
                      icon: const Icon(Icons.clear_all),
                      color: isDarkMode ? Colors.redAccent : Colors.red,
                    ),
                    IconButton(
                      onPressed: widget.onClosePanel,
                      icon: const Icon(Icons.close),
                      color: isDarkMode ? Colors.grey : Colors.black87,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            const Divider(),
            const SizedBox(height: 8.0),
            Expanded(
              child: notifications.isNotEmpty
                  ? ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: Icon(
                            Icons.notifications,
                            color: isDarkMode
                                ? Colors.blue[300]
                                : Colors.blue[800],
                          ),
                          title: Text(
                            notifications[index]
                                .message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            '${notifications[index].timestamp.toLocal().toString().split(' ')[0]} ${notifications[index].timestamp.hour}:${notifications[index].timestamp.minute.toString().padLeft(2, '0')}', // Display date and time
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            color: isDarkMode ? Colors.redAccent : Colors.red,
                            onPressed: () => _removeNotification(index),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        'No notifications yet!',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
