from flask import Blueprint, request, jsonify
from datetime import date
import datetime
from db_functions import connect_to_database
from rule_based import process_user
import json
import traceback
from db import mysql

tracking_bp = Blueprint('tracking', __name__)

@tracking_bp.route('/update_weight', methods=['POST'])
def update_weight():
    data = request.get_json()
    user_id = data.get('user_id')
    new_weight = data.get('weight')
    log_date = data.get('date')

    if not all([user_id, new_weight, log_date]):
        return jsonify({"error": "Missing user_id, weight, or date"}), 400

    try:
        conn = connect_to_database()
        cursor = conn.cursor()

        # 1. Update weight_history
        cursor.execute("""
            INSERT INTO weight_history (user_id, weight, log_date)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE weight = VALUES(weight)
        """, (user_id, new_weight, log_date))

        # 2. If log_date == end_date of active plan or today -> update user's weight
        today = date.today().isoformat()
        cursor.execute("""
            SELECT end_date FROM weekly_diet_plan
            WHERE user_id = %s AND is_active = TRUE
        """, (user_id,))
        active_plan = cursor.fetchone()

        if active_plan:
            end_date = active_plan[0].isoformat()
            if log_date == end_date or log_date == today:
                cursor.execute("""
                    UPDATE users SET weight = %s WHERE id = %s
                """, (new_weight, user_id))

        # 3. Fetch updated user data
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        columns = [col[0] for col in cursor.description]
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "User not found after weight update"}), 404

        user_dict = dict(zip(columns, row))

        # Parse JSON fields correctly for rule-based logic
        if isinstance(user_dict.get("diseases"), str):
            user_dict["diseases"] = json.loads(user_dict["diseases"])
        if isinstance(user_dict.get("allergies"), str):
            user_dict["allergies"] = json.loads(user_dict["allergies"])
        if isinstance(user_dict.get("meal_types"), str):
            user_dict["meal_types"] = json.loads(user_dict["meal_types"])

        # 4. Recalculate metrics
        output = process_user(user_dict)

        # 5. Update matrices table with recalculated metrics
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
                meal_calories = %s
            WHERE user_id = %s
        """, (
            output['bmi'],
            output['bmi_category'],
            output['rmr'],
            output['tdee'],
            output['total_calories'],
            json.dumps(output['macronutrient_split']),
            json.dumps(output['macronutrient_grams']),
            json.dumps(output['meal_distribution']),
            json.dumps(output['meal_calories']),
            user_id
        ))

        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"message": "Weight and metrics updated successfully"}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@tracking_bp.route('/get_weight_history', methods=['GET'])
def weight_history():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({"error": "Missing 'user_id'"}), 400

    try:
        cursor = mysql.connection.cursor()

        cursor.execute("""
            SELECT weight, log_date 
            FROM weight_history 
            WHERE user_id = %s
            ORDER BY log_date ASC
        """, [user_id])
        
        weight_data = cursor.fetchall()
        cursor.close()

        if not weight_data:
            return jsonify({"message": "No weight history found"}), 404

        formatted_data = [
            {
                "date": log_date.strftime('%Y-%m-%d'),
                "weight": float(weight)
            }
            for weight, log_date in weight_data
        ]

        return jsonify({
            "success": True,
            "data": formatted_data
        }), 200

    except Exception as e:
        return jsonify({
            "error": f"Failed to fetch weight history: {str(e)}"
        }), 500