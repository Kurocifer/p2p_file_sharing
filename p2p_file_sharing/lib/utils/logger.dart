import 'dart:async';
import 'dart:io';

class Logger {
  final StreamController<List<String>> _logController = StreamController<List<String>>.broadcast();
  final List<String> _logs = [];

  Stream<List<String>> get logStream => _logController.stream;

  // Log messages to both a file and the UI
  void logMessage({
    required String message,
    Function(String)? onLog,
  }) {
    // Log to the log file
    final logFile = File('log.txt');
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);

    // Update the UI log stream
    _logs.add(message);
    _logController.add(List.from(_logs));  // Send logs to the stream

    // Call the optional onLog callback for UI or other actions
    if (onLog != null) {
      onLog(message);
    }
  }
}
