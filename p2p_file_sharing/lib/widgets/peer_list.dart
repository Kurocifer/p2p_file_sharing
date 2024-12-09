import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class PeerList extends StatelessWidget {
  final Logger logger;
  final VoidCallback notify;

  const PeerList({super.key, required this.logger, required this.notify});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Peers",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 5, // Replace with actual peer count
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text("Peer $index"),
                  onTap: () {
                    // Use the logger to log the interaction
                    logger.logMessage(
                      message: "Interacted with Peer $index",
                      onLog: (message) {
                        // Optional callback function to handle other UI actions
                        print(message); // You can perform other actions here
                      },
                    );
                    // Notify the caller, e.g., to refresh the peer list or update the UI
                    notify();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
