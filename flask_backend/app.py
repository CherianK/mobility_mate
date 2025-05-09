from flask import Flask, redirect
from flask_cors import CORS
from flask_pymongo import PyMongo
from flask_admin import Admin
from dotenv import load_dotenv
import os

# Register routes
from routes.report_routes import report_bp
from routes.location_routes import location_bp
from routes.upload_routes import upload_bp
from routes.events import events_bp

# Admin views and login
from admin.views import ApprovalAdminView, AdminIndexView
from admin.auth import init_login

# Load environment variables
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Secret key for session management (should be set in .env)
app.secret_key = os.getenv("SECRET_KEY")

# MongoDB setup
app.config["MONGO_URI"] = MONGO_URI
mongo = PyMongo(app)
app.mongo = mongo  # Exposed for use in login manager

# Initialize login system
init_login(app, mongo)

# Register blueprints
app.register_blueprint(location_bp)
app.register_blueprint(report_bp)
app.register_blueprint(upload_bp)
app.register_blueprint(events_bp)

# Base route
@app.route('/')
def home():
    return "Welcome to MobilityMate API"

# Admin redirect helper
@app.route('/admin-redirect')
def redirect_to_admin():
    return redirect('/admin')

# Admin dashboard setup
admin = Admin(app, name="MobilityMate Admin", template_mode="bootstrap4", index_view=AdminIndexView(mongo))

# Approval-only views for each collection
admin.add_view(ApprovalAdminView(mongo, "toilets-victoria", name="Toilet Approvals", endpoint="toilet_approval"))
admin.add_view(ApprovalAdminView(mongo, "trains-victoria", name="Train Approvals", endpoint="train_approval"))
admin.add_view(ApprovalAdminView(mongo, "trams-victoria", name="Tram Approvals", endpoint="tram_approval"))
admin.add_view(ApprovalAdminView(mongo, "medical-victoria", name="Hospital Approvals", endpoint="hospital_approval"))

# Run the app
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))  # Fallback to port 10000 if not defined
    app.run(host='0.0.0.0', port=port)