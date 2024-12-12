import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';

class Logger {
  final BehaviorSubject<List<String>> _logController =
      BehaviorSubject<List<String>>.seeded([]);
  final List<String> _logs = [];
  final List<String> _errors = [];

  // Dynamically determine log file path based on the platform
  String get logFilePath {
    if (Platform.isWindows) {
      return r'C:\Users\Public\Documents\deezapp\logs\log.txt';
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '/tmp'; // Fallback to /tmp if HOME is not set
      return path.join(home, 'deezapp', 'logs', 'log.txt');
    } else {
      throw UnsupportedError('Platform not supported for logging');
    }
  }

  // Ensure the log directory exists
  void _ensureLogDirectory() {
    final logFile = File(logFilePath);
    final logDir = logFile.parent;
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
  }

  Stream<List<String>> get logStream => _logController.stream;

  void logMessage({
    required String message,
    bool isError = false,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $message';

    // Ensure log directory exists
    _ensureLogDirectory();

    // Append log entry to file
    final logFile = File(logFilePath);
    logFile.writeAsStringSync('$logEntry\n', mode: FileMode.append);

    // Add log entry to respective lists
    _logs.add(logEntry);
    if (isError) _errors.add(logEntry);

    // Broadcast logs to the stream
    _logController.add(List.from(_logs));
  }

  void dispose() {
    _logController.close();
  }
}
