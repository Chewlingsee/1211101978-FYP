import 'package:flutter/material.dart';

// Background widget with gradient
class ForgetBackground extends StatelessWidget {
  final Widget child; // The widget that will be placed inside the background

  const ForgetBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 234, 251, 255),
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 142, 182, 243),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child, // Place the passed widget here
    );
  }
}
