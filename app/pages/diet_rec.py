from flask import Blueprint, request, jsonify
import os
import json
import numpy as np
from datetime import date, timedelta
from pages.finalize_log import finalize_meal_status_and_logs  
from recommendation.diet import DietRecommendation
import pandas as pd
import json

diet_bp = Blueprint('diet_bp', __name__)

RECIPE_CSV_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../model/recipe_dataset.csv'))

# Load recipe data once
recipe_df = pd.read_csv(RECIPE_CSV_PATH)

# Create a lookup map: recipe_id -> {ingredient_lines, instructions}
def safe_json_load(value):
    if not value:
        return []
    
    # Handle cases where the value might be a string representation of a list
    if isinstance(value, str):
        # First, try to parse as JSON
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return parsed
            elif isinstance(parsed, str):
                # Might be a string that was double-encoded
                try:
                    return json.loads(parsed)
                except:
                    return [parsed]
            return [parsed]
        except json.JSONDecodeError:
            # If not JSON, check if it's a plain string with comma separation
            if ',' in value:
                return [item.strip() for item in value.split(',')]
            return [value.strip()]
    
    # Handle cases where value might already be a list
    if isinstance(value, (list, tuple)):
        return list(value)
    
    # Fallback for other types
    return [str(value)]

recipe_lookup = {
    str(row['recipe_id']): {
        'ingredient_lines': safe_json_load(row.get('ingredient_lines', '')),
        'recipe_instructions': str(row.get('recipe_instructions', ""))
    }
    for _, row in recipe_df.iterrows()
}


