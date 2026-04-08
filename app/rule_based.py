import clips
from calculation import HealthCalculation
import random

# Disease -> Diet Label Logic
DISEASE_LABEL_MAPPING = {
    "hypertension": ["Low-Fat", "Low-Sodium"],
    "type 2 diabetes": ["Low-Sugar"],
    "hyperlipidemia": ["High-Fiber"],
    "kidney failure": ["Low-Sodium", "Low-Protein"],
}

NORMAL_MACRONUTRIENT_RANGES = {
    "underweight": {"protein": (15, 25), "carbs": (50, 60), "fat": (25, 35)},
    "normal": {"protein": (10, 20), "carbs": (45, 65), "fat": (20, 35)},
    "overweight": {"protein": (15, 35), "carbs": (40, 50), "fat": (20, 25)},
    "obese": {"protein": (25, 35), "carbs": (40, 50), "fat": (15, 20)}
}

LABEL_MACRONUTRIENT_RANGES = {
    "Low-Fat": {"protein": (15, 25), "carbs": (45, 60), "fat": (0, 15)},
    "Low-Protein": {"protein": (0, 15), "carbs": (45, 60), "fat": (20, 35)},
}

def get_diet_labels_from_diseases(diseases):
    """Map disease to diet labels from DISEASE_LABEL_MAPPING."""
    diet_labels = set()
    for disease in diseases:
        for key, labels in DISEASE_LABEL_MAPPING.items():
            if key.lower() == disease.lower():
                diet_labels.update(labels)
    return list(diet_labels)

def calculate_macronutrient_split(bmi_category, diseases):
    def strict_bounds(ranges):
        if not ranges:
            return (0, 100)
        min_bound = max(r[0] for r in ranges)  # Tightest lower bound
        max_bound = min(r[1] for r in ranges)  # Tightest upper bound
        return (min_bound, max_bound)

    def clamp(value, min_val, max_val):
        return max(min_val, min(value, max_val))

    # Normalize inputs
    bmi_category = bmi_category.lower().strip()
    diseases = [d.lower().strip() for d in diseases if d.lower().strip() != "no disease"]

    # Get BMI fallback ranges
    bmi_ranges = NORMAL_MACRONUTRIENT_RANGES.get(bmi_category, {
        "protein": (25.0, 25.0), "carbs": (50.0, 50.0), "fat": (25.0, 25.0)
    })

    if not diseases:
        # Case 1: No diseases → Use BMI ranges
        merged = bmi_ranges
    else:
        # Get all diet labels from diseases
        diet_labels = get_diet_labels_from_diseases(diseases)
        valid_labels = [label for label in diet_labels if label in LABEL_MACRONUTRIENT_RANGES]

        if not valid_labels:
            # Case 2: No valid labels → Use BMI ranges
            merged = bmi_ranges
        elif len(valid_labels) == 1:
            # Case 3: One valid label → Use its ranges directly
            merged = LABEL_MACRONUTRIENT_RANGES[valid_labels[0]]
        else:
            # Case 4: Multiple labels → Combine ranges using union
            macro_ranges = {"protein": [], "carbs": [], "fat": []}
            for label in valid_labels:
                for macro in macro_ranges:
                    macro_ranges[macro].append(LABEL_MACRONUTRIENT_RANGES[label][macro])
            merged = {
                macro: (min(r[0] for r in macro_ranges[macro]),  # Union min
                max(r[1] for r in macro_ranges[macro]) )  # Union max
                for macro in ["protein", "carbs", "fat"]
            }

    # Step 1: Calculate midpoints within bounds
    protein = (merged["protein"][0] + merged["protein"][1]) / 2
    carbs = (merged["carbs"][0] + merged["carbs"][1]) / 2
    fat = (merged["fat"][0] + merged["fat"][1]) / 2

    # Step 2: Calculate how much we need to add to reach 100%
    current_sum = protein + carbs + fat
    remaining = 100 - current_sum

    if abs(remaining) > 0.1:  # Only adjust if significant difference
        # Calculate how much room we have to adjust each macro
        room_available = {
            "protein": merged["protein"][1] - protein,
            "carbs": merged["carbs"][1] - carbs,
            "fat": merged["fat"][1] - fat
        }
        total_room = sum(room_available.values())

        if total_room > 0:
            # Distribute remaining proportionally to available room
            protein += remaining * (room_available["protein"] / total_room)
            carbs += remaining * (room_available["carbs"] / total_room)
            fat += remaining * (room_available["fat"] / total_room)

    # Step 3: Clamp all values to ensure they stay within bounds
    protein = clamp(protein, *merged["protein"])
    carbs = clamp(carbs, *merged["carbs"])
    fat = clamp(fat, *merged["fat"])

    # Step 4: Round and handle any remaining small differences
    rounded = {
        "protein": round(protein, 1),
        "carbs": round(carbs, 1),
        "fat": round(fat, 1)
    }

    # Final adjustment to ensure exact 100% sum
    diff = round(100.0 - sum(rounded.values()), 1)
    if abs(diff) > 0:
        # Find which macro can absorb the difference without violating bounds
        for macro in ["carbs", "fat", "protein"]:  # Priority order
            current = rounded[macro]
            min_val, max_val = merged[macro]
            if diff > 0 and current < max_val:
                add = min(diff, max_val - current)
                rounded[macro] = round(current + add, 1)
                diff -= add
            elif diff < 0 and current > min_val:
                subtract = min(-diff, current - min_val)
                rounded[macro] = round(current - subtract, 1)
                diff += subtract
            if abs(diff) < 0.1:
                break

    return rounded

