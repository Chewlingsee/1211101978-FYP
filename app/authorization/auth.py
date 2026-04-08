from flask import Blueprint, request, jsonify
from db import mysql
from flask_mysqldb import MySQL
import json
from werkzeug.security import generate_password_hash, check_password_hash


auth_bp = Blueprint('auth_bp', __name__)

@auth_bp.route('/login', methods=['POST'])
def login():
    email = request.json.get('email')
    password = request.json.get('password')

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT id, password FROM account WHERE email = %s", [email])
    result = cursor.fetchone()

    if result:
        stored_password = result[1]
        # Use proper hash checking
        if check_password_hash(stored_password, password):
            account_id = result[0]
            
            cursor.execute("SELECT * FROM users WHERE account_id = %s", [account_id])
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
                    "exercise_recommendation": user_data[12]
                }

                # Fetch metrics from the matrices table
                cursor.execute("SELECT * FROM matrices WHERE user_id = %s", [user_dict['id']])
                metrics_data = cursor.fetchone()

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
                    "message": "Login successful!",
                    "account_id": account_id,
                    "user_data": user_dict,
                    "metrics": metrics
                }), 200
            else:
                return jsonify({"message": "User data not found!"}), 404
        else:
            return jsonify({"message": "Incorrect password!"}), 401
    else:
        return jsonify({"message": "Email not found!"}), 404
    
@auth_bp.route('/register', methods=['POST'])
def register():
    email = request.json.get('email')
    password = request.json.get('password')

    if not email or not password:
        return jsonify({"message": "Email and password are required!"}), 400

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM account WHERE email = %s", [email])
    existing_user = cursor.fetchone()

    if existing_user:
        return jsonify({"message": "Email already registered!"}), 409
    
    # HASH the password here before saving!
    hashed_password = generate_password_hash(password)

    cursor.execute(
        "INSERT INTO account (email, password) VALUES (%s, %s)", 
        (email, hashed_password)
    )

    mysql.connection.commit()
    account_id = cursor.lastrowid
    cursor.close()

    return jsonify({"message": "Registration successful!", "account_id": account_id}), 201

@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    email = request.json.get('email')
    if not email:
        return jsonify({'message': 'Email is required'}), 400

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM account WHERE email = %s", [email])
    account = cursor.fetchone()
    cursor.close()

    if account:
        return jsonify({'message': 'Email is valid'}), 200
    else:
        return jsonify({'message': 'Email not found'}), 404

@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
    email = request.json.get('email')
    new_password = request.json.get('new_password')

    if not email or not new_password:
        return jsonify({'message': 'Email and new password are required'}), 400

    cursor = mysql.connection.cursor()
    cursor.execute("SELECT * FROM account WHERE email = %s", [email])
    account = cursor.fetchone()

    if not account:
        cursor.close()
        return jsonify({'message': 'Email not found'}), 404

    hashed_password = generate_password_hash(new_password)

    cursor.execute("UPDATE account SET password = %s WHERE email = %s", (hashed_password, email))
    mysql.connection.commit()
    cursor.close()

    return jsonify({'message': 'Password reset successful!'}), 200
