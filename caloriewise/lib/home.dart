import 'package:caloriewise/pages/image_page.dart';
import 'package:flutter/material.dart';
import 'package:caloriewise/pages/home_page.dart';
import 'package:caloriewise/pages/plan/plan_page.dart';
import 'package:caloriewise/pages/tracking_page.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class HomePage extends StatefulWidget {
  final int accountId;
  const HomePage({super.key, required this.accountId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int myIndex = 0;
  late final List<Widget> widgetList; // Remove const

  @override
  void initState() {
    super.initState();
    // Initialize widget list with the accountId
    widgetList = [
      HomeScreen(accountId: widget.accountId),
      PlanPage(accountId: widget.accountId),
      ImagePage(accountId: widget.accountId),
      TrackingPage(accountId: widget.accountId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widgetList[myIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
          child: GNav(
            backgroundColor: Colors.black,
            color: Colors.white,
            activeColor: Colors.white,
            tabBackgroundColor: Colors.grey.shade800,
            gap: 8,
            selectedIndex: myIndex,
            onTabChange: (index) {
              setState(() {
                myIndex = index;
              });
            },
            padding: const EdgeInsets.all(16),
            tabs: const [
              GButton(icon: Icons.home, text: 'Home'),
              GButton(icon: Icons.fastfood_rounded, text: 'Plans'),
              GButton(icon: Icons.camera, text: 'Upload'),
              GButton(icon: Icons.auto_graph, text: 'Tracking'),
            ],
          ),
        ),
      ),
    );
  }
}
