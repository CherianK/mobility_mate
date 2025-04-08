from flask import Flask
from flask_cors import CORS
from routes.location_routes import location_bp
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)



app.register_blueprint(location_bp) 
#  Define routes BEFORE running the app
@app.route('/')
def home():
    return "Welcome to MobilityMate API "



if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
