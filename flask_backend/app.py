from flask import Flask
from flask_cors import CORS
from routes.user_routes import user_bp

app = Flask(__name__)
CORS(app)

# Register routes
app.register_blueprint(user_bp)

# ✅ Define routes BEFORE running the app
@app.route('/')
def home():
    return "Welcome to MobilityMate API 🚀"

if __name__ == '__main__':
    app.run(debug=True)
