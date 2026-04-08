import csv
import random
from typing import List, Dict
from datetime import datetime, timedelta
from db_functions import connect_to_database

def load_exercise_db(csv_path: str) -> List[Dict]:
    """Load exercise database from CSV file"""
    exercises = []
    with open(csv_path, mode='r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            row['mets'] = float(row['mets'])
            exercises.append(row)
    return exercises

def generate_workout_recommendations(user_data: Dict, exercise_db: List[Dict]) -> List[Dict]:
    """
    Generate workout plan with:
    - No repeating exercises
    - Precise weekly calorie distribution
    - Weight assumed to be in kg (no conversion)
    """
    if user_data.get('exercise_recommendation', '').lower() != 'yes':
        return []

    # Calculate weekly calorie target
    amount = user_data.get('exercise_amount', 'moderate').lower()
    daily_calorie_burn = 500 * {
        'less': 0.10,    # 50 kcal/day → 350 kcal/week
        'moderate': 0.15, # 75 kcal/day → 525 kcal/week
        'more': 0.20      # 100 kcal/day → 700 kcal/week
    }.get(amount, 0.15)
    weekly_target = daily_calorie_burn * 7

    # Determine session count
    session_ranges = {
        'less': (2, 3),      # 2-3 sessions
        'moderate': (3, 4),   # 3-4 sessions
        'more': (4, 5)       # 4-5 sessions
    }
    min_sessions, max_sessions = session_ranges.get(amount, (3, 3))
    num_sessions = random.randint(min_sessions, max_sessions)

   # STRICT EXERCISE FILTERING
    intensity = user_data.get('exercise_intensity', '').lower()
    goal = user_data.get('goal', '').lower()

    if goal == 'loss':
        # ONLY allow exact "Aerobic/Cardiovascular" type
        filtered_exercises = [
            ex for ex in exercise_db 
            if (ex['intensity'].lower() == intensity and
                ex['activity_type'] == "Aerobic/Cardiovascular")  # Exact match
        ]
        
    elif goal == 'gain':
        # EXCLUDE any "Aerobic/Cardiovascular" exercises
        filtered_exercises = [
            ex for ex in exercise_db 
            if (ex['intensity'].lower() == intensity and
                ex['activity_type'] != "Aerobic/Cardiovascular")  # Exact exclusion
        ]
    else:
        # Other goals - all matching intensity
        filtered_exercises = [
            ex for ex in exercise_db 
            if ex['intensity'].lower() == intensity
        ]

    # Early return if no matching exercises
    if len(filtered_exercises) < num_sessions:
        num_sessions = len(filtered_exercises)
        if num_sessions == 0:
            print(f"No suitable exercises found for goal: {goal}, intensity: {intensity}")
            return []

    # Get weight in kg (assuming already in kg)
    weight_kg = float(user_data['weight'])

    recommendations = []
    remaining_calories = weekly_target
    used_exercises = set()

    # Shuffle for random selection
    random.shuffle(filtered_exercises)

    for session_num in range(1, num_sessions + 1):
        # Get next unused exercise
        exercise = next(
            (ex for ex in filtered_exercises if ex['workout_name'] not in used_exercises),
            None
        )
        if not exercise:
            break

        used_exercises.add(exercise['workout_name'])

        # Calculate target calories
        if session_num == num_sessions:
            target_cals = remaining_calories
        else:
            base_target = weekly_target / num_sessions
            target_cals = base_target * random.uniform(0.9, 1.1)
            target_cals = min(target_cals, remaining_calories * 0.8)

        calories_per_min = (exercise['mets'] * 3.5 * weight_kg) / 200
        minutes = max(10, min(60, round(target_cals / calories_per_min)))
        actual_cals = calories_per_min * minutes

        recommendations.append({
            'user_id': user_data['id'],
            'workout_name': exercise['workout_name'],
            'activity_type': exercise['activity_type'],
            'intensity': exercise['intensity'],
            'minutes_per_session': minutes,
            'calories_per_session': round(actual_cals, 1),
            'session_number': session_num,
            'mets': exercise['mets'],
            'description': exercise.get('description_benefit', ''),
            'weight_kg': weight_kg,
            'date_generated': datetime.now().date()
        })

        remaining_calories -= actual_cals

    # Final adjustment if needed
    if recommendations:
        total_calories = sum(rec['calories_per_session'] for rec in recommendations)
        if abs(total_calories - weekly_target) > weekly_target * 0.05:
            adjustment = weekly_target - total_calories
            last_rec = recommendations[-1]
            calories_per_min = (last_rec['mets'] * 3.5 * weight_kg) / 200
            new_minutes = last_rec['minutes_per_session'] + round(adjustment / calories_per_min)
            new_minutes = max(10, min(60, new_minutes))
            
            last_rec['minutes_per_session'] = new_minutes
            last_rec['calories_per_session'] = round(calories_per_min * new_minutes, 1)

        # Add summary info
        for rec in recommendations:
            rec.update({
                'daily_calorie_burn': round(daily_calorie_burn, 1),
                'weekly_calorie_burn': round(weekly_target, 1),
                'total_sessions': num_sessions,
                'total_weekly_calories': round(total_calories, 1)
            })

    return recommendations

def save_recommendations_to_db(recommendations: List[Dict]) -> bool:
    conn = connect_to_database()
    if not conn or not recommendations:
        return False

    try:
        cursor = conn.cursor()
        user_id = recommendations[0]['user_id']

        # 1. Determine end_date (prefer diet plan, fallback to 7-day default)
        cursor.execute("""
            SELECT end_date FROM weekly_diet_plan
            WHERE user_id = %s AND is_active = TRUE
            ORDER BY id DESC LIMIT 1
        """, (user_id,))
        diet_row = cursor.fetchone()

        default_start_date = datetime.now().date() + timedelta(days=1)
        default_end_date = default_start_date + timedelta(days=6)
        end_date = diet_row[0] if diet_row else default_end_date

        # 2. Check for existing workout recommendation
        cursor.execute("""
            SELECT id FROM workout_recommendations 
            WHERE user_id = %s
            ORDER BY date_generated DESC 
            LIMIT 1
        """, (user_id,))
        existing_rec = cursor.fetchone()
        recommendation_id = existing_rec[0] if existing_rec else None

        if recommendation_id:
            # 3a. Update existing recommendation
            cursor.execute("""
                UPDATE workout_recommendations 
                SET daily_calorie_burn = %s,
                    weekly_calorie_burn = %s,
                    total_sessions = %s,
                    date_generated = %s,
                    end_date = %s
                WHERE id = %s
            """, (
                recommendations[0]['daily_calorie_burn'],
                recommendations[0]['weekly_calorie_burn'],
                recommendations[0]['total_sessions'],
                recommendations[0]['date_generated'],
                end_date,
                recommendation_id
            ))

            # 3b. Delete old workout details
            cursor.execute("""
                DELETE FROM workout_recommendation_details 
                WHERE recommendation_id = %s
            """, (recommendation_id,))
        else:
            # 4. Insert new workout recommendation
            cursor.execute("""
                INSERT INTO workout_recommendations (
                    user_id, daily_calorie_burn, weekly_calorie_burn, 
                    total_sessions, date_generated, end_date
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                user_id,
                recommendations[0]['daily_calorie_burn'],
                recommendations[0]['weekly_calorie_burn'],
                recommendations[0]['total_sessions'],
                recommendations[0]['date_generated'],
                end_date
            ))
            recommendation_id = cursor.lastrowid

        # 5. Insert all recommendation details
        for rec in recommendations:
            cursor.execute("""
                INSERT INTO workout_recommendation_details (
                    recommendation_id, workout_name, activity_type, intensity,
                    minutes_per_session, calories_per_session, session_number,
                    mets
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                recommendation_id,
                rec['workout_name'],
                rec['activity_type'],
                rec['intensity'],
                rec['minutes_per_session'],
                rec['calories_per_session'],
                rec['session_number'],
                rec['mets'],
            ))

        conn.commit()
        return True

    except Exception as e:
        print(f"Error saving to DB: {e}")
        conn.rollback()
        return False

    finally:
        cursor.close()
        conn.close()
