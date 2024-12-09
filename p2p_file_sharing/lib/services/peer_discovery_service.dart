import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class PeerDiscoveryService {
  final int broadcastPort = 4445;
  final List<String> discoveredPeers = [];
  final Function(String)? onLog;

  PeerDiscoveryService({required this.onLog});

  Timer? _broadcastTimer;
  bool isBroadcasting = false;

  // Get device name to use as peer name
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

  // Announce this peer on the network
  Future<void> _startBroadcasting() async {
    final peerName = await _getDeviceName();
    final localIP = await _getLocalIP();
    final message = jsonEncode({'peerName': peerName, 'ip': localIP});
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    Logger.logMessage(
      message: 'Broadcasting presence: $message',
      onLog: onLog,
    );

    // Start broadcasting at regular intervals
    _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      socket.send(
        utf8.encode(message),
        InternetAddress('255.255.255.255'),
        broadcastPort,
      );
    });

    isBroadcasting = true;
  }

  /// Start broadcasting presence
  Future<void> startBroadcasting() async {
    if (!isBroadcasting) {
      Logger.logMessage(
        message: '[INFO] Starting broadcast...',
        onLog: onLog,
      );
      await _startBroadcasting();
    } else {
      Logger.logMessage(
        message: '[INFO] Broadcast already active.',
        onLog: onLog,
      );
    }
  }

  /// Stop broadcasting presence
  void stopBroadcasting() {
    if (isBroadcasting) {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      isBroadcasting = false;
      Logger.logMessage(
        message: '[INFO] Broadcast stopped.',
        onLog: onLog,
      );
    } else {
      Logger.logMessage(
        message: '[INFO] Broadcast is not active.',
        onLog: onLog,
      );
    }
  }

  // Listen for peer announcements
  void listenForPeers() async {
    final socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

    Logger.logMessage(
      message: 'Listening for peers on port $broadcastPort...',
      onLog: onLog,
    );

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();

        if (datagram != null) {
          final data = utf8.decode(datagram.data);
          final peerInfo = jsonDecode(data);
          final peerIP = peerInfo['ip'];

          if (!discoveredPeers.contains(peerIP)) {
            discoveredPeers.add(peerIP);
            Logger.logMessage(
              message:
                  'Discovered peer: ${peerInfo['peerName']} at $peerIP',
              onLog: onLog,
            );
          }
        }
      }
    });
  }

  // Get the local IP address
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

  // Start the discovery process (broadcast + listen)
  void startDiscovery() {
    startBroadcasting();
    listenForPeers();
  }
}
