import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/screens/home.dart';
import 'package:p2p_file_sharing/widgets/peer_file_explorer_screen.dart';

void main() {
  runApp(const FileTransferapp());
}

class FileTransferapp extends StatefulWidget {
  const FileTransferapp({super.key});

  @override
  State<FileTransferapp> createState() => _FileTransferappState();
}

class _FileTransferappState extends State<FileTransferapp> {
  ThemeMode themeMode = ThemeMode.system ; // default theme

  void changeThemeMode(bool useLightMode) {
    setState(() {
      themeMode = useLightMode ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P File Transfer',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: Home(changeTheme: changeThemeMode),
      //home: PeerFileExplorer(),
    );
  }
}

