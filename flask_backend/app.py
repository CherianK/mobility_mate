from flask import Flask, redirect
from flask_cors import CORS
from flask_pymongo import PyMongo
from flask_admin import Admin
from dotenv import load_dotenv
import os

from routes.report_routes import report_bp
from routes.location_routes import location_bp
from routes.upload_routes import upload_bp
from routes.events import events_bp

from admin.views import ApprovalAdminView, AdminIndexView  # ✅ updated import
from admin.auth import init_login

# Load environment variables
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

# Initialize app and CORS
app = Flask(__name__)
CORS(app)

app.secret_key = os.getenv("SECRET_KEY")

# MongoDB setup
app.config["MONGO_URI"] = MONGO_URI
mongo = PyMongo(app)
app.mongo = mongo  # ✅ needed for auth

# Initialize login manager
init_login(app, mongo)

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

# ✅ Updated Flask-Admin setup with approval views
admin = Admin(app, name="MobilityMate Admin", template_mode="bootstrap4", index_view=AdminIndexView(mongo))

# Approval views for different collections
admin.add_view(ApprovalAdminView(mongo, "toilets-victoria", name="Toilet Approvals", endpoint="toilet_approval"))
admin.add_view(ApprovalAdminView(mongo, "trains-victoria", name="Train Approvals", endpoint="train_approval"))
admin.add_view(ApprovalAdminView(mongo, "trams-victoria", name="Tram Approvals", endpoint="tram_approval"))
admin.add_view(ApprovalAdminView(mongo, "medical-victoria", name="Hospital Approvals", endpoint="hospital_approval"))

# Run the app
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))  # fallback to port 10000
    app.run(host='0.0.0.0', port=port)