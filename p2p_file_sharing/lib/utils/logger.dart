import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';

class Logger {
  // Controller for the log stream
  final BehaviorSubject<List<String>> _logController = 
      BehaviorSubject<List<String>>.seeded([]);

  // Internal list to store logs
  final List<String> _logs = [];

  // Dynamically determine log file path based on the platform
  String get logFilePath {
    if (Platform.isWindows) {
      return r'C:\Users\Public\Documents\deezapp\logs\log.txt';
    } else if (Platform.isLinux || Platform.isMacOS) {
      // Get HOME environment variable or fallback to /tmp
      final home = Platform.environment['HOME'] ?? '/tmp';
      return path.join(home, 'deezapp', 'logs', 'log.txt');
    } else {
      throw UnsupportedError('Platform not supported for logging');
    }
  }

  // Ensure the log directory exists
  void _ensureLogDirectory() {
    final logFile = File(logFilePath);
    final logDir = logFile.parent;

    // Create the directory if it does not exist
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
  }

  // Stream of log messages
  Stream<List<String>> get logStream => _logController.stream;

  // Method to log a message
  void logMessage({required String message}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    // Ensure log directory exists before writing
    _ensureLogDirectory();

    // Append log entry to the log file
    final logFile = File(logFilePath);
    logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);

    // Add log entry to internal logs
    _logs.add(logEntry);
    
    // Print the logs to the console (for debugging purposes)
    print(_logs);

    // Broadcast the updated logs to the stream
    _logController.add(List.from(_logs));
  }

  // Dispose the logger and close the stream
  void dispose() {
    _logController.close();
  }
}
