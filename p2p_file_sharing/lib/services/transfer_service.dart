import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_file_sharing/screens/home.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:p2p_file_sharing/utils/notificatioItem.dart';
import 'package:udp/udp.dart';
import 'package:path/path.dart' as path;

import 'dart:async';

List<NotificationItem> notifications = [];
int notificationCount = notifications.length;

class TransferService {
  static const int chunkSize = 8192; // 8kb chunks
  static const int metadataPort = 8080; // Port for sending metadata
  static const int dataPort = 8889; // Port for sending actual file data
  static const int directoryPort = 7070; // Port for directory request
  static const int fileRequestPort = 9000;
  final Logger logger = Logger();
  final StreamController<List<NotificationItem>> _notificationStreamController =
      StreamController.broadcast();
  final StreamController<int> _notifCountStreamController =
      StreamController.broadcast();

  late List<String> currentPath;
  late Map<String, dynamic> currentDirectory;
  late String currentDirectoryPath;
  String errorMessage = '';

  Stream<List<NotificationItem>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<int> get notifCountStram => _notifCountStreamController.stream;

  TransferService();

  TransferService._();

  static Future<TransferService> create() async {
    final service = TransferService._();
    String path = await service.getOrCreateDirectoryPath();
    service.listenForDirectoryRequests(directoryPort, path);
    service.listenForFileRequests(fileRequestPort);
    service.startFileReceiver();
    return service;
  }

  /// Get or create the directory path based on the platform
  Future<String> getOrCreateDirectoryPath() async {
    String directoryPath;

    if (Platform.isWindows) {
      directoryPath = 'C:\\Users\\Public\\Documents\\deezapp\\shared\\';
    } else if (Platform.isLinux || Platform.isMacOS) {
      directoryPath = '${Platform.environment['HOME']}/deezapp/shared/';
    } else {
      throw UnsupportedError('Unsupported operating system');
    }

    final Directory directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      logger.logMessage(message: 'Created directory: $directoryPath');
    } else {
      logger.logMessage(message: 'Directory already exists: $directoryPath');
    }

