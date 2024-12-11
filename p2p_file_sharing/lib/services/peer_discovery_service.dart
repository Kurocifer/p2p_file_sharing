import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

/*
class PeerDiscoveryService {
  final int broadcastPort = 4445;
  final Set<String> discoveredPeers = {}; // Use a Set for unique peers
  final Logger logger = Logger();
  final Function(String)? onLog;

  PeerDiscoveryService({required this.onLog});

  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;
  bool isBroadcasting = false;

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          return androidInfo.model;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          return iosInfo.name;
        }
      } else {
        return Platform.localHostname;
      }
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to get device name: $e',
        onLog: onLog,
      );
    }
    return "UnknownDevice";
  }

  Future<void> _startBroadcasting() async {
    try {
      final peerName = await _getDeviceName();
      final localIP = await _getLocalIP();
      if (localIP == '0.0.0.0') {
        logger.logMessage(
          message: '[WARNING] No valid local IP found. Broadcasting may fail.',
          onLog: onLog,
        );
      }

      final message = jsonEncode({'peerName': peerName, 'ip': localIP});
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket!.broadcastEnabled = true;

      logger.logMessage(
        message: '[INFO] Broadcasting presence: $message',
        onLog: onLog,
      );

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
        onLog: onLog,
      );
    }
  }

  Future<void> startBroadcasting() async {
    if (!isBroadcasting) {
      logger.logMessage(
        message: '[INFO] Starting broadcast...',
        onLog: onLog,
      );
      await _startBroadcasting();
    } else {
      logger.logMessage(
        message: '[INFO] Broadcast already active.',
        onLog: onLog,
      );
    }
  }

  void stopBroadcasting() {
    if (isBroadcasting) {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _broadcastSocket?.close();
      _broadcastSocket = null;
      isBroadcasting = false;

      logger.logMessage(
        message: '[INFO] Broadcast stopped.',
        onLog: onLog,
      );
    } else {
      logger.logMessage(
        message: '[INFO] Broadcast is not active.',
        onLog: onLog,
      );
    }
  }

  void listenForPeers() async {
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

      logger.logMessage(
        message: '[INFO] Listening for peers on port $broadcastPort...',
        onLog: onLog,
      );

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();

          if (datagram != null) {
            final data = utf8.decode(datagram.data);
            try {
              final peerInfo = jsonDecode(data);

              if (peerInfo is Map<String, dynamic> &&
                  peerInfo.containsKey('peerName') &&
                  peerInfo.containsKey('ip')) {
                final peerIP = peerInfo['ip'];
                final peerName = peerInfo['peerName'];

                // Use a unique identifier for peers
                final peerIdentifier = '$peerName@$peerIP';

                if (discoveredPeers.add(peerIdentifier)) {
                  // New peer added
                  logger.logMessage(
                    message: '[INFO] Discovered new peer: $peerName at $peerIP',
                    onLog: onLog,
                  );
                } else {
                  // Peer already exists
                  logger.logMessage(
                    message: '[INFO] Duplicate peer ignored: $peerName at $peerIP',
                    onLog: onLog,
                  );
                }
              } else {
                logger.logMessage(
                  message: '[WARNING] Received invalid peer data: $data',
                  onLog: onLog,
                );
              }
            } catch (e) {
              logger.logMessage(
                message: '[ERROR] Failed to decode peer data: $e',
                onLog: onLog,
              );
            }
          }
        }
      });
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to listen for peers: $e',
        onLog: onLog,
      );
    }
  }

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to retrieve local IP address: $e',
        onLog: onLog,
      );
    }
    return '0.0.0.0';
  }

  void listenForPeersWY() async {
  try {
    final socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

    final localIP = await _getLocalIP(); // Get the local IP address
    logger.logMessage(
      message: '[INFO] Listening for peers on port $broadcastPort...',
      onLog: onLog,
    );

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();

        if (datagram != null) {
          final senderIP = datagram.address.address; // Sender's IP address
          if (senderIP == localIP) {
            // Ignore messages from self
            logger.logMessage(
              message: '[INFO] Ignored self-broadcast from $senderIP',
              onLog: onLog,
            );
            return;
          }

          final data = utf8.decode(datagram.data);
          try {
            final peerInfo = jsonDecode(data);

            // Validate incoming JSON
            if (peerInfo is Map<String, dynamic> &&
                peerInfo.containsKey('peerName') &&
                peerInfo.containsKey('ip')) {
              final peerIP = peerInfo['ip'];
              final peerName = peerInfo['peerName'];

              // Use a unique identifier for peers
              final peerIdentifier = '$peerName@$peerIP';

              if (discoveredPeers.add(peerIdentifier)) {
                // New peer added
                logger.logMessage(
                  message: '[INFO] Discovered new peer: $peerName at $peerIP',
                  onLog: onLog,
                );
              } else {
                // Peer already exists
                logger.logMessage(
                  message: '[INFO] Duplicate peer ignored: $peerName at $peerIP',
                  onLog: onLog,
                );
              }
            } else {
              logger.logMessage(
                message: '[WARNING] Received invalid peer data: $data',
                onLog: onLog,
              );
            }
          } catch (e) {
            logger.logMessage(
              message: '[ERROR] Failed to decode peer data: $e',
              onLog: onLog,
            );
          }
        }
      }
    });
  } catch (e) {
    logger.logMessage(
      message: '[ERROR] Failed to listen for peers: $e',
      onLog: onLog,
    );
  }
}

  void startDiscovery() {
    startBroadcasting();
    listenForPeers();
  }
}
*/
class PeerDiscoveryService {
  final int broadcastPort = 4445;
  final Set<String> discoveredPeers = {}; // Use a Set for unique peers
  final Logger logger = Logger();
  final Function(String)? onLog;

