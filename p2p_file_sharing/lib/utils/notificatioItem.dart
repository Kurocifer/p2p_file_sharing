import 'dart:convert';
import 'dart:io';

class NotificationItem {
  final String message;
  DateTime timestamp;

  NotificationItem(this.message) : timestamp = DateTime.now();

  // Convert a NotificationItem to a Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(), // Use ISO 8601 format for date
    };
  }

  // Factory method to create a NotificationItem from JSON
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(json['message'])
      ..timestamp = DateTime.parse(json['timestamp']);
  }
}

class NotificationService {
  final String _filePath = '${Platform.environment['HOME']}/deezapp/.deezapp/.notifications.json';

  // Method to write notifications to the file
  Future<void> writeNotifications(List<NotificationItem> notifications) async {
    final file = File(_filePath);
    // Create the directory if it doesn't exist
    await file.parent.create(recursive: true);

    // Convert notifications to JSON
    final jsonList = notifications.map((item) => item.toJson()).toList();
    
    // Write to the file, overwriting existing content
    await file.writeAsString(jsonEncode(jsonList));
  }

  // Method to delete notifications from the file
  Future<void> deleteNotifications() async {
    final file = File(_filePath);
    if (await file.exists()) {
      await file.delete(); // Delete the file
    }
  }

  // Method to read notifications from the file (if needed)
  Future<List<NotificationItem>> readNotifications() async {
    final file = File(_filePath);
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => NotificationItem.fromJson(json)).toList();
    }
    return [];
  }
}