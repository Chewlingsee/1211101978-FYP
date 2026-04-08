from flask import Flask
from db import init_db
from authorization.auth import auth_bp
from authorization.survey import survey_bp
from pages.profile import profile_bp
from pages.workout import workout_bp
from pages.diet_rec import diet_bp
from pages.classify import classify_bp
from pages.search import search_bp
from pages.tracking import tracking_bp

def create_app():
    app = Flask(__name__)
    init_db(app)

    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(survey_bp, url_prefix='/survey')
    app.register_blueprint(profile_bp, url_prefix='/profile')
    app.register_blueprint(workout_bp, url_prefix='/workout')
    app.register_blueprint(diet_bp, url_prefix='/diet')
    app.register_blueprint(classify_bp)
    app.register_blueprint(search_bp)
    app.register_blueprint(tracking_bp, url_prefix='/tracking')

    return app

if __name__ == '__main__':
    app = create_app()
    app.run(debug=True)