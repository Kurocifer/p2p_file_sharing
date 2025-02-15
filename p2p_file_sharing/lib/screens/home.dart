import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:p2p_file_sharing/utils/notificatioItem.dart';
import 'package:p2p_file_sharing/widgets/file_explorer.dart';
import 'package:p2p_file_sharing/widgets/log_panel.dart';
import 'package:p2p_file_sharing/widgets/notifications_panel.dart';
import 'package:p2p_file_sharing/widgets/peer_list.dart';
import 'package:p2p_file_sharing/widgets/theme_button.dart';
import 'package:p2p_file_sharing/services/peer_discovery_service.dart';
import 'package:path/path.dart' as path;
import 'package:badges/badges.dart' as badges;

// Set to store paths of private files/folders
final Set<String> privatePaths = {};
// Path to the file that  stores private paths
late String privatePathsFile;


class Home extends StatefulWidget {
  final void Function(bool useLightMode) changeTheme;

  const Home({
    super.key,
    required this.changeTheme,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final Logger logger = Logger();
  final PeerDiscoveryService _peerDiscoveryService = PeerDiscoveryService();

  late final StreamSubscription<List<String>> _peerSubscription;
  late Future<TransferService> _transferService; // Future for TransferService

  bool _isFileExplorerCollapsed = false;
  bool _isLogsPanelCollapsed = true;
  bool _isNotificationPanelVisible = false;
  final List<String> peers = [];
  bool _isAnnouncingPresence = true;
    Timer? _notificationTimer;
    final NotificationService notifService = NotificationService();

 @override
  void initState() {
    super.initState();
    _startDiscovery();
    logger.logMessage(message: "Peer discovery initialized.");

    privatePathsFile = _getPrivatePathsFilePath();
    _loadPrivatePaths();

    // Subscribe to the peer updates from the stream
    _peerSubscription = _peerDiscoveryService.peersStream.listen((newPeers) {
      setState(() {
        peers.clear();
        peers.addAll(newPeers);
      });
    });

    _transferService = TransferService.create(); // Initialize TransferService

    // Start the timer to update notificationCount every 3 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        notificationCount = notifications.length;
      });
    });
    _loadNotifs();
  }

  String _getPrivatePathsFilePath() {
    if (Platform.isWindows) {
      return r'C:\Users\Public\Documents\deezapp\.deezapp\private_paths.json';
    } else {
      final homeDirectory = Platform.environment['HOME'] ?? '/';
      return path.join(
          homeDirectory, 'deezapp', '.deezapp', 'private_paths.json');
    }
  }

  void _loadPrivatePaths() {
    try {
      final file = File(privatePathsFile);
      if (file.existsSync()) {
        final contents = file.readAsStringSync();
        final List<dynamic> paths = json.decode(contents);
        privatePaths.addAll(paths.cast<String>());
      }
    } catch (e) {
      print('Error loading private paths: $e');
    }
  }

  void _loadNotifs() async {
    notifications = await notifService.readNotifications();
  }

  void _startDiscovery() {
    _peerDiscoveryService.startDiscovery();
    logger.logMessage(message: "Started peer discovery.");
  }

  void _togglePresenceBroadcast() async {
    if (_isAnnouncingPresence) {
      _peerDiscoveryService.stopBroadcasting();
      logger.logMessage(message: "Stopped broadcasting presence.");
    } else {
      await _peerDiscoveryService.startBroadcasting();
      logger.logMessage(message: "Started broadcasting presence.");
    }
    setState(() {
      _isAnnouncingPresence = !_isAnnouncingPresence;
    });
  }

  void _writeNotifs() async {
    await notifService.writeNotifications(notifications);
  }

  void _toggleFileExplorer(String directoryToExplore) {
    setState(() {
      _isFileExplorerCollapsed = !_isFileExplorerCollapsed;
    });
    logger.logMessage(
        message: _isFileExplorerCollapsed
            ? "Collapsed File Explorer"
            : "Expanded File Explorer");
  }

  void _toggleLogsPanel() {
    setState(() {
      _isLogsPanelCollapsed = !_isLogsPanelCollapsed;
    });
    logger.logMessage(
        message: _isLogsPanelCollapsed
            ? "Collapsed Logs Panel"
            : "Expanded Logs Panel");
  }

  void _toggleNotificationPanel() {
    setState(() {
      _isNotificationPanelVisible = !_isNotificationPanelVisible;
    });
    logger.logMessage(
      message: _isNotificationPanelVisible
          ? "Opened Notification Panel"
          : "Closed Notification Panel",
    );
  }

 @override
  void dispose() {
    _peerSubscription.cancel();
    _peerDiscoveryService.stopBroadcasting();
    _notificationTimer?.cancel();
    logger.dispose();
    _writeNotifs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // File Explorer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isFileExplorerCollapsed ? 0 : 250,
            child: FileExplorer(
              isCollapsed: _isFileExplorerCollapsed,
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Peer List Section
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: _togglePresenceBroadcast,
                          child: Text(
                            _isAnnouncingPresence
                                ? 'Stop Broadcasting'
                                : 'Start Broadcasting',
                          ),
                        ),
                      ),
                      Expanded(
                        child: FutureBuilder<TransferService>(
                          future: _transferService, // Future of TransferService
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error: ${snapshot.error}'));
                            } else if (snapshot.hasData) {
                              // TransferService is available
                              return peers.isEmpty
                                  ? Center(
                                      child: Text(
                                        "No peers found. Try refreshing or check your network.",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : PeerList(
                                      peers: peers,
                                      logger: logger,
                                      transferService: snapshot
                                          .data!, // Pass TransferService
                                      notify:
                                          () {},
                                    );
                            } else {
                              return const Center(child: Text('No data available.'));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Log Panel
                Expanded(
                  flex: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3.0,
                    width: _isLogsPanelCollapsed
                        ? 0
                        : MediaQuery.of(context)
                            .size
                            .width, // Use available width
                    child: LogPanel(
                      logger: logger,
                      isCollapsed: _isLogsPanelCollapsed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Notification Panel
      bottomSheet: _isNotificationPanelVisible
          ? Container(
              color: Theme.of(context)
                  .scaffoldBackgroundColor,

              child: NotificationPanel(
                notificationCount: notificationCount,
                onEditNotificationCounts: (action) =>
                    _editNotificationCounts(action),
                onClosePanel: () {
                  // Handle closing logic
                  setState(() {
                    _isNotificationPanelVisible = false;
                  });
                },
              ),
            )
          : null,
    );
  }

  void _editNotificationCounts(String action) {
    setState(() {
      switch (action) {
        case "clear":
          notificationCount = 0;
          break;
        case "deleteOne":
          notificationCount -= 1;
          break;
        case "addOne":
          notificationCount += 1;
          break;
        default:
          break;
      }
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 4.0,
      leading: IconButton(
        iconSize: 30.0,
        icon: const Icon(Icons.folder),
        onPressed: () => _toggleFileExplorer('shared'),
        tooltip: 'Toggle file explorer',
        color: Colors.blue,
      ),
      actions: [
        ElevatedButton(
          onPressed: _toggleLogsPanel,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: Text(_isLogsPanelCollapsed ? 'Show Logs' : 'Hide Logs'),
        ),
        Stack(
          children: [
            IconButton(
              color: Colors.yellow,
              iconSize: 28.0,
              icon: const Icon(Icons.notifications),
              onPressed: _toggleNotificationPanel,
            ),
            if (notificationCount > 0)
              Positioned(
                right: 8,
                top: 5,
                child: badges.Badge(
                  badgeContent: Text(
                    '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.0,
                    ),
                  ),
                  badgeColor: Colors.red,
                  position: badges.BadgePosition.topEnd(),
                ),
              ),
          ],
        ),
        ThemeButton(changeThemeMode: widget.changeTheme),
      ],
    );
  }
}
