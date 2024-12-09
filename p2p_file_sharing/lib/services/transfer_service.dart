import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:p2p_file_sharing/utils/logger.dart';
import 'package:udp/udp.dart';

class TransferService {
  static const int chunkSize = 8192; // 8kb chunks
  static const int metadataPort = 8080; // Port for sending metadata
  static const int dataPort = 8889; // Port for sending actual file data
  final Function(String)? onLog;
  final Logger logger = Logger();

  TransferService(this.onLog);

  /// Upload a file to a peer
  Future<void> uploadFile(String peerIP, int peerPort, String fileName) async {
    final file = File(fileName);
    if (!(await file.exists())) {
      logger.logMessage(
        message: "[ERROR] File $fileName does not exist.",
        onLog: onLog,
      );
      return;
    }

    final fileSize = await file.length();
    final udpSocket = await UDP.bind(Endpoint.any());

    logger.logMessage(
      message: '[INFO] Connected to UDP socket for sending...',
      onLog: onLog,
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

    logger.logMessage(message: '[INFO] Metadata sent: $metadata', onLog: onLog);

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
        onLog: onLog,
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
    logger.logMessage(message: '[INFO] File transfer completed.', onLog: onLog);

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
      onLog: onLog,
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
            onLog: onLog,
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
            onLog: onLog,
          );
        } else if (packet.containsKey('done') && packet['done'] == true) {
          logger.logMessage(
            message: '[INFO] File transfer completed. Assembling file...',
            onLog: onLog,
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
              onLog: onLog,
            );
          } else {
            logger.logMessage(
              message: '[ERROR] Metadata missing. Unable to save file.',
              onLog: onLog,
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
      onLog: onLog,
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
      onLog: onLog,
    );
  }

  void listenForFileRequests(int port, List<String> availableFiles) async {
    final udpSocket = await UDP.bind(Endpoint.any(port: Port(port)));

    logger.logMessage(
      message: '[INFO] Listening for file requests on port $port',
      onLog: onLog,
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
                onLog: onLog,
              );

              // Proceed to upload the requested file
              await uploadFile(
                  datagram.address.address, datagram.port, fileName);
            } else {
              logger.logMessage(
                message: '[ERROR] Requested file $fileName not found.',
                onLog: onLog,
              );
            }
          }
        } catch (e) {
          logger.logMessage(
            message: '[ERROR] Failed to process request: $e',
            onLog: onLog,
          );
        }
      }
    });
  }
}
