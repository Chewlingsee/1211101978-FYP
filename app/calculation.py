import json
from decimal import Decimal

class HealthCalculation:

    @staticmethod
    def _convert_decimal(value):
        """Convert Decimal or int to float if needed."""
        return float(value) if isinstance(value, (Decimal,)) else float(value)

    @classmethod
    def calculate_bmi(cls, weight, height):
        """Calculate BMI and categorize it."""
        weight = cls._convert_decimal(weight)
        height_m = cls._convert_decimal(height) / 100.0

        bmi = round(weight / (height_m ** 2), 2)
        return bmi

    @staticmethod
    def get_bmi_category(bmi):
        if bmi < 18.5:
            return "Underweight"
        elif 18.5 <= bmi < 24.9:
            return "Normal"
        elif 25.0 <= bmi < 29.9:
            return "Overweight"
        else:
            return "Obese"
        
    @classmethod
    def calculate_rmr(cls, weight, height, age, gender):
        """Calculate Resting Metabolic Rate (Mifflin-St Jeor)."""
        weight = cls._convert_decimal(weight)
        height = cls._convert_decimal(height)
        age = int(age)

        if gender.lower() == 'male':
            return round((10 * weight) + (6.25 * height) - (5 * age) + 5, 2)
        elif gender.lower() == 'female':
            return round((10 * weight) + (6.25 * height) - (5 * age) - 161, 2)
        return None

    @staticmethod
    def calculate_tdee(rmr, activity_level):
        """Calculate Total Daily Energy Expenditure (TDEE)."""
        activity_multipliers = {
            "sedentary": 1.2,
            "light": 1.375,
            "moderate": 1.55,
            "active": 1.725,
            "very active": 1.9
        }
        multiplier = activity_multipliers.get(activity_level.lower(), 1.2)
        return round(rmr * multiplier, 2)

    @staticmethod
    def calculate_total_calorie(tdee, goal, exercise_recommendation='no', exercise_amount='less'):
        exercise_adjustment = 0 

        if goal == 'gain':
            total_calories = tdee + 500
        elif goal == 'loss':
            total_calories = tdee - 500
        else:
            total_calories = tdee

        # Add back exercise burn if applicable
        if exercise_recommendation == 'yes':
            if exercise_amount == 'less':
                exercise_adjustment = 500 * 0.10
            elif exercise_amount == 'moderate':
                exercise_adjustment = 500 * 0.15
            elif exercise_amount == 'more':
                exercise_adjustment = 500 * 0.20

            total_calories += exercise_adjustment

        return round(total_calories, 2), round(exercise_adjustment, 2)

    @staticmethod
    def calculate_macronutrient_grams(total_calories, macronutrient_split):
        """Calculate macronutrient measurements in grams."""
        protein_grams = (macronutrient_split["protein"] / 100) * total_calories / 4
        carbs_grams = (macronutrient_split["carbs"] / 100) * total_calories / 4
        fat_grams = (macronutrient_split["fat"] / 100) * total_calories / 9

        return {
            "protein_grams": round(protein_grams, 1),
            "carbs_grams": round(carbs_grams, 1),
            "fat_grams": round(fat_grams, 1)
        }

    @staticmethod
    def split_calories_into_meals(total_calories, meal_types):
        """
        Split total calories into meals based on meal types.
        meal_types: List of meal types chosen by the user (e.g., ['breakfast', 'lunch', 'dinner']).
        """
        meal_distribution_rules = {
        ("breakfast", "lunch", "snack"): [0.25, 0.40, 0.35],
        ("breakfast", "lunch", "dinner", "snack"): [0.25, 0.30, 0.30, 0.15],
        ("breakfast", "lunch", "dinner"): [0.25, 0.35, 0.40],
        ("breakfast", "dinner", "snack"): [0.25, 0.40, 0.35],
        ("lunch", "snack", "dinner"): [0.35, 0.25, 0.40],
        ("brunch", "dinner", "snack"): [0.35, 0.40, 0.25],
    }

        # Convert meal_types to a sorted tuple for dictionary key
        meal_types_tuple = tuple(sorted(meal_types))

        # Find the matching rule for the user's meal types
        distribution = None
        for rule_meal_types, rule_distribution in meal_distribution_rules.items():
            if set(rule_meal_types) == set(meal_types_tuple):
                distribution = rule_distribution
                break

        if not distribution:
            raise ValueError(f"No distribution rule found for meal types: {meal_types}")

        # Split calories based on the distribution
        meal_calories = {}
        meal_distribution = {}
        
        for i, meal in enumerate(meal_types_tuple):
            meal_calories[meal] = round(total_calories * distribution[i], 1)
            meal_distribution[meal] = round(distribution[i] * 100, 1)

        return meal_calories, meal_distribution
    
    @staticmethod    
    def parse_diseases(diseases_str):
        """
        Parse the diseases string into a list of diseases.
        Example: '["no_disease"]' -> ['no_disease']
        """
        try:
            diseases_str = json.loads(diseases_str.strip().replace("'", '"')) # Ensure double quotes for JSON
            return [disease.strip().lower() for disease in diseases_str]
        except (json.JSONDecodeError, AttributeError):
            return []

    @staticmethod
    def parse_meal_types(meal_types_str):
        """
        Parse the meal_types string into a list of meal types.
        Example: '["breakfast", "lunch", "snack"]' -> ['breakfast', 'lunch', 'snack']
        """
        try:
            meal_types_str = json.loads(meal_types_str.strip().replace("'", '"'))  # Ensure double quotes for JSON
            return [meal.strip().lower() for meal in meal_types_str]
        except (json.JSONDecodeError, AttributeError):
            return []

