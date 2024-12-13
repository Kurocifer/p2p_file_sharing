
import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';
import 'package:p2p_file_sharing/widgets/peer_file_explorer_screen.dart';

class PeerList extends StatelessWidget {
  final List<String> peers;
  final Logger logger;
  final TransferService transferService;
  final VoidCallback notify;

  const PeerList({
    super.key,
    required this.peers,
    required this.logger,
    required this.transferService,
    required this.notify,
  });

  String extractIpAddress(String input) {
  // Check if the input contains the '@' character
  if (input.contains('@')) {
    // Split the string at '@' and return the second part (IP address)
    return input.split('@')[1];
  } else {
    // If the format is not correct, return the input as is or handle as needed
    return input; // or throw an error, depending on your requirements
  }
}

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
                    message: "Requesting directory from peer: $peer",
                  );

                  transferService.requestDirectoryStructure(
                    extractIpAddress(peer),
                    TransferService.directoryPort,
                    (structure) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PeerFileExplorer(
                            peer: peer,
                            directoryStructure: structure,
                            paths: '',
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/*import 'package:flutter/material.dart';
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
*/
