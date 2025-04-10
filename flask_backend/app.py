from flask import Flask
from flask_cors import CORS
from routes.location_routes import location_bp
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)
CORS(app)



app.register_blueprint(location_bp) 
#  Define routes BEFORE running the app
@app.route('/')
def home():
    return "Welcome to MobilityMate API "

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))  # Default to 10000 just in case
    app.run(debug=False, host='0.0.0.0', port=port)
