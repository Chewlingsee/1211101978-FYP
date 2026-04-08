import 'package:caloriewise/survey/successfull_reg.dart';
import 'package:flutter/material.dart';
import 'package:caloriewise/survey/personal_details.dart';
import 'package:caloriewise/survey/diet/component/bg_color.dart';
import 'package:caloriewise/survey/exercise_details.dart';
import 'package:caloriewise/survey/diet_details.dart';

class SurveyScreen extends StatefulWidget {
  final int accountId;
  const SurveyScreen({super.key, required this.accountId});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  void _completeSurvey() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SuccessfullReg()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SurveyBackground(
        child: PersonalDetailsPage(
          accountId: widget.accountId,
          onComplete: (personalData) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ExerciseDetailsPage(
                      personalData: personalData,
                      onComplete: (exerciseData) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => DietDetailsPage(
                                  accountId: widget.accountId,
                                  surveyData: {
                                    ...personalData,
                                    ...exerciseData,
                                  },
                                  onFinish: _completeSurvey,
                                ),
                          ),
                        );
                      },
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
