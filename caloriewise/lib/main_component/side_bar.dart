import 'package:flutter/material.dart';
import 'package:caloriewise/profile/profile.dart';
import 'package:caloriewise/login_register/login_screen.dart';

class SideBar extends StatelessWidget {
  const SideBar({super.key, required this.accountId});
  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      semanticLabel: 'Menu',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 210, // Adjust height as needed
            padding: const EdgeInsets.only(top: 40.0),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 217, 215, 255),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const [
                Text(
                  'Menu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/images/profile.jpg'),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),

          const SizedBox(height: 20),
          ListTile(
            title: const Text('Profile', textAlign: TextAlign.center),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(accountId: accountId),
                ),
              );
            },
          ),

          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: SizedBox(
                width: 180,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 217, 215, 255),
                    foregroundColor: const Color.fromARGB(255, 88, 83, 193),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        20,
                      ), // Softer pill shape
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text("Log Out"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
