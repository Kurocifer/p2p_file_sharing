import 'dart:io';

import 'package:rxdart/rxdart.dart';

class Logger {
  final BehaviorSubject<List<String>> _logController =
      BehaviorSubject<List<String>>.seeded([]);
  final List<String> _logs = [];
  final List<String> _errors = [];

  Stream<List<String>> get logStream => _logController.stream;

  void logMessage({
    required String message,
    bool isError = false,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    // Append to file
    final logFile = File('log.txt');
    logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);

    // Add to respective lists
    _logs.add(logEntry);
    if (isError) _errors.add(logEntry);

    // Broadcast logs to the stream
    _logController.add(List.from(_logs));
  }

  void dispose() {
    _logController.close();
  }
}
