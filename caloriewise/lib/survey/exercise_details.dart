import 'package:caloriewise/survey/diet/component/bg_color.dart';
import 'package:flutter/material.dart';
import 'package:caloriewise/survey/dropdown.dart';
import 'package:caloriewise/main_component/colors.dart';

class ExerciseDetailsPage extends StatefulWidget {
  final Map<String, dynamic> personalData;
  final Function(Map<String, dynamic>) onComplete;

  const ExerciseDetailsPage({
    super.key,
    required this.personalData,
    required this.onComplete,
  });

  @override
  State<ExerciseDetailsPage> createState() => _ExerciseDetailsPageState();
}

class _ExerciseDetailsPageState extends State<ExerciseDetailsPage> {
  String exerciseRecommend = 'No';
  String exerciseIntensity = 'Light';
  String exerciseAmount = 'Less';

  void _submit() {
    widget.onComplete({
      'exerciseRecommend': exerciseRecommend.toLowerCase(),
      'exerciseIntensity':
          exerciseRecommend == 'Yes' ? exerciseIntensity.toLowerCase() : 'none',
      'exerciseAmount':
          exerciseRecommend == 'Yes' ? exerciseAmount.toLowerCase() : 'none',
    });
  }

  @override
  Widget build(BuildContext context) {
    return SurveyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/images/fitness.png', width: 400),
                    const SizedBox(height: 20),
                    const Text(
                      'Exercise Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Dropdown Fields
                    DropdownField(
                      label: 'Need exercise recommendation?',
                      items: ['Yes', 'No'],
                      initialValue: exerciseRecommend,
                      onChanged:
                          (value) => setState(() => exerciseRecommend = value),
                    ),
                    const SizedBox(height: 25),

                    if (exerciseRecommend == 'Yes') ...[
                      DropdownField(
                        label: 'Preferred intensity level:',
                        items: ['Light', 'Moderate', 'High'],
                        initialValue: exerciseIntensity,
                        onChanged:
                            (value) =>
                                setState(() => exerciseIntensity = value),
                      ),
                      const SizedBox(height: 25),

                      DropdownField(
                        label: 'Preferred exercise amount:',
                        items: ['Less', 'Moderate', 'More'],
                        initialValue: exerciseAmount,
                        onChanged:
                            (value) => setState(() => exerciseAmount = value),
                      ),
                      const SizedBox(height: 25),
                    ],

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: kPrimaryColor,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                            ),
                            onPressed: _submit,
                            child: const Text(
                              'Next',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
