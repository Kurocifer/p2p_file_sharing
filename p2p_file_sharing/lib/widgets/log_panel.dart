import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class LogPanel extends StatefulWidget {
  final Logger logger;
  final bool isCollapsed;

  const LogPanel({
    super.key,
    required this.logger,
    required this.isCollapsed,
  });

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  void _toggleCollapse() {
    setState(() {
      widget.logger.logMessage(message: 'Toggled Log Panel');
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCollapsed
        ? const SizedBox.shrink()
        : Material(
            elevation: 6.0,
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleCollapse,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8.0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Log Panel",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Icon(
                            Icons.update
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: widget.logger.logStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center();
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            return Text(
                              snapshot.data![index],
                              style: const TextStyle(fontSize: 14),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
