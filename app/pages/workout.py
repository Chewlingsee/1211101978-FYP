# workout.py (backend)
import os
from flask import Blueprint, request, jsonify
from db import mysql
from recommendation.exercise import load_exercise_db, generate_workout_recommendations, save_recommendations_to_db

workout_bp = Blueprint('workout_bp', __name__)


WORKOUT_CSV_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '../model/workout.csv'))

@workout_bp.route('/generate', methods=['POST'])
def generate_workout():
    data = request.json
    account_id = data.get('account_id')
    user_id = data.get('user_id')
    
    if not account_id or not user_id:
        return jsonify({"message": "Account ID and User ID are required"}), 400

    try:
        cursor = mysql.connection.cursor()

        # Verify the account_id and user_id match
        cursor.execute("""
            SELECT id FROM users 
            WHERE account_id = %s AND id = %s
            LIMIT 1
        """, (account_id, user_id))
        
        if not cursor.fetchone():
            cursor.close()
            return jsonify({"message": "User not found or IDs don't match"}), 404

        # Get user data including exercise preference
        cursor.execute("""
            SELECT id, account_id, name, age, gender, weight, height, 
                   activity_level, goal, exercise_recommendation, 
                   exercise_intensity, exercise_amount
            FROM users 
            WHERE id = %s
        """, [user_id])
        
        user_data = cursor.fetchone()
        
        if not user_data:
            cursor.close()
            return jsonify({"message": "User data not found"}), 404
            
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
            "exercise_recommendation": user_data[9],
            "exercise_intensity": user_data[10],
            "exercise_amount": user_data[11]
        }

        if user_dict['exercise_recommendation'].lower() != 'yes':
            # Delete details first due to FK constraint
            cursor.execute("""
                DELETE FROM workout_recommendation_details 
                WHERE recommendation_id IN (
                    SELECT id FROM workout_recommendations WHERE user_id = %s
                )
            """, [user_id])

            # Delete main recommendation entries
            cursor.execute("""
                DELETE FROM workout_recommendations WHERE user_id = %s
            """, [user_id])

            mysql.connection.commit()
            cursor.close()

            return jsonify({
                "message": "User opted no for exercise recommendation. No workout plan recommended.",
                "no_recommendation": True
            }), 200

        cursor.close()

        exercise_db = load_exercise_db(WORKOUT_CSV_PATH)
        recommendations = generate_workout_recommendations(user_dict, exercise_db)
        
        if not recommendations:
            return jsonify({"message": "No recommendations generated"}), 404

        save_success = save_recommendations_to_db(recommendations)

        return jsonify({
            "message": "Workout recommendations generated",
            "saved_to_db": save_success,
            "recommendations": recommendations
        }), 200

    except Exception as e:
        mysql.connection.rollback()
        return jsonify({"message": f"Error: {str(e)}"}), 500

    
@workout_bp.route('/history', methods=['GET'])
def get_workout_history():
    account_id = request.args.get('account_id')
    if not account_id:
        return jsonify({"message": "Account ID is required"}), 400

    try:
        cursor = mysql.connection.cursor()

        # Get user_id and exercise_recommendation from account_id
        cursor.execute("""
            SELECT id, exercise_recommendation 
            FROM users 
            WHERE account_id = %s
            LIMIT 1
        """, [account_id])
        user_result = cursor.fetchone()

        if not user_result:
            return jsonify({"message": "User not found"}), 404

        user_id, exercise_recommendation = user_result

        if exercise_recommendation.lower() != 'yes':
            return jsonify({
                "message": "User opted no for exercise recommendations. No history shown.",
                "no_recommendation": True
            }), 200

        # Get the latest workout recommendation
        cursor.execute("""
            SELECT wr.id, wr.date_generated, wr.daily_calorie_burn, 
                   wr.weekly_calorie_burn, wr.total_sessions, wr.end_date
            FROM workout_recommendations wr
            WHERE wr.user_id = %s
            ORDER BY wr.date_generated DESC
            LIMIT 1
        """, [user_id])

        recommendation = cursor.fetchone()

        if not recommendation:
            return jsonify({"message": "No workout history found"}), 404

        recommendation_id = recommendation[0]

        # Get the details for this recommendation
        cursor.execute("""
            SELECT workout_name, activity_type, intensity, 
                   minutes_per_session, calories_per_session, 
                   session_number, mets, status, completion_date
            FROM workout_recommendation_details
            WHERE recommendation_id = %s
            ORDER BY session_number ASC
        """, [recommendation_id])

        details = cursor.fetchall()
        cursor.close()

        # Format the response
        response = {
            "id": recommendation_id,
            "date": recommendation[1].isoformat(),
            "daily_calorie_burn": float(recommendation[2]),
            "weekly_calorie_burn": float(recommendation[3]),
            "total_sessions": recommendation[4],
            "end_date": recommendation[5].isoformat() if recommendation[5] else None,
            "recommendations": [
                {
                    "recommendation_id": recommendation_id,
                    "workout_name": row[0],
                    "activity_type": row[1],
                    "intensity": row[2],
                    "minutes_per_session": row[3],
                    "calories_per_session": float(row[4]),
                    "session_number": row[5],
                    "mets": float(row[6]),
                    "status": row[7],
                    "completion_date": row[8].isoformat() if row[8] else None
                } for row in details
            ]
        }

        return jsonify(response), 200

    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500


@workout_bp.route('/update-status', methods=['POST'])
def update_workout_status():
    data = request.get_json()
    
    try:
        account_id = int(data.get('account_id'))
        recommendation_id = int(data.get('recommendation_id'))
        session_number = int(data.get('session_number'))
        status = str(data.get('status'))
    except (TypeError, ValueError) as e:
        return jsonify({"error": "Invalid input types. account_id, recommendation_id, and session_number must be integers"}), 400

    completion_date = data.get('completion_date')  # This can be None

    if not all([account_id, recommendation_id, session_number, status]):
        return jsonify({"error": "Missing required fields"}), 400

    if status not in ['completed', 'skipped']:
        return jsonify({"error": "Status must be either 'completed' or 'skipped'"}), 400

    try:
        cursor = mysql.connection.cursor()
        
        # Verify the account has access to this recommendation
        cursor.execute("""
            SELECT wr.id 
            FROM workout_recommendations wr
            JOIN users u ON wr.user_id = u.id
            WHERE wr.id = %s AND u.account_id = %s
        """, (recommendation_id, account_id))
        
        if not cursor.fetchone():
            cursor.close()
            return jsonify({"error": "Recommendation not found or access denied"}), 404

        # Update the status
        update_query = """
            UPDATE workout_recommendation_details
            SET status = %s,
                completion_date = %s
            WHERE recommendation_id = %s AND session_number = %s
        """
        
        cursor.execute(update_query, (
            status,
            completion_date if status == 'completed' else None,
            recommendation_id,
            session_number
        ))
        
        mysql.connection.commit()
        cursor.close()
        
        return jsonify({
            "message": "Workout status updated successfully",
            "recommendation_id": recommendation_id,
            "session_number": session_number,
            "status": status
        }), 200

    except Exception as e:
        mysql.connection.rollback()
        return jsonify({"error": f"Failed to update workout status: {str(e)}"}), 500