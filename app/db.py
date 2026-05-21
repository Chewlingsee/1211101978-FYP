# db.py
from flask_mysqldb import MySQL

mysql = MySQL()

def init_db(app):
    app.config['MYSQL_HOST'] = 'host_name'
    app.config['MYSQL_USER'] = 'user_name'
    app.config['MYSQL_PASSWORD'] = ''
    app.config['MYSQL_DB'] = 'database_name'
    mysql.init_app(app)
