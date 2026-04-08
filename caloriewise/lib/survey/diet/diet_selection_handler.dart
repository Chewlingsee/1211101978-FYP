import 'package:caloriewise/survey/diet/diet_question.dart';

class SelectionHandler {
  static void handleSelection({
    required int questionIndex,
    required String answer,
    required List<Set<String>> selectedAnswers,
    required List<DietQuestion> questions,
    required Function(void Function()) setState,
  }) {
    setState(() {
      final currentSelections = selectedAnswers[questionIndex];
      final currentQuestion = questions[questionIndex];
      final exclusiveNoOptions = {0: "No Disease", 1: "No Allergic"};

      if (exclusiveNoOptions.containsKey(questionIndex)) {
        final noOption = exclusiveNoOptions[questionIndex]!;

        if (answer == noOption) {
          currentSelections
            ..clear()
            ..add(noOption);
        } else {
          currentSelections.remove(noOption);

          if (currentSelections.contains(answer)) {
            currentSelections.remove(answer);
          } else {
            if (_canAddAnswer(currentQuestion.text, currentSelections.length)) {
              currentSelections.add(answer);
            }
          }
        }
        return;
      }

      const brunchGroup = {'Brunch', 'Breakfast', 'Lunch'};
      if (questionIndex == 2 && brunchGroup.contains(answer)) {
        if (currentSelections.contains(answer)) {
          currentSelections.remove(answer);
        } else {
          if (answer == 'Brunch') {
            currentSelections.remove('Breakfast');
            currentSelections.remove('Lunch');
          } else {
            currentSelections.remove('Brunch');
          }
          currentSelections.add(answer);
        }
        return;
      }

      if (currentSelections.contains(answer)) {
        currentSelections.remove(answer);
      } else {
        if (_canAddAnswer(currentQuestion.text, currentSelections.length)) {
          currentSelections.add(answer);
        }
      }
    });
  }

  static bool _canAddAnswer(String questionText, int currentLength) {
    if (questionText.contains("Not more than 2")) {
      return currentLength < 2;
    } else if (questionText.contains("Not more than 3")) {
      return currentLength < 3;
    } else if (questionText.contains("Choose at least 3")) {
      return currentLength < 4;
    }
    return true;
  }
}
