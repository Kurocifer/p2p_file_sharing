import 'package:flutter/material.dart';
import 'package:p2p_file_sharing/components/theme_button.dart';

class Home extends StatefulWidget {
  final void Function(bool useLightMode) changeTheme;

  const Home({
    super.key,
    required this.changeTheme,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 4.0,
      leading: const Icon(Icons.folder_outlined),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ThemeButton(
          changeThemeMode: widget.changeTheme,
        ),
        ],
      ),
    );
  }
}
