import 'package:flutter/material.dart';

class PeerFileExplorer extends StatefulWidget {
  final Map<String, dynamic> directoryStructure;
  final String peer;

  const PeerFileExplorer({
    super.key,
    required this.directoryStructure,
    required this.peer,
  });

  @override
  _PeerFileExplorerState createState() => _PeerFileExplorerState();
}

class _PeerFileExplorerState extends State<PeerFileExplorer> {
  String? selectedItem; // Keeps track of the currently selected item (file/folder)

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _handleDownload() {
    if (selectedItem == null) {
      _showMessage('No file or directory selected.');
      return;
    }

    final isDirectory = widget.directoryStructure[selectedItem] != null;

    if (isDirectory) {
      _showMessage("Operation can't be performed on directory.");
    } else {
      _showMessage('Downloading $selectedItem...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 4.0,
        title: Text('${widget.peer} File Explorer'),
        actions: [
          // "Download" button with click reaction
          ElevatedButton(
            onPressed: _handleDownload,
            style: ElevatedButton.styleFrom(
              elevation: 20.0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Download File'),
                SizedBox(width: 10.0),
                Icon(Icons.download),
              ],
            ),
          ),
          const SizedBox(width: 16), // Space between buttons
          // "Send" button with click reaction
          ElevatedButton(
            onPressed: () => print('send'),
            style: ElevatedButton.styleFrom(
              elevation: 20.0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Send File'),
                SizedBox(width: 10),
                Icon(Icons.send),
              ],
            ),
          ),
          const SizedBox(width: 20.0),
        ],
      ),
      body: widget.directoryStructure.isEmpty
          ? const Center(
              child: Text('No files or directories available'),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: widget.directoryStructure.keys.map((name) {
                    final isDirectory = widget.directoryStructure[name] != null;

                    // Check if the current item is selected for highlighting
                    bool isSelected = selectedItem == name;

                    return GestureDetector(
                      onTap: () {
                        // Highlight on click (single tap)
                        setState(() {
                          selectedItem = name; // Set the clicked item as selected
                        });
                      },
                      onDoubleTap: () {
                        if (isDirectory) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PeerFileExplorer(
                                peer: widget.peer,
                                directoryStructure: widget.directoryStructure[name],
                              ),
                            ),
                          );
                        } else {
                          // Handle file click
                          print('File clicked: $name');
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150), // Smooth transition for highlight
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: isSelected
                              ? Colors.blue.withOpacity(0.2) // Highlight color
                              : Colors.transparent,
                        ),
                        width: 80.0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDirectory
                                  ? Icons.folder
                                  : Icons.insert_drive_file,
                              size: 40.0,
                              color: isDirectory ? Colors.amber : Colors.blue,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12.0),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}