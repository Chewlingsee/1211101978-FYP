import 'package:flutter/material.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  const NavBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 217, 215, 255),
      leading: IconButton(
        icon: const Icon(
          Icons.notifications,
          color: Colors.black,
        ), // Notification icon
        onPressed: () {
          // Handle notification icon press
        },
      ),
      title: const Text('CalorieWise', style: TextStyle(color: Colors.black)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.black), // Hamburger icon
          onPressed: () {
            Scaffold.of(context).openEndDrawer();
          },
        ),
      ],
      shape: const Border(bottom: BorderSide(color: Colors.black, width: 1.0)),
    );
  }
}
