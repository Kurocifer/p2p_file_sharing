import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class PeerDiscoveryService {
  final int broadcastPort = 4445; // Port for broadcasting
  final Set<String> _discoveredPeers = {}; // Set to store discovered peer identifiers
  final StreamController<List<String>> _peersStreamController =
      StreamController.broadcast(); // Stream controller for peer updates
  final Logger logger; // Logger instance for logging messages

  // Constructor
  PeerDiscoveryService() : logger = Logger();

  Timer? _broadcastTimer; // Timer for periodic broadcasting
  RawDatagramSocket? _broadcastSocket; // Datagram socket for broadcasting
  bool isBroadcasting = false; // Flag to check if broadcasting is active

  // Stream of discovered peers
  Stream<List<String>> get peersStream => _peersStreamController.stream;

  // Method to get the device name based on the platform
  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          return androidInfo.model; // Return Android device model
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          return iosInfo.name; // Return iOS device name
        }
      } else {
        return Platform.localHostname; // Return local hostname for other platforms
      }
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to get device name: $e',
      );
    }
    return "UnknownDevice"; // Fallback device name
  }

  // Method to get the operating system name
  String getOperatingSystem() {
    if (Platform.isLinux) {
      return 'Linux';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    if (Platform.isMacOS) {
      return 'MacOS';
    }
    return 'Unknown OS'; // Fallback for unknown OS
  }

  // Method to start broadcasting peer presence
  Future<void> _startBroadcasting() async {
    logger.logMessage(message: "I'm broadcasting");
    try {
      final deviceName = await _getDeviceName();
      final OSName = getOperatingSystem();
      final localIP = await _getLocalIP();

      if (localIP == '0.0.0.0') {
        logger.logMessage(
          message: '[WARNING] No valid local IP found. Broadcasting may fail.',
        );
      }

      final peerName = '$OSName:$deviceName';
      final message = jsonEncode({'peerName': peerName, 'ip': localIP});

      // Create a broadcast socket
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket!.broadcastEnabled = true;

      logger.logMessage(
        message: '[INFO] Broadcasting presence: $message',
      );

      // Periodically send broadcast messages
      _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _broadcastSocket!.send(
          utf8.encode(message),
          InternetAddress('255.255.255.255'),
          broadcastPort,
        );
      });

      isBroadcasting = true;
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to start broadcasting: $e',
      );
    }
  }

  // Method to start broadcasting if not already active
  Future<void> startBroadcasting() async {
    if (!isBroadcasting) {
      logger.logMessage(
        message: '[INFO] Starting broadcast...',
      );
      await _startBroadcasting();
    } else {
      logger.logMessage(
        message: '[INFO] Broadcast already active.',
      );
    }
  }

  // Method to stop broadcasting
  void stopBroadcasting() {
    if (isBroadcasting) {
      _broadcastTimer?.cancel(); // Cancel the broadcast timer
      _broadcastTimer = null;
      _broadcastSocket?.close(); // Close the broadcast socket
      _broadcastSocket = null;
      isBroadcasting = false; // Set broadcasting flag to false

      logger.logMessage(
        message: '[INFO] Broadcast stopped.',
      );
    } else {
      logger.logMessage(
        message: '[INFO] Broadcast is not active.',
      );
    }
  }

  // Notify listeners about peer updates
  void _notifyPeerUpdate() {
    _peersStreamController.add(_discoveredPeers.toList());
  }

  // Method to listen for incoming peer broadcasts
  void listenForPeers() async {
    logger.logMessage(message: "I'm listening");
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

      logger.logMessage(
        message: '[INFO] Listening for peers on port $broadcastPort...',
      );

      // Listen for incoming data on the socket
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();

          if (datagram != null) {
            final data = utf8.decode(datagram.data);
            try {
              final peerInfo = jsonDecode(data);

              // Validate the received peer information
              if (peerInfo is Map<String, dynamic> &&
                  peerInfo.containsKey('peerName') &&
                  peerInfo.containsKey('ip')) {
                final peerIP = peerInfo['ip'];
                final peerName = peerInfo['peerName'];

                final peerIdentifier = '$peerName@$peerIP';

                // Add new peer to the discovered peers set
                if (_discoveredPeers.add(peerIdentifier)) {
                  logger.logMessage(
                    message: '[INFO] Discovered new peer: $peerName at $peerIP',
                  );
                  _notifyPeerUpdate();
                }
              }
            } catch (e) {
              logger.logMessage(
                message: '[ERROR] Failed to decode peer data: $e',
              );
            }
          }
        }
      });
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to listen for peers: $e',
      );
    }
  }

  // Method to get the local IP address
  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // Return the first non-loopback IPv4 address
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to retrieve local IP address: $e',
      );
    }
    return '0.0.0.0'; // Return fallback IP if none found
  }

  // Dispose the service and close the stream
  void dispose() {
    _peersStreamController.close();
  }

  // Start the discovery process
  void startDiscovery() {
    logger.logMessage(message: 'Started discovery');
    startBroadcasting();
    listenForPeers();
  }
}

