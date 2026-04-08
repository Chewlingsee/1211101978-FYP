import 'package:flutter/material.dart';
import 'package:caloriewise/survey/dropdown.dart';
import 'package:caloriewise/main_component/colors.dart';

class PersonalDetailsPage extends StatefulWidget {
  final int accountId;
  final Function(Map<String, dynamic>) onComplete;

  const PersonalDetailsPage({
    super.key,
    required this.accountId,
    required this.onComplete,
  });

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String selectedGender = 'Male';
  String goal = 'Maintain';
  String selectedActivity = 'Sedentary';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onComplete({
        'accountId': widget.accountId,
        'name': nameController.text.replaceAll(' ', '_'),
        'age': ageController.text,
        'weight': weightController.text,
        'height': heightController.text,
        'gender': selectedGender.toLowerCase(),
        'goal': goal.toLowerCase(),
        'activityLevel': selectedActivity.split(' ')[0].toLowerCase(),
      });
    }
  }

  final activityOptions = {
    'Sedentary': 'Little or no exercise',
    'Light Exercise': '1-3 days/week',
    'Moderate Exercise': '3-5 days/week',
    'Active': '6-7 days/week',
    'Very Active': 'Very hard exercise, or training twice/day',
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Details',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor, width: 1),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      } else if (!RegExp(
                        r'^[a-zA-Z0-9 ]{4,12}$',
                      ).hasMatch(value)) {
                        return 'Name must be 4-12 characters \nContain only letters and numbers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Age',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextFormField(
                    controller: ageController,
                    decoration: InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: kPrimaryColor, width: 1),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your age';
                      } else if (int.tryParse(value) == null ||
                          int.parse(value) < 1 ||
                          int.parse(value) > 99) {
                        return 'Age must be a number between 1 and 99';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weight',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextFormField(
                              controller: weightController,
                              decoration: const InputDecoration(
                                suffixText: 'kg',
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: kPrimaryColor,
                                    width: 1,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your weight';
                                } else if (!RegExp(
                                  r'^\d+(\.\d{1,2})?$',
                                ).hasMatch(value)) {
                                  return 'Must be positive number \n(max 2 decimal)';
                                } else if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return 'Must Greater than 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Height',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextFormField(
                              controller: heightController,
                              decoration: const InputDecoration(
                                suffixText: 'cm',
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: kPrimaryColor,
                                    width: 1,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your height';
                                } else if (!RegExp(
                                  r'^\d+(\.\d{1,2})?$',
                                ).hasMatch(value)) {
                                  return 'Must be positive number \n(max 2 decimal)';
                                } else if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return 'Must Greater than 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  DropdownField(
                    label: 'Gender',
                    items: ['Male', 'Female'],
                    initialValue: selectedGender,
                    onChanged: (value) {
                      selectedGender = value;
                    },
                  ),
                  const SizedBox(height: 20),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownField(
                        label: 'Goal',
                        items: ['Gain', 'Maintain', 'Loss'],
                        initialValue: goal,
                        onChanged: (value) {
                          goal = value;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: A healthy weight change only around ±0.5 kg per week.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.fromARGB(255, 41, 37, 37),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  DropdownField(
                    label: 'Activity Level',
                    items:
                        activityOptions.entries
                            .map((entry) => '${entry.key} - ${entry.value}')
                            .toList(),
                    initialValue: selectedActivity,
                    onChanged: (value) {
                      selectedActivity = value.split(' - ')[0];
                    },
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
