import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:caloriewise/survey/dropdown.dart';
import 'package:caloriewise/main_component/colors.dart';

class EditProfile extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int accountId;

  const EditProfile({
    super.key,
    required this.userData,
    required this.accountId,
  });

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController nameController;
  late TextEditingController ageController;
  late TextEditingController weightController;
  late TextEditingController heightController;
  late String selectedGoal;
  late String selectedActivityLevel;
  late String exerciseRecommend;
  late String exerciseIntensity;
  late String exerciseAmount;

  final List<String> goalOptions = ['Gain', 'Loss', 'Maintain'];
  final List<String> activityOptions = [
    'Sedentary',
    'Light',
    'Moderate',
    'Active',
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with user data
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    ageController = TextEditingController(
      text: widget.userData['age']?.toString() ?? '',
    );
    weightController = TextEditingController(
      text: widget.userData['weight']?.toString() ?? '',
    );
    heightController = TextEditingController(
      text: widget.userData['height']?.toString() ?? '',
    );

    // Initialize dropdown values
    selectedGoal = widget.userData['goal'] ?? goalOptions.first;
    selectedActivityLevel =
        widget.userData['activity_level'] ?? activityOptions.first;
    exerciseRecommend =
        _matchDropdownValue(widget.userData['exercise_recommendation'], [
          'Yes',
          'No',
        ]) ??
        'No';
    exerciseIntensity =
        _matchDropdownValue(widget.userData['exercise_intensity'], [
          'Light',
          'Moderate',
          'High',
        ]) ??
        'Light';
    exerciseAmount =
        _matchDropdownValue(widget.userData['exercise_amount'], [
          'Less',
          'Moderate',
          'More',
        ]) ??
        'Less';
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'user_id': widget.userData['id'],
        'account_id': widget.accountId,
        'name': nameController.text,
        'age': int.tryParse(ageController.text),
        'weight': double.tryParse(weightController.text),
        'height': double.tryParse(heightController.text),
        'goal': selectedGoal.toLowerCase(),
        'activity_level': selectedActivityLevel.toLowerCase(),
        'exercise_recommendation': exerciseRecommend.toLowerCase(),
        'exercise_intensity':
            exerciseRecommend == 'Yes' ? exerciseIntensity.toLowerCase() : null,
        'exercise_amount':
            exerciseRecommend == 'Yes' ? exerciseAmount.toLowerCase() : null,
      };

      // Remove null values
      updatedData.removeWhere((key, value) => value == null);

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/profile/update_profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedData),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        Navigator.pop(context, {
          'user': responseData['user'],
          'metrics': responseData['metrics'],
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row with title and close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Edit Profile",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form fields
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (cm)'),
            ),
            const SizedBox(height: 20),

            // Dropdown fields
            DropdownField(
              label: "Goal",
              items: goalOptions,
              initialValue: selectedGoal,
              onChanged: (value) => setState(() => selectedGoal = value),
            ),
            const SizedBox(height: 20),
            DropdownField(
              label: "Activity Level",
              items: activityOptions,
              initialValue: selectedActivityLevel,
              onChanged:
                  (value) => setState(() => selectedActivityLevel = value),
            ),
            const SizedBox(height: 30),

            // Conditional exercise dropdowns
            DropdownField(
              label: 'Need exercise recommendation?',
              items: ['Yes', 'No'],
              initialValue: exerciseRecommend,
              onChanged: (value) => setState(() => exerciseRecommend = value),
            ),
            const SizedBox(height: 20),
            if (exerciseRecommend == 'Yes') ...[
              const SizedBox(height: 20),
              DropdownField(
                label: 'Preferred intensity level:',
                items: ['Light', 'Moderate', 'High'],
                initialValue: exerciseIntensity,
                onChanged: (value) => setState(() => exerciseIntensity = value),
              ),
              const SizedBox(height: 20),
              DropdownField(
                label: 'Preferred exercise amount:',
                items: ['Less', 'Moderate', 'More'],
                initialValue: exerciseAmount,
                onChanged: (value) => setState(() => exerciseAmount = value),
              ),
              const SizedBox(height: 20),
            ],

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        "Save",
                        style: TextStyle(color: Colors.white),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  String? _matchDropdownValue(
    String? backendValue,
    List<String> dropdownItems,
  ) {
    if (backendValue == null) return null;
    return dropdownItems.firstWhere(
      (item) => item.toLowerCase() == backendValue.toLowerCase(),
      orElse: () => dropdownItems.first,
    );
  }
}