# Setup CLIPS environment
env = clips.Environment()
env.clear()

# Templates
env.build("""
(deftemplate user
    (multislot diseases)
    (multislot allergies)
    (slot bmi-category)
    (slot goal)
)
""")

env.build("""
(deftemplate diet-label
    (slot value)
)
""")

env.build("""
(deftemplate health-label
    (slot value)
)
""")

# Rules
env.build("""
(defrule determine-diet-labels
    (user (diseases $?diseases))
    =>
    (printout t "Debug: Rule Fired! Diseases = " ?diseases crlf)
    (foreach ?disease $?diseases
        (if (eq (lowcase ?disease) "hypertension")
            then
            (assert (diet-label (value "Low-Fat")))
            (assert (diet-label (value "Low-Sodium"))))
        (if (eq (lowcase ?disease) "type 2 diabetes")
            then
            (assert (diet-label (value "Low-Sugar"))))
        (if (eq (lowcase ?disease) "hyperlipidemia")
            then
            (assert (diet-label (value "High-Fiber"))))
        (if (eq (lowcase ?disease) "kidney failure")
            then
            (assert (diet-label (value "Low-Sodium")))
            (assert (diet-label (value "Low-Protein"))))
    )
)
""")

env.build("""
(defrule determine-health-labels
    (user (allergies $?allergies))
    =>
    (foreach ?allergy ?allergies
        (if (eq ?allergy "gluten-free")
            then (assert (health-label (value "Gluten-Free"))))
        (if (eq ?allergy "dairy-free")
            then (assert (health-label (value "Dairy-Free"))))
        (if (eq ?allergy "soy-free")
            then (assert (health-label (value "Soy-Free"))))
        (if (eq ?allergy "egg-free")
            then (assert (health-label (value "Egg-Free"))))
        (if (eq ?allergy "peanut-free")
            then (assert (health-label (value "Peanut-Free"))))
    )
)
""")

def process_user(user_info):
    if not user_info:
        return "User not found or no user info."

    # 1) Calculate metrics
    weight = user_info['weight']
    height = user_info['height']
    age = user_info['age']
    gender = user_info['gender']
    goal = user_info['goal']
    activity_level = user_info['activity_level']
    exercise_recommendation = user_info['exercise_recommendation']
    exercise_amount = user_info['exercise_amount']

    bmi = HealthCalculation.calculate_bmi(weight, height)
    bmi_category = HealthCalculation.get_bmi_category(bmi)
    rmr = HealthCalculation.calculate_rmr(weight, height, age, gender)
    tdee = HealthCalculation.calculate_tdee(rmr, activity_level)
    total_calories, exercise_adjustment = HealthCalculation.calculate_total_calorie(
        tdee, goal, exercise_recommendation, exercise_amount
    )
    # 2) Get lists directly (no splitting needed)
    diseases = user_info.get('diseases', [])  # Already a list
    allergies = user_info.get('allergies', [])  # Already a list

    # Clean whitespace and lowercase (if needed)
    diseases = [disease.strip().lower() for disease in diseases]
    allergies = [allergy.strip() for allergy in allergies]

    # 3) Calculate macro split
    macronutrient_split = calculate_macronutrient_split(bmi_category, diseases) or {}
    env.reset()

    # 4) Prepare CLIPS inputs
    diseases = [d.strip().lower() for d in user_info.get('diseases', [])]
    diseases_str = ' '.join(f'"{d}"' for d in diseases if d != "no disease")
    
    # Clean and format allergies - ensure proper spacing and quoting
    allergies = [a.strip().lower() for a in user_info.get('allergies', [])]
    allergies_str = ' '.join(f'"{a}"' for a in allergies)
    
    print(f"Debug: Formatted allergies for CLIPS: {allergies_str}")


    # Assert user fact
    user_fact = f'(user (diseases {diseases_str}) (allergies {allergies_str})' \
                f'(bmi-category {bmi_category})' \
                f' (goal {goal}))'
    print(f"Debug: User fact: {user_fact}")
    env.assert_string(user_fact)
    
    # Print all rules for debugging
    print("\nDebug: All Rules:")
    for rule in env.rules():
        print(rule.name)
    
    env.run()

    # Debug: Print all facts after execution
    print("\nDebug: All Facts After Execution:")
    for fact in env.facts():
        print(fact)

    # 5) Extract labels
    health_labels = []
    diet_labels = []
    for fact in env.facts():
        if fact.template.name == "health-label":
            health_labels.append(fact["value"])
        elif fact.template.name == "diet-label":
            diet_labels.append(fact["value"])

    print("Debug: Diet Labels =", diet_labels)
    print("Debug: Health Labels =", health_labels)

    # 6) Get meal_types (already a list)
    meal_types = user_info.get('meal_types', [])

    # 7) Final calculations
    macronutrient_grams = HealthCalculation.calculate_macronutrient_grams(total_calories, macronutrient_split)
    meal_calories, meal_distribution = HealthCalculation.split_calories_into_meals(total_calories, meal_types)

    # 8) Return output
    return {
        'user_id': user_info['id'],
        'name': user_info['name'],
        'bmi': bmi,
        'bmi_category': bmi_category,
        'rmr': rmr,
        'tdee': tdee,
        'total_calories': total_calories,
        'exercise_adjustment': exercise_adjustment,
        'macronutrient_split': macronutrient_split,
        'macronutrient_grams': macronutrient_grams,
        'meal_distribution': meal_distribution,
        'meal_calories': meal_calories,
        'diet_labels': diet_labels,
        'health_labels': health_labels,
    }

    

