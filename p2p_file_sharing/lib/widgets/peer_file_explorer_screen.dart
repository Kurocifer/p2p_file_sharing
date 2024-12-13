import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';
import 'package:provider/provider.dart';

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
  String? selectedItem;
  late TransferService transferService;
  late String currentFilePath;
  late String osType;
  String? sendFilePath;

  @override
  void initState() {
    super.initState();
    initializeTransferService();
    currentFilePath = widget.paths;
    osType = extractOsType(widget.peer);
  }

  Future<void> initializeTransferService() async {
    transferService = await TransferService.create();
  }

  String extractIpAddress(String input) {
    if (input.contains('@')) {
      return input.split('@')[1];
    } else {
      return input;
    }
  }

  String extractOsType(String input) {
    if (input.contains(':')) {
      return input.split(':')[0];
    } else {
      return 'Unknown';
    }
  }

  String constructFilePath(String currentPath, String fileName) {
    final separator = (osType == 'Windows') ? '\\' : '/';
    return currentPath.isEmpty ? fileName : '$currentPath$separator$fileName';
  }

  Future<void> _handleDownload() async {
  if (selectedItem == null) {
    _showMessage('No file or directory selected.');
    return;
  }

  final isDirectory = widget.directoryStructure[selectedItem] != null;

  if (isDirectory) {
    _showMessage("Operation can't be performed on a directory.");
  } else {
    final fileName = constructFilePath(currentFilePath, selectedItem!);
    final peerIP = extractIpAddress(widget.peer);

    _showMessage('Requesting download for $fileName...');

    try {
      // Send file request
      await transferService.requestFile(peerIP, TransferService.fileRequestPort, fileName);

      // Attempt file download
      final response = await transferService.downloadFile();
      final feedback = jsonDecode(response);

      if (feedback['status'] == 'success') {
        final savedPath = feedback['filePath'];
        _showMessage('Download successful! File saved to: $savedPath');
        print('File downloaded to: $savedPath');
      } else if (feedback['status'] == 'error') {
        final errorMessage = feedback['message'];
        final errorDetails = feedback['details'] ?? 'No additional details provided.';
        _showMessage('Download failed: $errorMessage');
        print('Error details: $errorDetails');
      } else {
        _showMessage('Unexpected response received during download.');
        print('Download response: $response');
      }
    } catch (e) {
      _showMessage('Failed to download $fileName: $e');
      print('Error occurred: $e');
    }
  }
}

  Future<void> _handleSend(String peerIp, int port) async {
    // Pick a file using File Picker
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      sendFilePath = result.files.single.path;
      if (sendFilePath != null) {
        await transferService.uploadFile(peerIp, port, sendFilePath!);
        /*
        try {
          // Open the selected file
          final file = File(sendFilePath!);

          // Establish a connection to the peer
          Socket socket = await Socket.connect(peerIp, port);
          print("Connected to $peerIp:$port");

          // Send the file
          socket.add(await file.readAsBytes());
          await socket.flush();
          socket.close();
          print("File sent successfully!");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("File sent successfully!")),
          );
        } catch (e) {
          print("Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to send file: $e")),
          );
        }
        */
      }
    } else {
      print("No file selected!");
    }
  }



void handleDownloadandCheck() async {
  final String downloadFilePath = Platform.isWindows
      ? r'C:\Users\Public\Documents\deezapp\downloads'
      : '${Platform.environment['HOME']}/deezapp/downloads';
  final String logsFilePath = Platform.isWindows
      ? r'C:\Users\Public\Documents\deezapp\logs/logs.txt'
      : '${Platform.environment['HOME']}/deezapp/logs/logs.txt';

  final availableFiles = transferService.getAvailableFiles(downloadFilePath);

  if (!availableFiles.contains(selectedItem)) {
    _showMessage('An Error occured while downloading the $selectedItem');
    _showMessage('Check the $logsFilePath or the logs panel for more information');

  }
}


void _showMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => _handleSend(extractIpAddress(widget.peer), 9091),
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
          ? const Center(child: Text('No files or directories available'))
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
                        print('current dir: $currentFilePath');
                      },
                      onDoubleTap: () {
                        if (isDirectory) {
                          final newPath = constructFilePath(currentFilePath, name);
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
    );
  }
}