    return directoryPath;
  }

  /// Upload a file to a peer
  Future<String> uploadFile(String peerIP, int peer, String fileName) async {
    final file = File(fileName);
    if (!(await file.exists())) {
      logger.logMessage(message: "[ERROR] File $fileName does not exist.");
      return jsonEncode({
        'status': 'error',
        'message': "[ERROR] File '${path.basename(fileName)}' does not exist."
      });
    }

    final fileSize = await file.length();
    final udpSocket = await UDP.bind(Endpoint.any());

    logger.logMessage(message: '[INFO] Connected to UDP socket for sending...');

    // Send file metadata
    final metadata = {
      'fileName': file.uri.pathSegments.last,
      'fileSize': fileSize,
    };

    final metadataPacket = utf8.encode(jsonEncode(metadata));
    await udpSocket.send(
      metadataPacket,
      Endpoint.unicast(
        InternetAddress(peerIP),
        port: Port(metadataPort),
      ),
    );

    logger.logMessage(message: '[INFO] Metadata sent: $metadata');

    // Send file data in chunks
    final fileStream = file.openRead();
    int sequenceNumber = 0;

    await for (final chunk in fileStream) {
      final chunkPacket = {
        'seq': sequenceNumber,
        'data': base64Encode(chunk),
      };

      await udpSocket.send(
        utf8.encode(jsonEncode(chunkPacket)),
        Endpoint.unicast(
          InternetAddress(peerIP),
          port: Port(dataPort),
        ),
      );

      logger.logMessage(
        message:
            "[INFO] Sent chunk $sequenceNumber of size ${chunk.length} bytes.",
      );
      sequenceNumber++;
    }

    // Send completion signal
    final completionPacket = utf8.encode(jsonEncode({'done': true}));
    await udpSocket.send(
      completionPacket,
      Endpoint.unicast(
        InternetAddress(peerIP),
        port: Port(dataPort),
      ),
    );

    logger.logMessage(message: '[INFO] File transfer completed.');
    udpSocket.close();
    return jsonEncode({
      'status': 'error',
      'message': "Transfer of file '${path.basename(fileName)}' completed."
    });
  }

  /// Download a file from a peer and save it in the appropriate directory
  Future<String> downloadFile() async {
    // Determine save directory based on the platform
    String saveDirectory;
    if (Platform.isWindows) {
      saveDirectory = r'C:\Users\Public\Documents\deezapp\downloads';
    } else if (Platform.isLinux || Platform.isMacOS) {
      saveDirectory = '${Platform.environment['HOME']}/deezapp/downloads';
    } else {
      logger.logMessage(message: '[ERROR] Unsupported operating system');
      return jsonEncode(
          {'status': 'error', 'message': 'Unsupported operating system'});
    }

    try {
      // Ensure the save directory exists
      final Directory directory = Directory(saveDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Metadata and data sockets
      final metadataSocket =
          await UDP.bind(Endpoint.any(port: const Port(metadataPort)));
      final dataSocket =
          await UDP.bind(Endpoint.any(port: const Port(dataPort)));

      final fileChunks = <int, List<int>>{};
      String? fileName;
      int? fileSize;

      logger.logMessage(
        message:
            '[INFO] Listening for incoming file on metadata and data ports...',
      );

      // Listen for metadata
      metadataSocket.asStream().listen((datagram) {
        if (datagram != null) {
          try {
            final metadata = jsonDecode(utf8.decode(datagram.data));
            fileName = metadata['fileName'];
            fileSize = metadata['fileSize'];

            logger.logMessage(
              message: '[INFO] Receiving file: $fileName ($fileSize bytes)',
            );
          } catch (e) {
            logger.logMessage(message: '[ERROR] Failed to parse metadata: $e');
          }
        }
      });

      // Listen for file data
      await for (final datagram in dataSocket.asStream()) {
        if (datagram != null) {
          try {
            final packet = jsonDecode(utf8.decode(datagram.data));

            if (packet.containsKey('seq') && packet.containsKey('data')) {
              final sequenceNumber = packet['seq'];
              final chunkData = base64Decode(packet['data']);

              fileChunks[sequenceNumber] = chunkData;
              logger.logMessage(
                message:
                    '[INFO] Received chunk $sequenceNumber of size ${chunkData.length} bytes.',
              );
            } else if (packet.containsKey('done') && packet['done'] == true) {
              logger.logMessage(
                  message:
                      '[INFO] File transfer completed. Assembling file...');

              if (fileName != null) {
                final file = File('$saveDirectory/$fileName');
                final sortedChunks = fileChunks.keys.toList()..sort();

                final output = file.openWrite();
                for (final seq in sortedChunks) {
                  output.add(fileChunks[seq]!);
                }
                await output.close();

                logger.logMessage(
                    message: '[INFO] File savedddd to ${file.path}');

                metadataSocket.close();
                dataSocket.close();
                //_notifyNotificationsUpdate();
                return jsonEncode({
                  'status': 'success',
                  'message': 'File downloaded',
                  'filePath': file.path
                });
              } else {
                logger.logMessage(
                    message: '[ERROR] Metadata missing. Unable to save file.');
                metadataSocket.close();
                dataSocket.close();
                return jsonEncode({
                  'status': 'error',
                  'message': 'Metadata missing, file not saved'
                });
              }
            }
          } catch (e) {
            logger.logMessage(
                message: '[ERROR] Error while processing data packet: $e');
            return jsonEncode({
              'status': 'error',
              'message': 'Failed to download file',
              'details': e.toString()
            });
          }
        }
      }
    } catch (e) {
      logger.logMessage(
          message: '[ERROR] Error occurred during file download: $e');
      return jsonEncode({
        'status': 'error',
        'message': 'Failed to download file',
        'details': e.toString()
      });
    }
    return jsonEncode(
        {'status': 'error', 'message': 'Unexpected error occurred'});
  }

  /// Advertise available files
  Future<void> advertiseFiles(List<String> availableFiles, int port) async {
    final udpSocket = await UDP.bind(Endpoint.any());

    final message = jsonEncode({
      'peerName': Platform.localHostname,
      'files': availableFiles,
    });

    Timer.periodic(const Duration(seconds: 5), (_) {
      udpSocket.send(
        Uint8List.fromList(utf8.encode(message)),
        Endpoint.broadcast(port: Port(port)),
      );
    });

    logger.logMessage(message: '[INFO] Advertising files: $availableFiles');
  }

  /// Request a file from a peer
  Future<void> requestFile(String peerIP, int peerPort, String fileName) async {
    final udpSocket = await UDP.bind(Endpoint.any());

    final message = jsonEncode({
      'requestType': 'download',
      'fileName': fileName,
    });

    await udpSocket.send(
      Uint8List.fromList(utf8.encode(message)),
      Endpoint.unicast(InternetAddress(peerIP), port: Port(peerPort)),
    );

    logger.logMessage(
      message: '[INFO] File request sent for $fileName to $peerIP:$peerPort',
    );
  }

  /// Handle incoming file requests
  void listenForFileRequests(int port) async {
    // Determine the shared folder path based on the OS
    final String sharedFolderPath = Platform.isWindows
        ? r'C:\Users\Public\Documents\deezapp\shared'
        : '${Platform.environment['HOME']}/deezapp/shared';

    // Create the UDP socket
    final udpSocket = await UDP.bind(Endpoint.any(port: Port(port)));
    print('shared $sharedFolderPath');

    logger.logMessage(
        message: '[INFO] Listening for file requests on port $port');

    udpSocket.asStream().listen((datagram) async {
      if (datagram != null) {
        try {
          final request = jsonDecode(utf8.decode(datagram.data));

          if (request['requestType'] == 'download') {
            final fileName = request['fileName'];

            // Fetch the list of available files dynamically
            final availableFiles = getAvailableFiles(sharedFolderPath);
            availableFiles.add(fileName);

            if (availableFiles.contains(fileName) &&
                !privatePaths.contains(fileName)) {
              logger.logMessage(
                message: '[INFO] File request received for $fileName',
              );

              // Proceed to upload the requested file
              await uploadFile(datagram.address.address, datagram.port,
                  '$sharedFolderPath/$fileName');
            } else {
              logger.logMessage(
                  message:
                      '[ERROR] Requested file $fileName not found, or has been made private by owner.');
            }
          }
        } catch (e) {
          logger.logMessage(message: '[ERROR] Failed to process request: $e');
        }
      }
    });
  }

  /// Helper function to get the list of files from a directory
  List<String> getAvailableFiles(String directoryPath) {
    try {
      final directory = Directory(directoryPath);

      if (directory.existsSync()) {
        // List all files in the directory
        return directory
            .listSync()
            .whereType<File>()
            .where((file) => !privatePaths.contains(file.path))
            .map((file) => file.path.split(Platform.pathSeparator).last)
            .toList();
      } else {
        logger.logMessage(
            message:
                '[WARNING] Shared directory does not exist: $directoryPath');
        return [];
      }
    } catch (e) {
      logger.logMessage(
          message: '[ERROR] Failed to list files in directory: $e');
      return [];
    }
  }

  /// Directory-specific features
  Future<void> sendDirectoryStructure(
      String peerIP, int peerPort, String directoryPath) async {
    final udpSocket = await UDP.bind(Endpoint.any());
    final directoryStructure = await getDirectoryStructure(directoryPath);

    final response = jsonEncode({
      'type': 'directory',
      'structure': directoryStructure,
    });

    await udpSocket.send(
      Uint8List.fromList(utf8.encode(response)),
      Endpoint.unicast(
        InternetAddress(peerIP),
        port: Port(peerPort),
      ),
    );

    logger.logMessage(
        message: '[INFO] Sent directory structure to $peerIP:$peerPort.');
    udpSocket.close();
  }

  Future<Map<String, dynamic>> getDirectoryStructure(String path) async {
    final Directory dir = Directory(path);
    final directoryMap = <String, dynamic>{};

    if (await dir.exists()) {
      final entities = await dir.list().toList();
      for (var entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;

        if (!privatePaths.contains(entity.path)) {
          if (entity is Directory) {
            directoryMap[name] = await getDirectoryStructure(entity.path);
          } else if (entity is File) {
            directoryMap[name] = null; // Mark as file
          }
        }
      }
    } else {
      logger.logMessage(message: '[ERROR] Directory not found: $path');
    }
    return directoryMap;
  }

  void listenForDirectoryRequests(int port, String directoryPath) async {
    final udpSocket = await UDP.bind(Endpoint.any(port: Port(port)));

    logger.logMessage(
        message: '[INFO] Listening for directory requests on port $port.');

    udpSocket.asStream().listen((datagram) async {
      if (datagram != null) {
        final request = jsonDecode(utf8.decode(datagram.data));

        if (request['type'] == 'directoryRequest') {
          await sendDirectoryStructure(
            datagram.address.address,
            datagram.port,
            directoryPath,
          );
        }
      }
    });
  }

  Future<void> requestDirectoryStructure(String peerIP, int peerPort,
      Function(Map<String, dynamic>) onSuccess) async {
    final udpSocket = await UDP.bind(Endpoint.any());
    final request = {'type': 'directoryRequest'};

    await udpSocket.send(
      Uint8List.fromList(utf8.encode(jsonEncode(request))),
      Endpoint.unicast(InternetAddress(peerIP), port: Port(peerPort)),
    );

    logger.logMessage(
        message:
            '[INFO] Sent directory structure request to $peerIP:$peerPort.');

    udpSocket.asStream().listen((datagram) {
      if (datagram != null) {
        final response = jsonDecode(utf8.decode(datagram.data));
        if (response['type'] == 'directory') {
          final structure = response['structure'] as Map<String, dynamic>;
          onSuccess(structure);
        }
      }
    });
  }

  Future<String> startFileReceiver() async {
    String saveDirectory;
    if (Platform.isWindows) {
      saveDirectory = r'C:\Users\Public\Documents\deezapp\downloads';
    } else if (Platform.isLinux || Platform.isMacOS) {
      saveDirectory = '${Platform.environment['HOME']}/deezapp/downloads';
    } else {
      logger.logMessage(message: '[ERROR] Unsupported operating system');
      return jsonEncode(
          {'status': 'error', 'message': 'Unsupported operating system'});
    }

    try {
      // Ensure the save directory exists
      final Directory directory = Directory(saveDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Metadata and data sockets
      final metadataSocket =
          await UDP.bind(Endpoint.any(port: const Port(metadataPort)));
      final dataSocket =
          await UDP.bind(Endpoint.any(port: const Port(dataPort)));

      final fileChunks = <int, List<int>>{};
      String? fileName;
      int? fileSize;
      String? senderIp;

      logger.logMessage(
        message:
            '[INFO] Listening for incoming file on metadata and data ports...',
      );

      // Listen for metadata
      metadataSocket.asStream().listen((datagram) {
        if (datagram != null) {
          try {
            final metadata = jsonDecode(utf8.decode(datagram.data));
            fileName = metadata['fileName'];
            fileSize = metadata['fileSize'];
            senderIp = datagram.address.address;

            logger.logMessage(
              message:
                  '[INFO] Receiving file: $fileName ($fileSize bytes) from $senderIp',
            );

          } catch (e) {
            logger.logMessage(message: '[ERROR] Failed to parse metadata: $e');
          }
        }
      });

      // Listen for file data
      await for (final datagram in dataSocket.asStream()) {
        if (datagram != null) {
          try {
            final packet = jsonDecode(utf8.decode(datagram.data));

            if (packet.containsKey('seq') && packet.containsKey('data')) {
              final sequenceNumber = packet['seq'];
              final chunkData = base64Decode(packet['data']);

              fileChunks[sequenceNumber] = chunkData;
              logger.logMessage(
                message:
                    '[INFO] Received chunk $sequenceNumber of size ${chunkData.length} bytes.',
              );
            } else if (packet.containsKey('done') && packet['done'] == true) {
              logger.logMessage(
                  message:
                      '[INFO] File transfer completed. Assembling file...');

              if (fileName != null) {
                final file = File('$saveDirectory/$fileName');
                final sortedChunks = fileChunks.keys.toList()..sort();

                final output = file.openWrite();
                for (final seq in sortedChunks) {
                  output.add(fileChunks[seq]!);
                }
                await output.close();

                logger.logMessage(message: '[INFO] File saved to ${file.path}');
                metadataSocket.close();
                dataSocket.close();
                notifications.add(NotificationItem(
                    "You have received a file named $fileName from $senderIp"));
                return jsonEncode({
                  'status': 'success',
                  'message': 'File downloaded',
                  'filePath': file.path
                });
              } else {
                logger.logMessage(
                    message: '[ERROR] Metadata missing. Unable to save file.');
                metadataSocket.close();
                dataSocket.close();
                return jsonEncode({
                  'status': 'error',
                  'message': 'Metadata missing, file not saved'
                });
              }
            }
          } catch (e) {
            logger.logMessage(
                message: '[ERROR] Error while processing data packet: $e');
            return jsonEncode({
              'status': 'error',
              'message': 'Failed to download file',
              'details': e.toString()
            });
          }
        }
      }
    } catch (e) {
      logger.logMessage(
          message: '[ERROR] Error occurred during file download: $e');
      return jsonEncode({
        'status': 'error',
        'message': 'Failed to download file',
        'details': e.toString()
      });
    }
    return jsonEncode(
        {'status': 'error', 'message': 'Unexpected error occurred'});
  }
}


/*
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:udp/udp.dart';

class TransferService {
  static const int chunkSize = 8192; // 8kb chunks
  static const int metadataPort = 8080; // Port for sending metadata
  static const int dataPort = 8889; // Port for sending actual file data
  final Logger logger = Logger();
   late List<String> currentPath;
  late Map<String, dynamic> currentDirectory;
  late String currentDirectoryPath;
  String errorMessage = '';


  /// Upload a file to a peer
  Future<void> uploadFile(String peerIP, int peerPort, String fileName) async {
    final file = File(fileName);
    if (!(await file.exists())) {
      logger.logMessage(
        message: "[ERROR] File $fileName does not exist.",
      );
      return;
    }

    final fileSize = await file.length();
    final udpSocket = await UDP.bind(Endpoint.any());

    logger.logMessage(
      message: '[INFO] Connected to UDP socket for sending...',
    );

    // Send file metadata
    final metadata = {
      'fileName': file.uri.pathSegments.last,
      'fileSize': fileSize,
    };

    final metadataPacket = utf8.encode(jsonEncode(metadata));
    await udpSocket.send(
      metadataPacket,
      Endpoint.unicast(
        InternetAddress(peerIP),
        port: Port(metadataPort),
      ),
    );

    logger.logMessage(message: '[INFO] Metadata sent: $metadata');

    // Send file data in chunks
    final fileStream = file.openRead();
    int sequenceNumber = 0;

    await for (final chunk in fileStream) {
      final chunkPacket = {
        'seq': sequenceNumber,
        'data': base64Encode(chunk),
      };

      await udpSocket.send(
        utf8.encode(jsonEncode(chunkPacket)),
        Endpoint.unicast(
          InternetAddress(peerIP),
          port: Port(dataPort),
        ),
      );
      logger.logMessage(
        message:
            "[INFO] Sent chunk $sequenceNumber of size ${chunk.length} bytes.",
      );
      sequenceNumber++;
    }

    // Send completion signal
    final completionPacket = utf8.encode(jsonEncode({'done': true}));
    await udpSocket.send(
      completionPacket,
      Endpoint.unicast(
        InternetAddress(peerIP),
        port: Port(dataPort),
      ),
    );
    logger.logMessage(message: '[INFO] File transfer completed.');

    udpSocket.close();
  }

  /// Download a file from a peer
  Future<void> downloadFile(String saveDirectory) async {
    final metadataSocket =
        await UDP.bind(Endpoint.any(port: const Port(metadataPort)));
    final dataSocket = await UDP.bind(Endpoint.any(port: const Port(dataPort)));

    final fileChunks = <int, List<int>>{};
    String? fileName;
    int? fileSize;

    logger.logMessage(
      message:
          '[INFO] Listening for incoming file on metadata port $metadataPort and data port $dataPort...',
    );

    // Listen for metadata
    metadataSocket.asStream().listen((datagram) {
      if (datagram != null) {
        final metadata = jsonDecode(utf8.decode(datagram.data));

        if (metadata.containsKey('fileName') &&
            metadata.containsKey('fileSize')) {
          fileName = metadata['fileName'];
          fileSize = metadata['fileSize'];

          logger.logMessage(
            message: '[INFO] Receiving file: $fileName ($fileSize bytes)',
          );
        }
      }
    });

    // Listen for file data
    dataSocket.asStream().listen((datagram) async {
      if (datagram != null) {
        final packet = jsonDecode(utf8.decode(datagram.data));

        if (packet.containsKey('seq') && packet.containsKey('data')) {
          final sequenceNumber = packet['seq'];
          final chunkData = base64Decode(packet['data']);

          fileChunks[sequenceNumber] = chunkData;
          logger.logMessage(
            message:
                '[INFO] Received chunk $sequenceNumber of size ${chunkData.length} bytes.',
          );
        } else if (packet.containsKey('done') && packet['done'] == true) {
          logger.logMessage(
            message: '[INFO] File transfer completed. Assembling file...',
          );

          if (fileName != null && fileSize != null) {
            final file = File('$saveDirectory/$fileName');
            final sortedChunks = fileChunks.keys.toList()..sort();

            final output = file.openWrite();
            for (final seq in sortedChunks) {
              output.add(fileChunks[seq]!);
            }
            await output.close();

            logger.logMessage(
              message: '[INFO] File saved to ${file.path}',
            );
          } else {
            logger.logMessage(
              message: '[ERROR] Metadata missing. Unable to save file.',
            );
          }
          metadataSocket.close();
          dataSocket.close();
        }
      }
    });
  }

  Future<void> advertiseFiles(List<String> availableFiles, int port) async {
    final udpSocket = await UDP.bind(Endpoint.any());

    final message = jsonEncode({
      'peerName': Platform.localHostname,
      'files': availableFiles,
    });

    Timer.periodic(const Duration(seconds: 5), (_) {
      udpSocket.send(
        Uint8List.fromList(utf8.encode(message)),
        Endpoint.broadcast(port: Port(port)),
      );
    });

    logger.logMessage(
      message: '[INFO] Advertising files: $availableFiles',
    );
  }

  Future<void> requestFile(String peerIP, int peerPort, String fileName) async {
    final udpSocket = await UDP.bind(Endpoint.any());

    final message = jsonEncode({
      'requestType': 'download',
      'fileName': fileName,
    });

    await udpSocket.send(
      Uint8List.fromList(utf8.encode(message)),
      Endpoint.unicast(InternetAddress(peerIP), port: Port(peerPort)),
    );

    logger.logMessage(
      message: '[INFO] File request sent for $fileName to $peerIP:$peerPort',
    );
  }

  void listenForFileRequests(int port, List<String> availableFiles) async {
    final udpSocket = await UDP.bind(Endpoint.any(port: Port(port)));

    logger.logMessage(
      message: '[INFO] Listening for file requests on port $port',
    );

    udpSocket.asStream().listen((datagram) async {
      if (datagram != null) {
        try {
          final request = jsonDecode(utf8.decode(datagram.data));

          if (request['requestType'] == 'download') {
            final fileName = request['fileName'];

            if (availableFiles.contains(fileName)) {
              logger.logMessage(
                message: '[INFO] File request received for $fileName',
              );

              // Proceed to upload the requested file
              await uploadFile(
                  datagram.address.address, datagram.port, fileName);
            } else {
              logger.logMessage(
                message: '[ERROR] Requested file $fileName not found.',
              );
            }
          }
        } catch (e) {
          logger.logMessage(
            message: '[ERROR] Failed to process request: $e',
          );
        }
      }
    });
  }
}
*/
