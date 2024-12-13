import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';

class PeerFileExplorer extends StatefulWidget {
  final Map<String, dynamic> directoryStructure;
  final String peer;
  final String paths;

  const PeerFileExplorer({
    super.key,
    required this.directoryStructure,
    required this.peer,
    required this.paths,
  });

  @override
  _PeerFileExplorerState createState() => _PeerFileExplorerState();
}

class _PeerFileExplorerState extends State<PeerFileExplorer> {
  String? selectedItem; // Keeps track of the currently selected item (file/folder)
  late TransferService transferService; // Instance of TransferService
  late String currentFilePath;

  @override
  void initState() {
    super.initState();
    initializeTransferService();
    currentFilePath = widget.paths; // Initialize with the passed path
  }

  Future<void> initializeTransferService() async {
    transferService = await TransferService.create();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String extractIpAddress(String input) {
    if (input.contains('@')) {
      return input.split('@')[1];
    } else {
      return input;
    }
  }

  String removePrefixIfMatches(String input) {
    // Check if the input starts with the specified prefix
    if (input.startsWith('/')) {
      return input.substring('/'.length); // Remove the prefix
    }
    return input; // Return the original string if the prefix does not match
  }

  Future<void> _handleDownload() async {
    if (selectedItem == null) {
      _showMessage('No file or directory selected.');
      return;
    }

    final isDirectory = widget.directoryStructure[selectedItem] != null;

    if (isDirectory) {
      _showMessage("Operation can't be performed on directory.");
    } else {
      final fileName = removePrefixIfMatches('$currentFilePath/$selectedItem');
      final peerIP = extractIpAddress(widget.peer);
      print('file name: $fileName');

      _showMessage('Requesting download for $fileName...');

      try {
        await transferService.requestFile(peerIP, TransferService.fileRequestPort, fileName);
        await transferService.downloadFile();
        _showMessage('Download completed for $fileName.');
      } catch (e) {
        _showMessage('Failed to download $fileName: $e');
      }
    }
  }

  String removeAfterLastSlash() {
    // Check if the string is empty
    if (currentFilePath.isEmpty) {
      return '';
    }

    // Find the last index of '/'
    int lastSlashIndex = currentFilePath.lastIndexOf('/');

    // If no '/' is found, clear the string
    if (lastSlashIndex == -1) {
      return '';
    }

    // Set the currentFilePath to the substring before the last '/'
    return currentFilePath.substring(0, lastSlashIndex);
  }

  Future<bool> _onWillPop() async {
    // Call removeAfterLastSlash to update the currentFilePath
    String newPath = removeAfterLastSlash(); // Get the new path
    if (newPath != currentFilePath) {
      setState(() {
        currentFilePath = newPath; // Update the state
      });
      print('current Path: $currentFilePath');

      // Optionally, show a message if the path is cleared
      if (currentFilePath.isEmpty) {
        _showMessage('You are at the root directory.');
      }
    }

    // Allow the back action to proceed
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Add back button handling here
      child: Scaffold(
        appBar: AppBar(
          elevation: 4.0,
          title: Text('${widget.peer} File Explorer'),
          actions: [
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
                      final isSelected = selectedItem == name;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedItem = name;
                          });
                          print('Selected: $selectedItem');
                          print('current path after tap: $currentFilePath');
                        },
                        onDoubleTap: () {
                          if (isDirectory) {
                            String newPath = '$currentFilePath/$name'; // Update path
                            print('Navigating to: $newPath');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PeerFileExplorer(
                                  peer: widget.peer,
                                  directoryStructure: widget.directoryStructure[name],
                                  paths: newPath,
                                ),
                              ),
                            );
                          } else {
                            print('File clicked: $name');
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                          ),
                          width: 80.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDirectory ? Icons.folder : Icons.insert_drive_file,
                                size: 45.0,
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
      ),
    );
  }
}