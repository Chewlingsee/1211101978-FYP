# db.py
from flask_mysqldb import MySQL

mysql = MySQL()

def init_db(app):
    app.config['MYSQL_HOST'] = 'localhost'
    app.config['MYSQL_USER'] = 'root'
    app.config['MYSQL_PASSWORD'] = 'Clsee2344.'
    app.config['MYSQL_DB'] = 'caloriewise'
    mysql.init_app(app)
