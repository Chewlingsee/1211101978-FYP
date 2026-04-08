import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Add this import for date formatting

class DietPlanTab extends StatefulWidget {
  final int accountId;

  const DietPlanTab({super.key, required this.accountId});

  @override
  State<DietPlanTab> createState() => _DietPlanTabState();
}

class _DietPlanTabState extends State<DietPlanTab> {
  bool _loading = false;
  Map<String, dynamic>? _weeklyPlan;
  Map<String, dynamic>? _userData;
  String? _message;
  bool _hasHistory = false;
  DateTime? _planEndDate;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchUserId();
    await _fetchDietHistory();

    // If no history exists, automatically generate a plan
    if (!_hasHistory && _userData != null && _userData!['id'] != null) {
      await _generateDietPlan(showPrompt: false);
    }
  }

  Future<void> _fetchUserId() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/profile/user_id?account_id=${widget.accountId}',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch user ID');
      }

      final userId = json.decode(response.body)['user_id'];
      _userData = {'id': userId};
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user id: $e')));
    }
  }

  Future<void> _fetchDietHistory() async {
    try {
      setState(() {
        _loading = true;
      });
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/diet/history?user_id=${_userData!['id']}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _weeklyPlan = data['weekly_plan'];
          _hasHistory = _weeklyPlan != null && _weeklyPlan!.isNotEmpty;
          if (data['weekly_summary']?['end_date'] != null) {
            _planEndDate = DateTime.tryParse(
              data['weekly_summary']['end_date'],
            );
          } else {
            _planEndDate = null;
          }
          _loading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _hasHistory = false;
          _loading = false;
        });
      } else {
        throw Exception('Failed to load diet history: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _hasHistory = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading diet history: $e')));
    }
  }

  Future<void> _generateDietPlan({bool showPrompt = true}) async {
    if (_userData == null || _userData!['id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User data not loaded")));
      return;
    }

    if (_hasHistory && showPrompt) {
      final shouldGenerate = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Existing Diet Plan"),
              content: const Text(
                "You already have a diet plan. Would you like to generate a new one?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Generate New"),
                ),
              ],
            ),
      );

      if (shouldGenerate != true) {
        return;
      }
    }

    setState(() {
      _loading = true;
      _weeklyPlan = null;
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/generate_diet_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userData!['id']}),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _loading = false;
        _message = data['message'];
      });

      if (response.statusCode == 200) {
        setState(() {
          _weeklyPlan = data['weekly_plan'];
          _hasHistory = _weeklyPlan != null && _weeklyPlan!.isNotEmpty;
        });
        await _fetchDietHistory();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Diet plan generated successfully.")),
        );
      } else {
        throw Exception(data['error'] ?? 'Failed to generate diet plan');
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Error"),
              content: Text("Failed to generate plan: $e"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasEnded =
        _planEndDate != null &&
        DateTime.now().isAfter(
          DateTime(
            _planEndDate!.year,
            _planEndDate!.month,
            _planEndDate!.day,
            23,
            59,
            59,
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          _loading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "Please wait... your plan is generating...",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  if (hasEnded) ...[
                    const Text(
                      'Your diet plan has ended. Please generate a new one.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _generateDietPlan(showPrompt: false),
                      child: const Text("Generate New Plan"),
                    ),
                  ] else if (_hasHistory || _weeklyPlan == null)
                    ElevatedButton(
                      onPressed: () => _generateDietPlan(showPrompt: true),
                      child: const Text("Generate Diet Plan"),
                    ),
                  if (_hasHistory || _weeklyPlan == null)
                    const SizedBox(height: 20),
                  if (_weeklyPlan != null && _weeklyPlan!.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _weeklyPlan!.keys.length,
                        itemBuilder: (context, index) {
                          String dayKey = _weeklyPlan!.keys.elementAt(index);
                          Map<String, dynamic> dayData = _weeklyPlan![dayKey];
                          DateTime date = DateTime.parse(dayData['date']);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$dayKey (${DateFormat('yyyy-MM-dd').format(date)})",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...dayData['meals'].entries.map<Widget>((
                                    entry,
                                  ) {
                                    String mealType = entry.key;
                                    Map<String, dynamic> meal = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${mealType.replaceFirst(mealType[0], mealType[0].toUpperCase())}:",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            "  Recipe Name: ${meal['recipe_name']}",
                                          ),
                                          Text(
                                            "  Calories: ${meal['calories']?.toStringAsFixed(1)} kcal",
                                          ),
                                          Text(
                                            "  Fat: ${meal['fat']?.toStringAsFixed(1)} g",
                                          ),
                                          Text(
                                            "  Carbs: ${meal['carbs']?.toStringAsFixed(1)} g",
                                          ),
                                          Text(
                                            "  Protein: ${meal['protein']?.toStringAsFixed(1)} g",
                                          ),
                                          Text(
                                            "  Servings: ${meal['servings']?.toStringAsFixed(1)}",
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(),
                                  Text(
                                    "Daily Totals:",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "  Calories: ${dayData['totals']['calories']?.toStringAsFixed(1)} kcal",
                                  ),
                                  Text(
                                    "  Fat: ${dayData['totals']['fat']?.toStringAsFixed(1)} g",
                                  ),
                                  Text(
                                    "  Carbs: ${dayData['totals']['carbs']?.toStringAsFixed(1)} g",
                                  ),
                                  Text(
                                    "  Protein: ${dayData['totals']['protein']?.toStringAsFixed(1)} g",
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_message != null &&
                      (_weeklyPlan == null || _weeklyPlan!.isEmpty))
                    Text(_message!, style: const TextStyle(color: Colors.grey)),
                ],
              ),
    );
  }
}
