import 'dart:io';

class Logger {
  
  // Log messages to both a file and the UI
  static void logMessage({required String message, Function(String)? onLog}) {
    // Log to the log file
    final logFile = File('../log.txt');
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);

    // Update the UI log
    if (onLog != null) {
      onLog(message);
    }
  }
}