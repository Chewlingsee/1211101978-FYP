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
    Safely fetch user data, ensuring DB resources are closed.
    Returns:
        dict: User info if found, None otherwise.
    """
    conn = None
    cursor = None
    try:
        conn = connect_to_database()
        if conn is None:
            return None
        
        cursor = conn.cursor(dictionary=True)
        query = "SELECT * FROM users WHERE id = %s"
        cursor.execute(query, (user_id,))
        return cursor.fetchone()  # Return here, cleanup happens in 'finally'
    
    except Error as e:
        print(f"Database error: {e}")
        return None
    
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()