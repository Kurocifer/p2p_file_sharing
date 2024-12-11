import 'dart:collection';
import 'dart:io';
import 'dart:async';
import 'package:p2p_file_sharing/utils/logger.dart';

class ServerService {
  final int maxSimultaneosConnections = 5;
  final int maxRequestsPerClient = 10;
  final Duration rateLimitDuration = Duration(seconds: 60);
  
  final Map<String, int> requestCounts = {};
  final Map<String, Timer> rateLimitTimers = {};
  final Queue<Socket> requestQueue = Queue();
  int currentConnections = 0;
  final Function(String)? onLog;
  final Logger logger = Logger();


  ServerService({required this.onLog});

  // Start the server
  void startServer() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);
    logger.logMessage(message: "Server running on ${server.address.address}:${server.port}");

    server.listen((Socket socket) {
      if (currentConnections >= maxSimultaneosConnections) {
        socket.write("Too many connections. Please wait.");
        requestQueue.add(socket);
        logger.logMessage(message: "Connection queued: ${socket.remoteAddress}");
      } else {
        _handleConnection(socket);
      }
    });
  }

  // Handle incoming connection
  void _handleConnection(Socket socket) {
    currentConnections++;
    logger.logMessage(message: "Client connected: ${socket.remoteAddress}");

    final userIP = socket.remoteAddress.address;
    _resetRateLimit(userIP);

    socket.listen(
      (data) {
        // Track request count per client
        requestCounts[userIP] = (requestCounts[userIP] ?? 0) + 1;

        if (requestCounts[userIP]! > maxRequestsPerClient) {
          socket.write("Rate limit exceeded.");
          socket.destroy();
          logger.logMessage(message: "Rate limit exceeded for $userIP");
        } else {
          socket.write("Request received.");
          logger.logMessage(message: "Request received from $userIP");
        }
      },
      onDone: () {
        currentConnections--;
        socket.close();
        logger.logMessage(message: "Client disconnected: ${socket.remoteAddress}");
        _processQueue();
      },
      onError: (error) {
        logger.logMessage(message: "Error with connection: $error");
      },
    );
  }

  // Process queued requests when space becomes available
  void _processQueue() {
    if (requestQueue.isNotEmpty && currentConnections < maxSimultaneosConnections) {
      final nextSocket = requestQueue.removeFirst();
      _handleConnection(nextSocket);
    }
  }

  // Reset the rate limit timer for each client (per IP)
  void _resetRateLimit(String userIP) {
    if (rateLimitTimers.containsKey(userIP)) {
      rateLimitTimers[userIP]?.cancel();
    }

    rateLimitTimers[userIP] = Timer(rateLimitDuration, () {
      requestCounts[userIP] = 0;
      logger.logMessage(message: "Rate limit reset for $userIP");
    });
  }
}
