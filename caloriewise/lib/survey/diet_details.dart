import 'package:caloriewise/survey/diet/component/bg_color.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:caloriewise/survey/diet/diet_question.dart';
import 'package:caloriewise/survey/diet/data.dart';
import 'package:caloriewise/survey/diet/diet_selection_handler.dart';

class DietDetailsPage extends StatefulWidget {
  final int accountId;
  final Map<String, dynamic>
  surveyData; // Contains both personal and exercise data
  final VoidCallback onFinish;

  const DietDetailsPage({
    super.key,
    required this.accountId,
    required this.surveyData,
    required this.onFinish,
  });

  @override
  State<DietDetailsPage> createState() => _DietDetailsPageState();
}

class _DietDetailsPageState extends State<DietDetailsPage> {
  int _currentQuestionIndex = 0;
  final List<Set<String>> _selectedAnswers = List.generate(
    questions.length,
    (_) => {},
  );

  void _nextQuestion() {
    if (_currentQuestionIndex < questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitSurvey(); // Submit survey data when all questions are answered
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    } else {
      Navigator.pop(context); // Go back to PersonalDetailsPage
    }
  }

  void _onAnswerSelected(String answer) {
    SelectionHandler.handleSelection(
      questionIndex: _currentQuestionIndex,
      answer: answer,
      selectedAnswers: _selectedAnswers,
      questions: questions,
      setState: (fn) => setState(fn),
    );
  }

  void _submitSurvey() async {
    // Preprocess the selected answers
    final processedDiseases =
        _selectedAnswers[0]
            .map((answer) => answer.split('\n')[0].toLowerCase())
            .toList();

    final processedAllergies =
        _selectedAnswers[1]
            .map(
              (answer) =>
                  answer.split('\n')[0].toLowerCase().replaceAll(' ', '-'),
            )
            .toList();

    final processedMealTypes =
        _selectedAnswers[2]
            .map((answer) => answer.split('\n')[0].toLowerCase())
            .toList();

    // Prepare the survey data
    final surveyData = {
      'account_id': widget.accountId,
      'name': widget.surveyData['name'],
      'age': widget.surveyData['age'],
      'weight': widget.surveyData['weight'],
      'height': widget.surveyData['height'],
      'gender': widget.surveyData['gender'],
      'goal': widget.surveyData['goal'],
      'activity_level': widget.surveyData['activityLevel'],
      'diseases': processedDiseases,
      'allergies': processedAllergies,
      'meal_types': processedMealTypes,
      'exercise_recommendation': widget.surveyData['exerciseRecommend'],
      'exercise_intensity': widget.surveyData['exerciseIntensity'],
      'exercise_amount': widget.surveyData['exerciseAmount'],
    };

    // Send the survey data to the backend
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/survey/submit_survey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(surveyData),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      widget
          .onFinish(); // Call the onFinish callback to navigate to the login screen
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit survey data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    DietQuestion currentQuestion = questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == questions.length - 1;
    final currentSelectionsCount =
        _selectedAnswers[_currentQuestionIndex].length;

    return SurveyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Diet Details'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentQuestion.text,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ...currentQuestion.selections.map((answer) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _onAnswerSelected(answer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedAnswers[_currentQuestionIndex].contains(
                                    answer,
                                  )
                                  ? const Color.fromARGB(255, 118, 140, 220)
                                  : const Color.fromARGB(255, 49, 45, 157),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          answer,
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment:
                        _currentQuestionIndex == 0
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentQuestionIndex > 0)
                        ElevatedButton(
                          onPressed: _previousQuestion,
                          child: Text('Back'),
                        ),
                      ElevatedButton(
                        onPressed:
                            isLastQuestion
                                ? (currentSelectionsCount >= 3
                                    ? _nextQuestion
                                    : null)
                                : (currentSelectionsCount > 0
                                    ? _nextQuestion
                                    : null),
                        child: Text(isLastQuestion ? 'Finish' : 'Next'),
                      ),
                    ],
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
