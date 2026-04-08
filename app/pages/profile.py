import json
from datetime import date
from flask import Blueprint, request, jsonify, current_app
from db import mysql
from rule_based import process_user


profile_bp = Blueprint('profile_bp', __name__)

@profile_bp.route('', methods=['GET'])
def profile():
    account_id = request.args.get('account_id')
    print(f"Fetching profile data for account_id: {account_id}")  

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM users WHERE account_id = %s", [account_id])
    user_data = cursor.fetchone()

    if user_data:
        print(f"User data fetched: {user_data}") 
        user_dict = {
            "id": user_data[0],
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

        cursor.execute("SELECT * FROM matrices WHERE user_id = %s", [user_dict['id']])
        metrics_data = cursor.fetchone()
        print(f"Metrics data fetched: {metrics_data}")  

        if metrics_data:
            metrics = {
                "bmi": metrics_data[2],
                "bmi_category": metrics_data[3],
                "rmr": metrics_data[4],
                "tdee": metrics_data[5],
                "total_calories": metrics_data[6]
            }
        else:
            metrics = None

        return jsonify({
            "message": "Profile data fetched successfully!",
            "account_id": account_id,
            "user_data": user_dict,
            "metrics": metrics
        }), 200
    else:
        print("User not found in the database") 
        return jsonify({"message": "User not found"}), 404
    
@profile_bp.route('/user_id', methods=['GET'])
def get_user_id():
    account_id = request.args.get('account_id')
    print("Incoming account_id:", account_id)

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT id FROM users WHERE account_id = %s", [account_id])
    result = cursor.fetchone()

    if result:
        print("Found user_id:", result[0])
        return jsonify({'user_id': result[0]}), 200
    else:
        print("No user found with account_id =", account_id)
        return jsonify({'message': 'User not found'}), 404
    
@profile_bp.route('/update_profile', methods=['POST'])
def update_profile():
    data = request.get_json()
    if not data:
        return jsonify({"message": "No data provided"}), 400

    user_id = data.get('user_id')
    if not user_id:
        return jsonify({"message": "User ID is required"}), 400

    cursor = mysql.connection.cursor()
    try:
        # Verify user exists
        cursor.execute("SELECT id FROM users WHERE id = %s", [user_id])
        if not cursor.fetchone():
            return jsonify({"message": "User not found"}), 404

        # Prepare update fields
        update_fields = {}
        fields_to_update = [
            'name', 'age', 'weight', 'height', 'goal', 
            'activity_level', 'exercise_recommendation',
            'exercise_intensity', 'exercise_amount'
        ]

        for field in fields_to_update:
            if field in data and data[field] is not None:
                # Special handling for exercise fields
                if field == 'exercise_recommendation':
                    rec = data[field].lower()
                    update_fields[field] = rec
                    # If changing to "no", clear intensity and amount
                    if rec == 'no':
                        update_fields['exercise_intensity'] = 'none'
                        update_fields['exercise_amount'] = 'none'
                elif field in ['exercise_intensity', 'exercise_amount']:
                    # Only include if recommendation is "yes"
                    if data.get('exercise_recommendation', '').lower() == 'yes':
                        update_fields[field] = data[field]
                else:
                    update_fields[field] = data[field]

        if 'weight' in update_fields:
            today = date.today().isoformat()
            
            # Check if weight entry exists for today
            cursor.execute("""
                SELECT id FROM weight_history 
                WHERE user_id = %s AND log_date = %s
            """, (user_id, today))
            
            if cursor.fetchone():
                # Update existing weight entry
                cursor.execute("""
                    UPDATE weight_history 
                    SET weight = %s 
                    WHERE user_id = %s AND log_date = %s
                """, (update_fields['weight'], user_id, today))
            else:
                # Insert new weight entry
                cursor.execute("""
                    INSERT INTO weight_history (user_id, weight, log_date)
                    VALUES (%s, %s, %s)
                """, (user_id, update_fields['weight'], today))

        # Build and execute update query for user
        if update_fields:
            set_clause = ", ".join([f"{k} = %s" for k in update_fields])
            query = f"UPDATE users SET {set_clause} WHERE id = %s"
            args = list(update_fields.values()) + [user_id]
            cursor.execute(query, args)

        # Get updated user data
        cursor.execute("SELECT * FROM users WHERE id = %s", [user_id])
        updated_user = cursor.fetchone()
        
        if not updated_user:
            return jsonify({"message": "Failed to fetch updated user"}), 500

        user_dict = {
            "id": updated_user[0],
            "account_id": updated_user[1],
            "name": updated_user[2],
            "age": updated_user[3],
            "gender": updated_user[4],
            "weight": updated_user[5],
            "height": updated_user[6],
            "activity_level": updated_user[7],
            "goal": updated_user[8],
            "diseases": json.loads(updated_user[9]) if updated_user[9] else [],
            "allergies": json.loads(updated_user[10]) if updated_user[10] else [],
            "meal_types": json.loads(updated_user[11]) if updated_user[11] else [],
            "exercise_recommendation": updated_user[12],
            "exercise_intensity": updated_user[13],
            "exercise_amount": updated_user[14]
        }

        # Recalculate metrics (assuming process_user exists)
        output = process_user(user_dict) if 'process_user' in globals() else {}

        # Update matrices table 
        cursor.execute("""
            UPDATE matrices SET
                bmi = %s,
                bmi_category = %s,
                rmr = %s,
                tdee = %s,
                total_calories = %s,
                macronutrient_split = %s,
                macronutrient_grams = %s,
                meal_distribution = %s,
                meal_calories = %s,
                diet_labels = %s,
                health_labels = %s,
                exercise_adjustment = %s
            WHERE user_id = %s
        """, (
            output.get('bmi'),
            output.get('bmi_category'),
            output.get('rmr'),
            output.get('tdee'),
            output.get('total_calories'),
            json.dumps(output.get('macronutrient_split', {})),
            json.dumps(output.get('macronutrient_grams', {})),
            json.dumps(output.get('meal_distribution', {})),
            json.dumps(output.get('meal_calories', {})),
            json.dumps(output.get('diet_labels', [])),
            json.dumps(output.get('health_labels', [])),
            output.get('exercise_adjustment'),
            user_id
        ))

        mysql.connection.commit()

        return jsonify({
            "message": "Profile updated successfully",
            "user": user_dict,
            "metrics": output
        }), 200

    except Exception as e:
        mysql.connection.rollback()
        current_app.logger.error(f"Error updating profile: {str(e)}")
        return jsonify({"message": "Internal server error"}), 500
    finally:
        cursor.close()


