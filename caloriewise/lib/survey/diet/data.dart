import 'package:caloriewise/survey/diet/diet_question.dart';

const questions = [
  DietQuestion('Do you have any chronic diseases?\n(Not more than 2)', [
    'No Disease',
    'Hypertension',
    'Type 2 Diabetes',
    'Hyperlipidemia',
    'Kidney Failure',
  ]),

  DietQuestion('Do you have any allergics? \n(Not more than 2)', [
    'No Allergic',
    'Gluten Free\n(No ingredients containing gluten)',
    'Dairy Free\n(No dairy; no lactose)',
    'Soy Free\n(No soy or products containing soy)',
    'Egg Free\n(No eggs or products containing eggs)',
    'Peanut Free\n(No peanuts or products containing peanuts)',
  ]),
  DietQuestion(
    'Choose at least 3 meal types: \n(If brunch is chosen, avoid the choice of breakfast and lunch)',
    ['Breakfast', 'Lunch', 'Brunch', 'Dinner', 'Snack'],
  ),
];
