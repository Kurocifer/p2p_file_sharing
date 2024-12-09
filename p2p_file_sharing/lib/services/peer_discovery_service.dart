import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class PeerDiscoveryService {
  final int broadcastPort = 4445;
  final List<String> discoveredPeers = [];
  final Function(String)? onLog;

  PeerDiscoveryService({required this.onLog});

  // get device name to use as peer name
  Future<String> _getDeviceName() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms (Android, iOS)
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model; // Use the device model as peer name
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name; // Use iOS device name
      }
    } else {
      // For desktop platforms (Windows, macOS, Linux)
      return Platform.localHostname; // Use local hostname
    }
    return "UnknownDevice"; // Default in case of failure
  }

  // Log messages to both a file and the UI
  void _logMessage(String message) {
    // Log to the log file
    final logFile = File('../log.txt');
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);

    // Update the UI log
    if (onLog != null) {
      onLog!(message);
    }
  }

  // Announce this peer on the network
  void announcePresence() async {
    final peerName = await _getDeviceName();
    final localIP = await _getLocalIP();
    final message = jsonEncode({'peerName': peerName, 'ip': localIP});
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    Timer.periodic(const Duration(seconds: 5), (timer) {
      socket.send(
        utf8.encode(message),
        InternetAddress('255.255.255.255'),
        broadcastPort,
      );
    });
    
    _logMessage('Broadcasting presence: $message');
  }

  // Listen for peer announcements
  void listenForPeers() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

    _logMessage('Listen for peers on port $broadcastPort...');

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();

        if (datagram != null) {
          final data = utf8.decode(datagram.data);
          final peerInfo = jsonDecode(data);
          final peerIP = peerInfo['ip'];

          if (!discoveredPeers.contains(peerIP)) {
            discoveredPeers.add(peerIP);
            _logMessage("Discovered peer: ${peerInfo['peerName']} at $peerIP");
          }
        }
      }
    });
  }
  
  // Get the Local IP address
  Future<String> _getLocalIP() async {
    final interfaces = await NetworkInterface.list();

    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '0.0.0.0'; // Default in case of no IP found
  }

  // start discovery process
  void startDiscovery() {
    announcePresence();
    listenForPeers();
  }
} 