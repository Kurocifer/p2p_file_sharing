import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:p2p_file_sharing/widgets/file_explorer.dart';
import 'package:p2p_file_sharing/widgets/log_panel.dart';
import 'package:p2p_file_sharing/widgets/notifications_panel.dart';
import 'package:p2p_file_sharing/widgets/peer_list.dart';


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
  int notificationCount = 0; // Track notification count
  bool _isFileExplorerCollapsed = true; // Track file explorer state
  bool _isNotificationPanelVisible = false; // Notification panel visibility
    final List<String> logs = [];


  void _notify() {
    setState(() {});
  }

  void _toggleFileExplorer() {
    setState(() {
      _isFileExplorerCollapsed = !_isFileExplorerCollapsed;
    });
  }

  // Toggle visibility of notification panel
  void _toggleNotificationPanel() {
    setState(() {
      _isNotificationPanelVisible = !_isNotificationPanelVisible;
      if (_isNotificationPanelVisible) {
        notificationCount++; // Increment notification count when shown
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // File Explorer Side Panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isFileExplorerCollapsed ? 0 : 250,
            child: Material(
              elevation: 4.0, // Add elevation for shadow effect
              child: FileExplorer(logger: logger),
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Peer List
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: PeerList(
                      logger: logger,
                      notify: _notify,
                    ),
                  ),
                ),

                // Log Panel
                Expanded(
                  flex: 3,
                  child: Material(
                    elevation: 4.0, // Add elevation for shadow effect
                    child: LogPanel(
                      logger: logger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Floating Action Button to toggle file explorer visibility
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleFileExplorer,
        child: Icon(
          _isFileExplorerCollapsed ? Icons.arrow_forward : Icons.arrow_back,
        ),
      ),

      // Bottom Sheet for Notification Panel
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
        onPressed: _toggleFileExplorer, // Toggle file explorer when clicked
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Notification icon button to toggle notification panel visibility
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _toggleNotificationPanel,
          ),
        ],
      ),
    );
  }

  // Function to clear notifications
  void _clearNotifications() {
    setState(() {
      notificationCount = 0;
      _isNotificationPanelVisible = false; // Hide panel after clearing notifications
    });
  }

  void _addLog(String log) {
    setState(() {
      logs.add(log);
    });
  }
}
