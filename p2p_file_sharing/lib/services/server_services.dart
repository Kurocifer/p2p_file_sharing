import 'dart:collection';
import 'dart:io';

class ServerService {
  final int maxSimultaneosConnections = 5;
  final Map<String, int> requestCounts = {};
  final Queue<Socket> requestQueue = Queue();
  int currentConnections = 0;

  void startServer() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);
    print("Server running on ${server.address.address}:${server.port}");

    server.listen((Socket socket) {
      if (currentConnections >= maxSimultaneosConnections) {
        socket.write("Too many connections. Please wait.");
        requestQueue.add(socket);
      } else {
        _handleConnection(socket);
      }
    });
    
  }
  
  void _handleConnection(Socket socket) {
    currentConnections++;
    print("Client connected: ${socket.remoteAddress}");

    socket.listen(
      (data) {
        final userIP = socket.remoteAddress.address;
        requestCounts[userIP] = (requestCounts[userIP] ?? 0) + 1;

        if (requestCounts[userIP]! > 10) {
          socket.write("Rale limit exceeded.");
          socket.destroy();
        } else {
          socket.write("Request received.");
        }
      },
      onDone: () {
        currentConnections--;
        socket.close();
        _processQueue();
      }
    );

  }
  
  void _processQueue() {
    if (requestQueue.isNotEmpty) {
      final nextSocket = requestQueue.removeFirst();
      _handleConnection(nextSocket);
    }
  }
}