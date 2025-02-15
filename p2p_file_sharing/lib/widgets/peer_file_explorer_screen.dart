import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/services/transfer_service.dart';
import 'package:path/path.dart' as path;

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
    currentFilePath = widget.paths;
    osType = _extractOsType(widget.peer);
    _initializeTransferService();
  }

  Future<void> _initializeTransferService() async {
    transferService = await TransferService.create();
  }

  String _extractIpAddress(String input) {
    return input.contains('@') ? input.split('@')[1] : input;
  }

  String _extractOsType(String input) {
    return input.contains(':') ? input.split(':')[0] : 'Unknown';
  }

  String _constructFilePath(String currentPath, String fileName) {
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
      return;
    }

    final fileName = _constructFilePath(currentFilePath, selectedItem!);
    final peerIP = _extractIpAddress(widget.peer);

    _showMessage('Requesting download for $fileName...');

    try {
      await transferService.requestFile(
          peerIP, TransferService.fileRequestPort, fileName);
      final response = await transferService.downloadFile();
      _handleDownloadResponse(response);
    } catch (e) {
      _showMessage('Failed to download $fileName: $e');
      print('Error occurred: $e');
    }
  }

  void _handleDownloadResponse(String response) {
    final feedback = jsonDecode(response);

    if (feedback['status'] == 'success') {
      final savedPath = feedback['filePath'];
      _showMessage('Download successful! File saved to: $savedPath');
      print('File downloaded to: $savedPath');
    } else {
      final errorMessage = feedback['status'] == 'error'
          ? feedback['message']
          : 'Unexpected response received.';
      _showMessage('Download failed: $errorMessage');
      print('Download response: $response');
    }
  }

  Future<void> _handleSend(String peerIp, int port) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.isNotEmpty) {
      sendFilePath = result.files.single.path;
      if (sendFilePath != null) {
        String filename = path.basename(sendFilePath!);
        _showMessage("Seding $filename to ${widget.peer}");
        await transferService.uploadFile(peerIp, port, sendFilePath!);
        _showMessage("File $filename sent successfully!");
      }
    } else {
      _showMessage("No file selected. Select a file to send");
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
        actions: _buildAppBarActions(),
      ),
      body: widget.directoryStructure.isEmpty
          ? const Center(child: Text('No files or directories available'))
          : _buildDirectoryList(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      _buildActionButton(
          'Download File', Icons.download, _handleDownload, Colors.blue),
      const SizedBox(width: 16),
      _buildActionButton(
          'Send File',
          Icons.send,
          () => _handleSend(_extractIpAddress(widget.peer), 9091),
          Colors.green),
      const SizedBox(width: 20),
    ];
  }

  ElevatedButton _buildActionButton(
      String label, IconData icon, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,

        elevation: 20.0,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 10.0),
          Icon(icon),
        ],
      ),
    );
  }

  Widget _buildDirectoryList() {
    return SingleChildScrollView(
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
                  final newPath = _constructFilePath(currentFilePath, name);
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
              child: _buildDirectoryItem(name, isDirectory, isSelected),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDirectoryItem(String name, bool isDirectory, bool isSelected) {
    return AnimatedContainer(
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
    );
  }
}
