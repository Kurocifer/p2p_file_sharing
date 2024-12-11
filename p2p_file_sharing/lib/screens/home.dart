import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:p2p_file_sharing/widgets/file_explorer.dart';
import 'package:p2p_file_sharing/widgets/log_panel.dart';
import 'package:p2p_file_sharing/widgets/notifications_panel.dart';
import 'package:p2p_file_sharing/widgets/peer_list.dart';
import 'package:p2p_file_sharing/widgets/theme_button.dart';
import 'package:p2p_file_sharing/services/peer_discovery_service.dart';

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
  final PeerDiscoveryService _peerDiscoveryService = PeerDiscoveryService(
    onLog: (message) => print(message),
  );

  int notificationCount = 0;
  bool _isFileExplorerCollapsed = true;
  bool _isLogsPanelCollapsed = false;
  bool _isNotificationPanelVisible = false;
  final List<String> peers = [];
  bool _isAnnouncingPresence = true;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
    logger.logMessage(message: "Peer discovery initialized.");
  }

  void _startDiscovery() {
    _peerDiscoveryService.startDiscovery();
    _updatePeers();
    logger.logMessage(message: "Started peer discovery.");
  }

  void _updatePeers() {
    setState(() {
      peers.clear();
      peers.addAll(_peerDiscoveryService.discoveredPeers);
    });
    logger.logMessage(
      message:
          "Peer list updated: ${peers.isEmpty ? 'No peers found' : '${peers.length} peers discovered'}",
    );
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
    _updatePeers();
  }

  void _toggleFileExplorer() {
    setState(() {
      _isFileExplorerCollapsed = !_isFileExplorerCollapsed;
    });
    logger.logMessage(
        message: _isFileExplorerCollapsed
            ? "Collapsed File Explorer"
            : "Expanded File Explorer");
  }

  void _togglelogsPanel() {
    setState(() {
      _isLogsPanelCollapsed = !_isLogsPanelCollapsed;
    });
    logger.logMessage(
        message: _isLogsPanelCollapsed
            ? "Collapsed File Explorer"
            : "Expanded File Explorer");
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
    _peerDiscoveryService.stopBroadcasting();
    logger.dispose(); // Close logger resources
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
                        child: peers.isEmpty
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
                                notify: _updatePeers,
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
          ? NotificationPanel(
              notificationCount: notificationCount,
              onClearNotifications: _clearNotifications,
            )
          : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 4.0,
      leading: IconButton(
        icon: const Icon(Icons.folder_outlined),
        onPressed: _toggleFileExplorer,
      ),
      actions: [
        ElevatedButton(
          onPressed: _togglelogsPanel,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent, // Match `AppBar` style
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: Text(_isLogsPanelCollapsed ? 'Show Logs' : 'Hide Logs'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _toggleNotificationPanel,
        ),
        ThemeButton(changeThemeMode: widget.changeTheme),
      ],
    );
  }

  void _clearNotifications() {
    setState(() {
      notificationCount = 0;
      _isNotificationPanelVisible = false;
    });
    logger.logMessage(message: "Cleared all notifications.");
  }
}
