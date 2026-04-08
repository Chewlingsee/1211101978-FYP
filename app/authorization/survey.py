import json
from flask import Blueprint, request, jsonify, current_app
from db import mysql
from rule_based import process_user
from datetime import date

survey_bp = Blueprint('survey_bp', __name__)

@survey_bp.route('/submit_survey', methods=['POST'])
def submit_survey():
    data = request.json
    current_app.logger.info(f"Incoming request data: {data}")  # Log the request data

    account_id = data.get('account_id')
    name = data.get('name')
    age = data.get('age')
    weight = data.get('weight')
    height = data.get('height')
    gender = data.get('gender')
    goal = data.get('goal')
    activity_level = data.get('activity_level')
    diseases = json.dumps(data.get('diseases', []))
    allergies = json.dumps(data.get('allergies', []))
    meal_types = json.dumps(data.get('meal_types', []))
    exercise_recommendation = data.get('exercise_recommendation', 'no')
    exercise_intensity = data.get('exercise_intensity', 'none') if exercise_recommendation == 'yes' else 'none'
    exercise_amount = data.get('exercise_amount', 'none') if exercise_recommendation == 'yes' else 'none'


    if not account_id:
        return jsonify({"message": "Account ID is required!"}), 400

    # Validate gender
    if gender not in ['male', 'female']:
        return jsonify({"message": "Invalid gender value!"}), 400

    cursor = mysql.connection.cursor()

    try:
        # Insert user data into the users table
        query = """
            INSERT INTO users (
                account_id, name, age, gender, weight, height, activity_level, goal,
                diseases, allergies, meal_types, exercise_recommendation, exercise_intensity, exercise_amount
            ) VALUES (%s, %s,%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        args = (
            account_id, name, age, gender, weight, height, activity_level, goal,
            diseases, allergies, meal_types, exercise_recommendation, exercise_intensity, exercise_amount
        )
        cursor.execute(query, args)
        mysql.connection.commit()

        # Fetch the newly inserted user data
        cursor.execute("SELECT * FROM users WHERE account_id = %s ORDER BY id DESC LIMIT 1", [account_id])
        user_data = cursor.fetchone()

        if user_data:
            user_dict = {
                "id": user_data[0],
                "account_id": user_data[1],
                "name": user_data[2],
                "age": user_data[3],
                "gender": user_data[4],
                "weight": user_data[5],
                "height": user_data[6],
                "activity_level": user_data[7],
                "goal": user_data[8],
                "diseases": json.loads(user_data[9]),
                "allergies": json.loads(user_data[10]),
                "meal_types": json.loads(user_data[11]),
                "exercise_recommendation": user_data[12],
                "exercise_intensity": user_data[13],
                "exercise_amount": user_data[14]
            }

            # Store initial weight in weight_history
            today = date.today().isoformat()
            cursor.execute("""
                INSERT INTO weight_history (user_id, weight, log_date)
                VALUES (%s, %s, %s)
            """, (user_dict['id'], weight, today))

            # Call the rule-based system to get diet and health labels and calculate metrics
            output = process_user(user_dict)

            # Insert calculated data into the matrices table
            cursor.execute("""
                INSERT INTO matrices (
                    user_id, bmi, bmi_category, rmr, tdee, total_calories, 
                    macronutrient_split, macronutrient_grams,  meal_distribution, meal_calories,
                    diet_labels, health_labels, exercise_adjustment
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                user_dict['id'],
                output['bmi'],
                output['bmi_category'],
                output['rmr'],
                output['tdee'],
                output['total_calories'],
                json.dumps(output['macronutrient_split']), 
                json.dumps(output['macronutrient_grams']),  
                json.dumps(output['meal_distribution']), 
                json.dumps(output['meal_calories']), 
                json.dumps(output['diet_labels']),  
                json.dumps(output['health_labels']),  
                output['exercise_adjustment'],
            ))

            mysql.connection.commit()

            cursor.close()
            return jsonify({
                "message": "Survey data submitted successfully!",
                "user_id": user_dict['id'],
                "metrics": output
            }), 201
        else:
            cursor.close()
            return jsonify({"message": "Failed to fetch user data after insertion!"}), 500
    except Exception as e:
        mysql.connection.rollback()
        cursor.close()
        current_app.logger.error(f"Error in submit_survey: {str(e)}")
        return jsonify({"message": f"Error: {str(e)}"}), 500