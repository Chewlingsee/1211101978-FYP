import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorkoutPlanTab extends StatefulWidget {
  final int accountId;

  const WorkoutPlanTab({super.key, required this.accountId});

  @override
  State<WorkoutPlanTab> createState() => _WorkoutPlanTabState();
}

class _WorkoutPlanTabState extends State<WorkoutPlanTab> {
  bool _loading = false;
  List<dynamic> _recommendations = [];
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
    await _fetchWorkoutHistory();

    // If no history exists, automatically generate a plan
    if (!_hasHistory && _userData != null && _userData!['id'] != null) {
      await generateWorkout(showPrompt: false);
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

  Future<void> _fetchWorkoutHistory() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/workout/history?account_id=${widget.accountId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _recommendations = data['recommendations'] ?? [];
          _hasHistory = _recommendations.isNotEmpty;

          // Extract end_date from data if available
          if (data.containsKey('end_date')) {
            _planEndDate = DateTime.tryParse(data['end_date']);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading workout history: $e')),
      );
    }
  }

  Future<void> generateWorkout({bool showPrompt = true}) async {
    if (_userData == null || _userData!['id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User data not loaded")));
      return;
    }

    // Show confirmation dialog if there's existing history and we're supposed to show prompt
    if (_hasHistory && showPrompt) {
      final shouldGenerate = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Existing Workout Plan"),
              content: const Text(
                "You already have a workout plan. Would you like to generate a new one?",
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
        return; // User cancelled
      }
    }

    setState(() {
      _loading = true;
      _recommendations = [];
      _message = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/workout/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account_id': widget.accountId,
          'user_id': _userData!['id'],
        }),
      );

      final data = jsonDecode(response.body);
      setState(() {
        _loading = false;
        _message = data['message'];
      });

      if (response.statusCode == 200) {
        if (data['no_recommendation'] == true) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text("Notice"),
                  content: Text(data['message']),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
          );
        } else {
          await _fetchWorkoutHistory();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Workout plan generated successfully."),
            ),
          );
        }
      } else {
        throw Exception(data['message']);
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
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (hasEnded) ...[
                    const Text(
                      'Your workout plan has ended. Please generate a new one.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => generateWorkout(showPrompt: false),
                      child: const Text("Generate New Plan"),
                    ),
                    const SizedBox(height: 20),
                  ] else if (_hasHistory) ...[
                    ElevatedButton(
                      onPressed: () => generateWorkout(showPrompt: true),
                      child: const Text("Generate Workout Plan"),
                    ),
                    const SizedBox(height: 20),
                    if (_recommendations.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          itemCount: _recommendations.length,
                          itemBuilder: (context, index) {
                            final workout = _recommendations[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Session ${workout['session_number']}: ${workout['workout_name']}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text("Type: ${workout['activity_type']}"),
                                    Text("Intensity: ${workout['intensity']}"),
                                    Text(
                                      "Duration: ${workout['minutes_per_session']} minutes",
                                    ),
                                    Text(
                                      "Calories: ${workout['calories_per_session']} kcal",
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],

                  if (_message != null && _recommendations.isEmpty)
                    Text(_message!, style: const TextStyle(color: Colors.grey)),
                ],
              ),
    );
  }
}
