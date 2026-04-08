import 'package:flutter/material.dart';
import 'package:caloriewise/main_component/nav.dart';
import 'package:caloriewise/main_component/side_bar.dart';
import 'package:caloriewise/pages/homePage_component/nutrition_summary.dart';
import 'package:caloriewise/pages/homePage_component/today_meal.dart';
import 'package:caloriewise/pages/homePage_component/weekly_plan_remainder.dart';
import 'package:caloriewise/pages/homePage_component/weekly_exercise.dart';
import 'package:caloriewise/pages/plan/plan_page.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

class HomeScreen extends StatefulWidget {
  final int accountId;
  const HomeScreen({super.key, required this.accountId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _weeklyPlan;
  Map<String, dynamic>? _userData;
  bool _loading = false;
  final DateTime _today = DateTime.now();
  int _currentDayIndex = 0;
  Map<String, double> _dailyTargets = {};
  bool _loadingTargets = true;
  List<dynamic> _workoutRecommendations = [];
  Map<int, bool> _workoutStatus = {};
  final _finalizingPreviousDay = false;

  @override
  void initState() {
    super.initState();
    _fetchDietHistory();
  }

  Future<void> _addToIntake(Map<String, dynamic> recipe) async {
    if (!mounted) return;

    // Parse nutrition values
    final calories =
        double.tryParse(recipe['calories']?.toString() ?? '0') ?? 0;
    final fat = double.tryParse(recipe['fat']?.toString() ?? '0') ?? 0;
    final carbs = double.tryParse(recipe['carbs']?.toString() ?? '0') ?? 0;
    final protein = double.tryParse(recipe['protein']?.toString() ?? '0') ?? 0;

    // Optimistic UI update
    setState(() {
      if (_todayMeals != null) {
        _todayMeals!['totals'] ??= {
          'calories': 0.0,
          'fat': 0.0,
          'carbs': 0.0,
          'protein': 0.0,
        };

        _todayMeals!['totals']['calories'] += calories;
        _todayMeals!['totals']['fat'] += fat;
        _todayMeals!['totals']['carbs'] += carbs;
        _todayMeals!['totals']['protein'] += protein;
      }
    });

    try {
      final userId = _userData?['id'];
      if (userId == null) throw Exception('User ID not available');

      // Prepare the request body with all needed fields
      final requestBody = {
        'user_id': userId,
        'log_date': DateTime.now().toIso8601String().substring(0, 10),
        'calories': calories,
        'fat': fat,
        'carbs': carbs,
        'protein': protein,
        'recipe_id': recipe['recipe_id']?.toString(),
        'recipe_name': recipe['label']?.toString() ?? 'Custom Recipe',
        'servings': double.tryParse(recipe['servings']?.toString() ?? '1') ?? 1,
        'fiber': double.tryParse(recipe['fiber']?.toString() ?? '0') ?? 0,
        'sugars': double.tryParse(recipe['sugars']?.toString() ?? '0') ?? 0,
        'sodium': double.tryParse(recipe['sodium']?.toString() ?? '0') ?? 0,
      };

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/log_intake'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode != 200) {
        // Revert if failed
        if (mounted) {
          setState(() {
            if (_todayMeals != null) {
              _todayMeals!['totals']['calories'] -= calories;
              _todayMeals!['totals']['fat'] -= fat;
              _todayMeals!['totals']['carbs'] -= carbs;
              _todayMeals!['totals']['protein'] -= protein;
            }
          });
        }
        throw Exception('Failed to save intake: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
      rethrow;
    }
  }

  Future<void> _finalizePreviousDayFromServer() async {
    try {
      final now = DateTime.now();
      if (now.hour < 1) return; // Optional: skip if too early

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/finalize_previous_day'),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        log('Finalized previous day from server.');
      } else {
        log('Server failed to finalize: ${data['error']}');
      }
    } catch (e) {
      log('Error calling server finalization: $e');
    }
  }

  Future<void> _loadDailyTargets(DateTime date) async {
    final targets = await fetchDailyTargets(_userData?['id'] ?? '', date);
    if (targets != null) {
      setState(() {
        _dailyTargets = targets;
        _loadingTargets = false;
      });
    } else {
      setState(() => _loadingTargets = false);
    }
  }

  Future<void> _autoSubmitEndOfDay() async {
    if (_weeklyPlan == null || _weeklyPlan!.isEmpty) return;

    final dayKey = _weeklyPlan!.keys.elementAt(_currentDayIndex);
    final meals = _weeklyPlan![dayKey]['meals'] as Map<String, dynamic>;
    final dateStr = _weeklyPlan![dayKey]['date'];

    double totalCalories = 0;
    double totalFat = 0;
    double totalCarbs = 0;
    double totalProtein = 0;

    // Update status for every meal (completed or skipped)
    for (final entry in meals.entries) {
      final mealType = entry.key;
      final meal = entry.value;

      final bool completed = meal['status'] == 'completed';
      final statusToUpdate = completed ? 'completed' : 'skipped';

      try {
        final res = await http.post(
          Uri.parse('http://10.0.2.2:5000/diet/update-status'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': _userData!['id'],
            'date': dateStr,
            'meal_type': mealType,
            'status': statusToUpdate,
          }),
        );

        if (res.statusCode != 200) {
          log('Failed to update meal status for $mealType');
        }
      } catch (e) {
        log('Error updating meal status for $mealType: $e');
      }

      // Accumulate totals only for completed meals
      if (completed) {
        totalCalories += (meal['calories'] ?? 0).toDouble();
        totalFat += (meal['fat'] ?? 0).toDouble();
        totalCarbs += (meal['carbs'] ?? 0).toDouble();
        totalProtein += (meal['protein'] ?? 0).toDouble();
      }
    }

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/log_intake'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': _userData!['id'],
          'log_date': dateStr,
          'calories': totalCalories,
          'fat': totalFat,
          'carbs': totalCarbs,
          'protein': totalProtein,
        }),
      );

      if (res.statusCode == 200) {
        log('Daily intake logged successfully');
      } else {
        log('Failed to log daily intake');
      }
    } catch (e) {
      log('Error logging daily intake: $e');
    }
  }

  Future<void> _fetchDietHistory() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch only user_id
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
      await _finalizePreviousDayFromServer();

      // 2. Fetch diet history using user_id
      final dietResponse = await http.get(
        Uri.parse('http://10.0.2.2:5000/diet/history?user_id=$userId'),
      );

      if (dietResponse.statusCode != 200) {
        throw Exception('Failed to fetch diet history');
      }

      final data = json.decode(dietResponse.body);
      _weeklyPlan = data['weekly_plan'];

      // 3. Determine current day index
      _currentDayIndex = _getCurrentDayIndex();

      // 4. Initialize totals
      _weeklyPlan?.forEach((dayKey, dayData) {
        dayData['totals'] ??= {
          'calories': 0.0,
          'fat': 0.0,
          'carbs': 0.0,
          'protein': 0.0,
        };

        dayData['totals']['calories'] = 0.0;
        dayData['totals']['fat'] = 0.0;
        dayData['totals']['carbs'] = 0.0;
        dayData['totals']['protein'] = 0.0;

        (dayData['meals'] as Map<String, dynamic>?)?.forEach((_, meal) {
          if (meal['status'] == 'completed') {
            dayData['totals']['calories'] += (meal['calories'] ?? 0).toDouble();
            dayData['totals']['fat'] += (meal['fat'] ?? 0).toDouble();
            dayData['totals']['carbs'] += (meal['carbs'] ?? 0).toDouble();
            dayData['totals']['protein'] += (meal['protein'] ?? 0).toDouble();
          }
        });
      });

      // 5. Load daily targets & check for auto-submit
      if (_weeklyPlan != null && _weeklyPlan!.isNotEmpty) {
        final planDate = DateTime.parse(
          _weeklyPlan!.values.elementAt(_currentDayIndex)['date'],
        );
        await _loadDailyTargets(planDate);
        await _fetchWorkoutHistory();
        if (DateTime.now().isAfter(planDate)) {
          await _autoSubmitEndOfDay();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() => _loading = false);
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
          _workoutRecommendations = data['recommendations'] ?? [];
          _workoutStatus = {
            for (int i = 0; i < _workoutRecommendations.length; i++)
              i: _workoutRecommendations[i]['status'] == 'completed',
          };
        });
      }
    } catch (e) {
      log('Error loading workout history: $e');
    }
  }

  void _handleWorkoutStatusChanged(int index, bool isCompleted) async {
    final workout = _workoutRecommendations[index];
    final recommendationId = workout['recommendation_id'];
    final sessionNumber = workout['session_number'];

    if (recommendationId == null || sessionNumber == null) {
      log("Workout missing identifiers: $workout");
      return;
    }

    setState(() {
      _workoutStatus[index] = isCompleted;
    });

    try {
      await updateWorkoutStatus(
        accountId: widget.accountId,
        recommendationId: recommendationId,
        sessionNumber: sessionNumber,
        status: isCompleted ? 'completed' : 'skipped',
      );
    } catch (e) {
      // Revert if it failed
      if (!mounted) return;
      setState(() {
        _workoutStatus[index] = !isCompleted;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update workout status: $e')),
      );
    }
  }

  Future<void> updateWorkoutStatus({
    required int accountId,
    required int recommendationId,
    required int sessionNumber,
    required String status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/workout/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'account_id': accountId,
          'recommendation_id': recommendationId,
          'session_number': sessionNumber,
          'status': status,
          'completion_date':
              status == 'completed' ? DateTime.now().toIso8601String() : null,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update workout status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update workout status: $e');
    }
  }

  Future<void> _updateMealStatus(String mealType, bool completed) async {
    final dayKey = _weeklyPlan!.keys.elementAt(_currentDayIndex);
    final meal = _weeklyPlan![dayKey]['meals'][mealType];

    // Update UI instantly
    setState(() {
      final wasCompleted = meal['status'] == 'completed';
      if (wasCompleted != completed) {
        meal['status'] = completed ? 'completed' : 'skipping';

        double calories = (meal['calories'] ?? 0).toDouble();
        double fat = (meal['fat'] ?? 0).toDouble();
        double carbs = (meal['carbs'] ?? 0).toDouble();
        double protein = (meal['protein'] ?? 0).toDouble();

        // Adjust totals accordingly
        if (completed) {
          _weeklyPlan![dayKey]['totals']['calories'] =
              (_weeklyPlan![dayKey]['totals']['calories'] + calories).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['fat'] =
              (_weeklyPlan![dayKey]['totals']['fat'] + fat).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['carbs'] =
              (_weeklyPlan![dayKey]['totals']['carbs'] + carbs).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['protein'] =
              (_weeklyPlan![dayKey]['totals']['protein'] + protein).clamp(
                0,
                double.infinity,
              );
        } else {
          _weeklyPlan![dayKey]['totals']['calories'] =
              (_weeklyPlan![dayKey]['totals']['calories'] - calories).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['fat'] =
              (_weeklyPlan![dayKey]['totals']['fat'] - fat).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['carbs'] =
              (_weeklyPlan![dayKey]['totals']['carbs'] - carbs).clamp(
                0,
                double.infinity,
              );
          _weeklyPlan![dayKey]['totals']['protein'] =
              (_weeklyPlan![dayKey]['totals']['protein'] - protein).clamp(
                0,
                double.infinity,
              );
        }
      }
    });

    try {
      log(
        'Sending update: user_id=${_userData!['id']}, date=${_weeklyPlan![dayKey]['date']}, meal_type=$mealType, status=${completed ? 'completed' : 'skipping'}',
      );

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': _userData!['id'],
          'date': _weeklyPlan![dayKey]['date'],
          'meal_type': mealType,
          'status': completed ? 'completed' : 'skipped',
        }),
      );

      log('Response status: ${response.statusCode}');
      log('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update status on server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update meal status: $e')),
      );
    }
  }

  int _getCurrentDayIndex() {
    if (_weeklyPlan == null) return 0;

    for (int i = 0; i < _weeklyPlan!.keys.length; i++) {
      final dayKey = _weeklyPlan!.keys.elementAt(i);
      final dayDate = DateTime.parse(_weeklyPlan![dayKey]['date']);
      if (dayDate.year == _today.year &&
          dayDate.month == _today.month &&
          dayDate.day == _today.day) {
        return i;
      }
    }
    return 0;
  }

  Widget _buildInfoWithButton(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlanPage(accountId: widget.accountId),
                  ),
                );
              },
              child: const Text("Generate Plan"),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? get _todayMeals {
    if (_weeklyPlan == null || _weeklyPlan!.isEmpty) return null;
    final dayKey = _weeklyPlan!.keys.elementAt(_currentDayIndex);
    return _weeklyPlan![dayKey];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      endDrawer: SideBar(accountId: widget.accountId),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_loading || _finalizingPreviousDay) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weeklyPlan == null || _weeklyPlan!.isEmpty) {
      return _buildInfoWithButton("No history found. Please generate a plan.");
    }

    if (DateTime.now().isAfter(
      DateTime.parse(
        _weeklyPlan!.values.last['date'],
      ).add(const Duration(days: 1)),
    )) {
      return _buildInfoWithButton(
        "Your previous plan has ended, please regenerate a new plan.",
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDietHistory,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date Header
            Text(
              DateFormat('EEEE, d MMMM y').format(_today),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Nutrition Summary Card
            NutritionSummary(
              totals:
                  _todayMeals?['totals'] ??
                  {'calories': 0, 'fat': 0, 'carbs': 0, 'protein': 0},
              dailyTargets: _dailyTargets,
              loading: _loadingTargets,
            ),
            const SizedBox(height: 30),

            // Today's Meals Section
            TodaysMeals(
              todayMeals: _todayMeals,
              weeklyPlan: _weeklyPlan,
              currentDayIndex: _currentDayIndex,
              onMealStatusChanged: _updateMealStatus,
              onAddToIntake: _addToIntake,
            ),
            const SizedBox(height: 30),

            // Weekly Exercise
            WeeklyExercise(
              recommendations: _workoutRecommendations,
              completedStatus: _workoutStatus,
              onStatusChanged: _handleWorkoutStatusChanged,
            ),
            const SizedBox(height: 30),

            // Weekly Plan Reminder
            WeeklyPlanReminder(
              weeklyPlan: _weeklyPlan,
              today: _today,
              onGenerateNewPlan: _fetchDietHistory,
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>?> fetchDailyTargets(
    String userId,
    DateTime date,
  ) async {
    final url = Uri.parse(
      'http://10.0.2.2:5000/diet/user_daily_targets?user_id=$userId&date=${date.toIso8601String().substring(0, 10)}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'fat': (data['total_fat'] as num).toDouble(),
          'carbs': (data['total_carbs'] as num).toDouble(),
          'protein': (data['total_protein'] as num).toDouble(),
          'calories': (data['total_calories'] as num).toDouble(),
        };
      }
    } catch (e) {
      log('Error fetching daily targets: $e');
    }
    return null;
  }
}
