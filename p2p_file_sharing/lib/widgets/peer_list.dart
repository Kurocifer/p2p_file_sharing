import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class PeerList extends StatelessWidget {
  final List<String> peers; // List of peers
  final Logger logger;
  final VoidCallback notify;

  const PeerList({
    super.key,
    required this.peers,
    required this.logger,
    required this.notify,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final peer = peers[index];
              return ListTile(
                title: Text(peer),
                onTap: () {
                  logger.logMessage(
                    message: "Interacted with peer: $peer",
                  );
                  notify();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
