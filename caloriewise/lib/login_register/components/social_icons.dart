import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocalIcon extends StatelessWidget {
  final String iconSrc; // Path to the icon
  final Function press; // Action to perform when pressed

  const SocalIcon({super.key, required this.iconSrc, required this.press});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => press(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              spreadRadius: 2,
              blurRadius: 2,
            ),
          ],
        ),
        child: SvgPicture.asset(
          iconSrc, // Path to SVG icon
          height: 40,
          width: 40,
        ),
      ),
    );
  }
}
