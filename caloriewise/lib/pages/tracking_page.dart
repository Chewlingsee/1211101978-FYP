import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'package:caloriewise/main_component/nav.dart';
import 'package:caloriewise/main_component/side_bar.dart';
import 'package:caloriewise/pages/tracking/barchart.dart';
import 'package:caloriewise/pages/tracking/update_weight.dart';
import 'package:caloriewise/pages/tracking/weight_line.dart';
import 'package:intl/intl.dart';

class TrackingPage extends StatefulWidget {
  final int accountId;
  const TrackingPage({super.key, required this.accountId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  List<Map<String, dynamic>> _logs = [];
  double _targetCalories = 2000;
  bool _loading = true;
  bool _hasData = false;
  List<Map<String, dynamic>> _weightLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchCalorieLog();
    _fetchWeightHistory();
  }

  Future<void> _fetchCalorieLog() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/diet/actual_logs?account_id=${widget.accountId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final logs = List<Map<String, dynamic>>.from(data['logs']);
        setState(() {
          _targetCalories = (data['target_calories'] as num).toDouble();
          _logs = logs;
          _hasData = logs.isNotEmpty;
          _loading = false;
        });
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      log("Error fetching log: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _submitWeight(double weight, DateTime date) async {
    try {
      final idResponse = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/profile/user_id?account_id=${widget.accountId}',
        ),
      );

      if (idResponse.statusCode != 200) {
        throw Exception("Unable to get user_id");
      }

      final userId = json.decode(idResponse.body)['user_id'];

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/tracking/update_weight'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'weight': weight,
          'date': DateFormat('yyyy-MM-dd').format(date),
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight updated successfully')),
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _fetchWeightHistory() async {
    final userIdResponse = await http.get(
      Uri.parse(
        'http://10.0.2.2:5000/profile/user_id?account_id=${widget.accountId}',
      ),
    );
    final userId = json.decode(userIdResponse.body)['user_id'];

    final response = await http.get(
      Uri.parse(
        'http://10.0.2.2:5000/tracking/get_weight_history?user_id=$userId',
      ),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _weightLogs = List<Map<String, dynamic>>.from(data['data']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      endDrawer: SideBar(accountId: widget.accountId),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _hasData
              ? SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Daily Actual Calorie Intake",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          color: Color.fromARGB(255, 247, 241, 255),
                          padding: const EdgeInsets.all(10.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: SizedBox(
                                width: _logs.length * 70,
                                height: 300,
                                child: CalorieBarChart(
                                  logs: _logs,
                                  targetCalories: _targetCalories,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      WeightInputCard(onSubmit: _submitWeight),
                      if (_weightLogs.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          "Weight Progress",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 200,
                          child: WeightLineChart(weightLogs: _weightLogs),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              : const Center(child: Text("No history found")),
    );
  }
}
