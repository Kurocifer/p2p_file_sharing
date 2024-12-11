import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

/*
class FileExplorer extends StatelessWidget {
  final Logger logger;
  final bool isCollapsed;

  const FileExplorer({
    super.key,
    required this.logger,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    // If collapsed, show an empty container or placeholder
    if (isCollapsed) {
      return Container(width: 0); // Collapsed state, hidden.
    }

    // Expanded state
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
*/


class FileExplorer extends StatefulWidget {
  final bool isCollapsed;

  const FileExplorer({
    super.key,
    required this.isCollapsed,
  });

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  late TreeViewController _controller;
  late String _rootDirectory;
  String? _selectedNodeKey;

  @override
  void initState() {
    super.initState();
    _rootDirectory = _getInitialDirectory();
    _loadDirectory(_rootDirectory);
  }

  String _getInitialDirectory() {
    if (Platform.isWindows) {
      return r'C:\Users\Public\Documents\deezapp';
    } else {
      final homeDirectory = Platform.environment['HOME'] ?? '/';
      return path.join(homeDirectory, 'deezapp', 'shared');
    }
  }

  void _loadDirectory(String directoryPath) {
    final rootNode = _createNodeFromDirectory(directoryPath);
    setState(() {
      _controller = TreeViewController(children: [rootNode]);
    });
  }

  Node _createNodeFromDirectory(String directoryPath) {
    final directory = Directory(directoryPath);

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final children = directory
        .listSync()
        .map((entity) {
          if (entity is Directory) {
            return _createNodeFromDirectory(entity.path);
          } else if (entity is File) {
            return Node(
              key: entity.path,
              label: path.basename(entity.path),
              data: {'type': 'file'},
            );
          }
          return null;
        })
        .whereType<Node>()
        .toList();

    return Node(
      key: directoryPath,
      label: path.basename(directoryPath),
      children: children,
      data: {'type': 'directory'},
      expanded: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCollapsed
        ? const SizedBox.shrink()
        : Material(
            elevation: 6.0,
            borderRadius: BorderRadius.circular(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: _selectFileToUpload,
                          icon: const Icon(Icons.upload_file),
                          label: const Text("Upload File"),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
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
                    padding: const EdgeInsets.all(8.0),
                    child: TreeView(
                      controller: _controller,
                      theme: TreeViewTheme(
                        expanderTheme: const ExpanderThemeData(
                          type: ExpanderType.none,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        parentLabelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        iconTheme: const IconThemeData(size: 20),
                      ),
                      nodeBuilder: (context, node) {
                        final isDirectory = node.data?['type'] == 'directory';
                        final isExpanded = node.expanded;

                        return GestureDetector(
                          onSecondaryTapDown: (details) => _showContextMenu(
                            context,
                            details.globalPosition,
                            node,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedNodeKey = node.key;
                              if (isDirectory) {
                                final updatedNode =
                                    node.copyWith(expanded: !isExpanded);
                                _controller = _controller.copyWith(
                                  children: _controller.updateNode(
                                      node.key, updatedNode),
                                );
                              }
                            });
                          },
                          child: Container(
                            color: _selectedNodeKey == node.key
                                ? Colors.blue.withOpacity(0.2)
                                : null,
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                if (isDirectory)
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_down_outlined
                                        : Icons.keyboard_arrow_right_outlined,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                Icon(
                                  isDirectory
                                      ? (isExpanded
                                          ? Icons.folder_open
                                          : Icons.folder)
                                      : Icons.insert_drive_file,
                                  color: isDirectory
                                      ? Colors.amber
                                      : Colors.blueGrey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    node.label,
                                    overflow: TextOverflow
                                        .ellipsis, // Prevents overflow by truncating
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  void _showContextMenu(
      BuildContext context, Offset position, Node node) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
          value: 'createFolder',
          child: Text('Create Folder'),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: Text('Rename'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete'),
        ),
      ],
    );

    if (result == 'createFolder') {
      _createFolder(context, node);
    } else if (result == 'rename') {
      _renameNode(context, node);
    } else if (result == 'delete') {
      _deleteNode(node);
    }
  }

  void _createFolder(BuildContext context, Node node) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Create Folder"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter folder name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final folderName = controller.text.trim();
                if (folderName.isNotEmpty) {
                  final parentPath = node.key;
                  final newFolderPath = path.join(parentPath, folderName);

                  try {
                    // Create the directory
                    Directory(newFolderPath).createSync();

                    // Update the tree view
                    setState(() {
                      final updatedNode = node.copyWith(
                        children: [
                          ...node.children,
                          Node(
                            key: newFolderPath,
                            label: folderName,
                            data: {'type': 'directory'},
                          ),
                        ],
                      );

                      _controller = _controller.copyWith(
                        children: _controller.updateNode(node.key, updatedNode),
                      );
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Folder "$folderName" created successfully.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating folder: $e')),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: const Text("Create"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _renameNode(BuildContext context, Node node) {
    final TextEditingController controller =
        TextEditingController(text: node.label);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final newName = controller.text;
                if (newName.isNotEmpty) {
                  final parentPath = path.dirname(node.key);
                  final newPath = path.join(parentPath, newName);
                  File(node.key).renameSync(newPath);

                  setState(() {
                    final updatedNode =
                        node.copyWith(key: newPath, label: newName);
                    _controller = _controller.copyWith(
                      children: _controller.updateNode(node.key, updatedNode),
                    );
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Rename"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _deleteNode(Node node) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete"),
          content: const Text("Are you sure you want to delete this file?"),
          actions: [
            TextButton(
              onPressed: () {
                File(node.key).deleteSync();

                setState(() {
                  _controller = _controller.copyWith(
                    children: _controller.deleteNode(node.key),
                  );
                });

                Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _selectFileToUpload() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.isNotEmpty) {
      final selectedFile = result.files.single;

      if (_selectedNodeKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a directory to upload the file.')),
        );
        return;
      }

      try {
        final selectedNode = _controller.getNode(_selectedNodeKey!);
        if (selectedNode == null || selectedNode.data?['type'] != 'directory') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Please select a valid directory to upload the file.')),
          );
          return;
        }

        final destinationPath = path.join(_selectedNodeKey!, selectedFile.name);

        File(selectedFile.path!).copySync(destinationPath);

        setState(() {
          final updatedNode = selectedNode.copyWith(
            children: [
              ...selectedNode.children,
              Node(
                key: destinationPath,
                label: selectedFile.name,
                data: {'type': 'file'},
              ),
            ],
          );

          _controller = _controller.copyWith(
            children: _controller.updateNode(_selectedNodeKey!, updatedNode),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('File "${selectedFile.name}" uploaded successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }
}
