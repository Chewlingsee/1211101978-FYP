import 'package:flutter/material.dart';
import 'package:caloriewise/main_component/nav.dart';
import 'package:caloriewise/pages/plan/diet_plan.dart';
import 'package:caloriewise/pages/plan/workout_plan.dart';
import 'package:caloriewise/main_component/side_bar.dart';

class PlanPage extends StatefulWidget {
  final int accountId;

  const PlanPage({super.key, required this.accountId});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      endDrawer: SideBar(accountId: widget.accountId),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Diet Plan'), Tab(text: 'Workout Plan')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DietPlanTab(accountId: widget.accountId),
                WorkoutPlanTab(accountId: widget.accountId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
