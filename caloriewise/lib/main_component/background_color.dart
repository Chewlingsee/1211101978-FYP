import 'package:flutter/material.dart';

// Background widget with gradient
class BackgroundWidget extends StatelessWidget {
  final Widget child; // The widget that will be placed inside the background

  const BackgroundWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 1, 0, 73),
            Color.fromARGB(255, 0, 75, 136),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child, // Place the passed widget here
    );
  }
}
