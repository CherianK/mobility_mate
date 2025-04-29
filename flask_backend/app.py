from flask import Flask, redirect
from flask_cors import CORS
from flask_pymongo import PyMongo
from flask_admin import Admin
from wtforms import Form
from dotenv import load_dotenv
import os
from routes.report_routes import report_bp
from routes.location_routes import location_bp
from routes.upload_routes import upload_bp
from routes.events import events_bp
from admin.views import ReadOnlyModelView

# Load environment variables
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

# Initialize app and CORS
app = Flask(__name__)
CORS(app)

# MongoDB setup
app.config["MONGO_URI"] = MONGO_URI
mongo = PyMongo(app)

# Register API routes
app.register_blueprint(location_bp)
app.register_blueprint(report_bp)
app.register_blueprint(upload_bp)
app.register_blueprint(events_bp)

# Home route
@app.route('/')
def home():
    return "Welcome to MobilityMate API"

# Redirect to admin dashboard
@app.route('/admin-redirect')
def redirect_to_admin():
    return redirect('/admin')

# Admin setup
admin = Admin(app, name="MobilityMate Admin", template_mode="bootstrap4")

# Register MongoDB collections
admin.add_view(ReadOnlyModelView(mongo.db["toilets-victoria"], "Toilets"))
admin.add_view(ReadOnlyModelView(mongo.db["trains-victoria"], "Trains"))
admin.add_view(ReadOnlyModelView(mongo.db["trams-victoria"], "Trams"))
admin.add_view(ReadOnlyModelView(mongo.db["medical-victoria"], "Hospitals"))

# Render-compatible launch
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))  # Fallback to 10000
    app.run(host='0.0.0.0', port=port)