  PeerDiscoveryService({required this.onLog});

  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;
  bool isBroadcasting = false;

  Future<String> _getDeviceName() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          return androidInfo.model;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          return iosInfo.name;
        }
      } else {
        return Platform.localHostname;
      }
    } catch (e) {
      logger.logMessage(
        message: '[ERROR] Failed to get device name: $e',
      );
    }
    return "UnknownDevice";
  }

  Future<void> _startBroadcasting() async {
    logger.logMessage(message: "I'm broadcasting");
    try {
      final peerName = await _getDeviceName();
      final localIP = await _getLocalIP();
      if (localIP == '0.0.0.0') {
        logger.logMessage(
          message: '[WARNING] No valid local IP found. Broadcasting may fail.',
        );
      }

      final message = jsonEncode({'peerName': peerName, 'ip': localIP});
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket!.broadcastEnabled = true;

      logger.logMessage(
        message: '[INFO] Broadcasting presence: $message',
      );

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

  void stopBroadcasting() {
    if (isBroadcasting) {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _broadcastSocket?.close();
      _broadcastSocket = null;
      isBroadcasting = false;

      logger.logMessage(
        message: '[INFO] Broadcast stopped.',
      );
    } else {
      logger.logMessage(
        message: '[INFO] Broadcast is not active.',
      );
    }
  }

  void listenForPeers() async {
    logger.logMessage(message: "I'm listening");
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);

      logger.logMessage(
        message: '[INFO] Listening for peers on port $broadcastPort...',
      );

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();

          if (datagram != null) {
            final data = utf8.decode(datagram.data);
            try {
              final peerInfo = jsonDecode(data);

              if (peerInfo is Map<String, dynamic> &&
                  peerInfo.containsKey('peerName') &&
                  peerInfo.containsKey('ip')) {
                final peerIP = peerInfo['ip'];
                final peerName = peerInfo['peerName'];

                // Use a unique identifier for peers
                final peerIdentifier = '$peerName@$peerIP';

                if (discoveredPeers.add(peerIdentifier)) {
                  // New peer added
                  logger.logMessage(
                    message: '[INFO] Discovered new peer: $peerName at $peerIP',
                  );
                } else {
                  // Peer already exists
                  logger.logMessage(
                    message: '[INFO] Duplicate peer ignored: $peerName at $peerIP',
                  );
                }
              } else {
                logger.logMessage(
                  message: '[WARNING] Received invalid peer data: $data',
                );
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
  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
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
    return '0.0.0.0';
  }

  void startDiscovery() {
    logger.logMessage(message: 'started discovery');
    startBroadcasting();
    listenForPeers();
  }
}

