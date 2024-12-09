import 'package:flutter/material.dart';

class ThemeButton extends StatelessWidget {
  final Function changeThemeMode;
  
  const ThemeButton({super.key, required this.changeThemeMode});

  @override
  Widget build(BuildContext context) {
    final isBright = Theme.of(context).brightness == Brightness.light;


    return IconButton(
      tooltip: isBright ? 'switch to dark theme' : 'switch to light theme',
      icon: isBright
          ? const Icon(Icons.dark_mode_outlined)
          : const Icon(Icons.light_mode_outlined),
      onPressed: () => changeThemeMode(!isBright),
    );
  }
}