import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/utils/logger.dart';

class FileExplorer extends StatelessWidget {
  final Logger logger;

  const FileExplorer({super.key, required this.logger});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "File Explorer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 10, // Replace with actual file count
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text("File $index"),
                  onTap: () {
                    // Use the logger to log the interaction
                    logger.logMessage(
                      message: "Selected File $index",
                      onLog: (message) {
                        // Optional callback function to handle other UI actions
                        print(message); // You can perform other actions here
                      },
                    );
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
