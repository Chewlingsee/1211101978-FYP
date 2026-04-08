import mysql.connector
from mysql.connector import Error

# Database connection details
DB_HOST = 'localhost'
DB_USER = 'root'
DB_PASSWORD = 'Clsee2344.'
DB_NAME = 'caloriewise'

def connect_to_database():
    """Establish a MySQL database connection."""
    try:
        connection = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        return connection
    except Error as e:
        print(f"Error: {e}")
        return None

def fetch_user_info(user_id):
    """
    Fetch user data from MySQL database.
    """
    conn = connect_to_database()
    if conn is None:
        return None
    cursor = conn.cursor(dictionary=True)
    query = "SELECT * FROM users WHERE id = %s"
    cursor.execute(query, (user_id,))
    user_info = cursor.fetchone()
    cursor.close()
    conn.close()
    return user_info