def convert_numpy_types(obj):
    """Convert numpy types to native Python types for JSON serialization"""
    if isinstance(obj, np.integer):
        return int(obj)
    elif isinstance(obj, np.floating):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, (list, tuple)):
        return [convert_numpy_types(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_numpy_types(value) for key, value in obj.items()}
    elif hasattr(obj, 'quantize'):  # Handle Decimal types
        return float(obj)
    return obj

@diet_bp.route('/generate_diet_plan', methods=['POST'])
def generate_diet_plan():
    """Endpoint to generate or regenerate a diet plan"""
    data = request.get_json()
    if not data or 'user_id' not in data:
        return jsonify({"error": "Missing 'user_id' in request body"}), 400

    user_id = data['user_id']
    recommender = None

    try:
        recommender = DietRecommendation(user_id, RECIPE_CSV_PATH)
        recommender.load_recipe_data()
        recommender.load_user_data()
        recommender.filter_by_labels()
        recommender.filter_by_macronutrients()
        recommender.create_serving_variations()
        
        weekly_plan = recommender.generate_weekly_plan()
        
        print(f"\n{'='*50}")
        print("Final Weekly Meal Plan Report")
        print(f"{'='*50}")
        recommender.print_weekly_plan(weekly_plan) 
        print(f"\n{'='*50}")
        
        if not weekly_plan:
            return jsonify({"message": "Could not generate a complete diet plan with current parameters.", "plan": {}}), 200

        recommender.save_plan_to_db()

        recommender.log_daily_plan()

        try:
            recommender.cursor.execute("""
                SELECT end_date FROM weekly_diet_plan 
                WHERE user_id = %s AND is_active = TRUE 
                ORDER BY id DESC LIMIT 1
            """, (user_id,))
            row = recommender.cursor.fetchone()
            if row:
                diet_end_date = row[0]  # datetime.date object

                # Update the most recent workout plan's end_date to match diet's
                recommender.cursor.execute("""
                    UPDATE workout_recommendations AS wr
                    JOIN (
                        SELECT id FROM (
                            SELECT id FROM workout_recommendations
                            WHERE user_id = %s
                            ORDER BY date_generated DESC
                            LIMIT 1
                        ) AS subq
                    ) AS latest ON wr.id = latest.id
                    SET wr.end_date = %s
                """, (user_id, diet_end_date))

                recommender.conn.commit()
        except Exception as sync_err:
            print(f"Warning: Failed to sync workout end_date: {sync_err}")

        # Prepare response with proper type conversion
        response_plan = {}
        for day, day_data in weekly_plan.items():
            processed_meals = {}
            for meal_type, meal_details in day_data['meals'].items():
                processed_meals[meal_type] = {
                    'recipe_name': meal_details['recipe_name'],
                    'servings': float(meal_details['servings']),
                    'calories': float(meal_details['calories']),
                    'fat': float(meal_details['fat']),
                    'carbs': float(meal_details['carbs']),
                    'protein': float(meal_details['protein']),
                    'fiber': float(meal_details['fiber']), 
                    'sugars': float(meal_details['sugars']), 
                    'sodium': float(meal_details['sodium'])
                }
            
            processed_totals = {
                'calories': float(day_data['totals']['calories']),
                'fat': float(day_data['totals']['fat']),
                'carbs': float(day_data['totals']['carbs']),
                'protein': float(day_data['totals']['protein']),
            }

            response_plan[day] = {
                "date": day_data['date'].isoformat(),
                "meals": processed_meals,
                "totals": processed_totals
            }

        return jsonify({
            "message": "Diet plan generated and saved successfully!",
            "user_id": user_id,
            "weekly_plan": response_plan,
            "target_calories": convert_numpy_types(recommender.user_data['total_calories']),
            "target_macronutrients_grams": convert_numpy_types(recommender.user_data['macronutrient_grams']),
            "meal_calories_distribution": convert_numpy_types(recommender.user_data['meal_calories'])
        }), 200

    except ValueError as ve:
        return jsonify({"error": str(ve)}), 400
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": "An internal server error occurred: " + str(e)}), 500
    finally:
        if recommender:
            recommender.close_connection()

@diet_bp.route('/history', methods=['GET'])
def get_diet_history():
    """Endpoint to fetch diet plan history with progress tracking"""
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing 'user_id' query parameter"}), 400

    recommender = None
    try:
        recommender = DietRecommendation(user_id, RECIPE_CSV_PATH)
        
        # Get active weekly plan
        recommender.cursor.execute(
            """SELECT id, start_date, end_date, date_generated,
                  plan_calories, plan_fats, plan_carbs, plan_protein
               FROM weekly_diet_plan
               WHERE user_id = %s AND is_active = TRUE""",
            (user_id,)
        )
        weekly_plan = recommender.cursor.fetchone()

        if not weekly_plan:
            return jsonify({"message": "No active diet plan found for this user"}), 404

        # Get daily meals with status
        recommender.cursor.execute(
            """SELECT plan_date, meal_type, recipe_id, recipe_name, servings,
                  target_cal, target_fat, target_carbs, target_protein, target_fiber, target_sugar, target_sodium, status
               FROM daily_meal_plan
               WHERE weekly_plan_id = %s
               ORDER BY plan_date, 
                        CASE meal_type 
                            WHEN 'breakfast' THEN 1 
                            WHEN 'brunch' THEN 2
                            WHEN 'lunch' THEN 3 
                            WHEN 'dinner' THEN 4 
                            WHEN 'snack' THEN 5 
                            ELSE 6 
                        END""",
            (weekly_plan[0],)
        )
        daily_meals = recommender.cursor.fetchall()

        # Reconstruct weekly plan with status
        reconstructed_plan = {}
        for day_num in range(7):
            current_date = weekly_plan[1] + timedelta(days=day_num)
            day_key = f"Day {day_num + 1}"
            
            day_meals = [m for m in daily_meals if m[0] == current_date]
            if not day_meals:
                continue
                
            meals_dict = {}
            for meal in day_meals:
                recipe_id = str(meal[2])  # Ensure it matches the CSV key type
                recipe_data = recipe_lookup.get(recipe_id, {
                    "ingredient_lines": [],
                    "recipe_instructions": ""
                })

                meals_dict[meal[1]] = {
                    'recipe_name': meal[3],
                    'recipe_id': recipe_id,
                    'ingredient_lines': recipe_data['ingredient_lines'],
                    'recipe_instructions': recipe_data['recipe_instructions'],
                    'servings': float(meal[4]),
                    'calories': float(meal[5]),
                    'fat': float(meal[6]),
                    'carbs': float(meal[7]),
                    'protein': float(meal[8]),
                    'fiber': float(meal[9]) if meal[9] is not None else 0.0,
                    'sugars': float(meal[10]) if meal[10] is not None else 0.0,
                    'sodium': float(meal[11]) if meal[11] is not None else 0.0,
                    'status': meal[12]
                }
            
            totals = {
                'calories': sum(m['calories'] for m in meals_dict.values()),
                'fat': sum(m['fat'] for m in meals_dict.values()),
                'carbs': sum(m['carbs'] for m in meals_dict.values()),
                'protein': sum(m['protein'] for m in meals_dict.values())
            }
            
            reconstructed_plan[day_key] = {
                'date': current_date.isoformat(),
                'meals': meals_dict,
                'totals': totals
            }

        return jsonify({
            "message": "Diet plan fetched successfully",
            "weekly_plan": reconstructed_plan,
            "weekly_summary": {
                "start_date": weekly_plan[1].isoformat(),
                "end_date": weekly_plan[2].isoformat(),
                "date_generated": weekly_plan[3].isoformat(),
                "plan_calories": float(weekly_plan[4]),
                "plan_fats": float(weekly_plan[5]),
                "plan_carbs": float(weekly_plan[6]),
                "plan_protein": float(weekly_plan[7])
            }
        }), 200

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if recommender:
            recommender.close_connection()

@diet_bp.route('/log_intake', methods=['POST'])
def log_daily_intake():
    data = request.get_json()
    print(f"Raw incoming data: {data}")  # Debug all incoming data
    
    # Enhanced field handling
    recipe_name = data.get('recipe_name')
    if recipe_name is None:  # Explicit None check
        recipe_name = data.get('label')  # Try alternative field
        if recipe_name is None:  # Still None
            print("WARNING: No recipe name found in any field!")
            recipe_name = 'Custom Recipe'
        else:
            print("Used 'label' field as recipe_name")
    
    print(f"Final recipe_name: {recipe_name}")

    if not data or 'user_id' not in data or 'log_date' not in data:
        return jsonify({"error": "Missing required fields"}), 400

    recommender = None
    try:
        recommender = DietRecommendation(data['user_id'], RECIPE_CSV_PATH)
        recommender.conn.autocommit = False  # Start transaction
        
        # 1. Log the actual intake
        recommender.update_actual_intake(
            date.fromisoformat(data['log_date']),
            {
                'calories': float(data.get('calories', 0)),
                'fat': float(data.get('fat', 0)),
                'carbs': float(data.get('carbs', 0)),
                'protein': float(data.get('protein', 0))
            }
        )

        # 2. Add to daily_meal_plan if recipe data exists
        if 'recipe_id' in data and data['recipe_id']:
            # Get active weekly plan
            recommender.cursor.execute("""
                SELECT id FROM weekly_diet_plan 
                WHERE user_id = %s AND start_date <= %s AND end_date >= %s AND is_active = TRUE
                ORDER BY id DESC LIMIT 1
            """, (data['user_id'], data['log_date'], data['log_date']))
            
            weekly_plan = recommender.cursor.fetchone()
            
            if weekly_plan:
                weekly_plan_id = weekly_plan[0]
                
                # Count existing addon meals for this day
                recommender.cursor.execute("""
                    SELECT COUNT(*) FROM daily_meal_plan
                    WHERE weekly_plan_id = %s AND plan_date = %s 
                    AND meal_type LIKE 'addon%'
                """, (weekly_plan_id, data['log_date']))
                
                addon_count = recommender.cursor.fetchone()[0]
                meal_type = f"addon{addon_count + 1}" if addon_count > 0 else "addon"
                
                # Insert into daily_meal_plan
                recommender.cursor.execute("""
                    INSERT INTO daily_meal_plan (
                        weekly_plan_id, plan_date, meal_type, recipe_id, recipe_name,
                        servings, target_cal, target_fat, target_carbs, target_protein,
                        target_fiber, target_sugar, target_sodium, status, updated_at
                    ) VALUES (
                        %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s,
                        %s, %s, %s, 'completed', NOW()
                    )
                """, (
                    weekly_plan_id,
                    data['log_date'],
                    meal_type,  # This will be 'addon', 'addon1', 'addon2', etc.
                    data.get('recipe_id'),
                    data.get('recipe_name'),
                    float(data.get('servings', 1)),
                    float(data.get('calories', 0)),
                    float(data.get('fat', 0)),
                    float(data.get('carbs', 0)),
                    float(data.get('protein', 0)),
                    float(data.get('fiber', 0)),
                    float(data.get('sugars', 0)),
                    float(data.get('sodium', 0))
                ))
                print(f"Inserted as {meal_type} meal")

        recommender.conn.commit()
        return jsonify({"message": "Intake logged successfully"}), 200

    except Exception as e:
        if recommender and recommender.conn:
            recommender.conn.rollback()
        print(f"Error in log_intake: {str(e)}")
        return jsonify({"error": str(e)}), 500
    finally:
        if recommender:
            recommender.conn.autocommit = True
            recommender.close_connection()

@diet_bp.route('/update-status', methods=['POST'])
def update_meal_status():
    data = request.get_json()
    user_id = data.get('user_id')
    meal_date_str = date.fromisoformat(data.get('date')) # 'YYYY-MM-DD'
    meal_type = data.get('meal_type')
    status = data.get('status')

    if not all([user_id, meal_date_str, meal_type, status]):
        return jsonify({"error": "Missing required fields"}), 400

    recommender = None
    try:
        recommender = DietRecommendation(user_id, RECIPE_CSV_PATH)

        # Find the active weekly_plan_id for this user and date
        recommender.cursor.execute("""
            SELECT id FROM weekly_diet_plan 
            WHERE user_id = %s AND start_date <= %s AND end_date >= %s AND is_active = TRUE
        """, (user_id, meal_date_str, meal_date_str))

        row = recommender.cursor.fetchone()
        if not row:
            return jsonify({"error": "No active weekly plan found for given date"}), 404

        weekly_plan_id = row[0]

        # Now update the daily meal status with weekly_plan_id
        sql = """
            UPDATE daily_meal_plan
            SET status = %s
            WHERE weekly_plan_id = %s AND plan_date = %s AND meal_type = %s
        """
        recommender.cursor.execute(sql, (status, weekly_plan_id, meal_date_str, meal_type))
        recommender.conn.commit()

        return jsonify({"message": "Meal status updated successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if recommender:
            recommender.close_connection()


@diet_bp.route('/user_daily_targets', methods=['GET'])
def user_daily_targets():
    user_id = request.args.get('user_id')
    date_str = request.args.get('date')  # format: yyyy-mm-dd

    if not user_id or not date_str:
        return jsonify({"error": "Missing user_id or date"}), 400

    try:
        query = """
            SELECT total_calories, total_fat, total_carbs, total_protein
            FROM daily_log
            WHERE user_id = %s AND log_date = %s
        """
        recommender = DietRecommendation(user_id, RECIPE_CSV_PATH)
        recommender.cursor.execute(query, (user_id, date_str))
        row = recommender.cursor.fetchone()
        recommender.close_connection()

        if not row:
            return jsonify({"error": "No data found"}), 404

        return jsonify({
            "total_calories": float(row[0]),
            "total_fat": float(row[1]),
            "total_carbs": float(row[2]),
            "total_protein": float(row[3])
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@diet_bp.route('/actual_logs', methods=['GET'])
def get_actual_calorie_logs():
    """Returns daily actual calorie logs for a user, using DietRecommendation"""
    account_id = request.args.get('account_id')
    if not account_id:
        return jsonify({"error": "Missing account_id parameter"}), 400

    recommender = None
    try:
        # Step 1: Get user_id from account_id
        from db_functions import connect_to_database
        conn = connect_to_database()
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM users WHERE account_id = %s", (account_id,))
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "User not found"}), 404
        user_id = row[0]
        cursor.close()
        conn.close()

        # Step 2: Use DietRecommendation to access logs and user data
        recommender = DietRecommendation(user_id, RECIPE_CSV_PATH)
        recommender.load_user_data()

        recommender.cursor.execute("""
            SELECT log_date, actual_calories
            FROM daily_log
            WHERE user_id = %s
            ORDER BY log_date ASC
        """, (user_id,))
        rows = recommender.cursor.fetchall()

        logs = [
            {"date": row[0].isoformat(), "actual_calories": float(row[1])}
            for row in rows
        ]

        return jsonify({
            "target_calories": float(recommender.user_data['total_calories']),
            "logs": logs
        })

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

    finally:
        if recommender:
            recommender.close_connection()

@diet_bp.route('/finalize_previous_day', methods=['POST'])
def finalize_previous_day_endpoint():
    try:
        results = finalize_meal_status_and_logs()  
        return jsonify({
            "success": True,
            "results": results
        }), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

