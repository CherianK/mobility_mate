from flask import Flask, redirect
from flask_cors import CORS
from flask_pymongo import PyMongo
from flask_admin import Admin
from flask_admin.contrib.pymongo import ModelView
from dotenv import load_dotenv
import os
from wtforms import Form

from routes.location_routes import location_bp  # 🔁 Import your blueprint

# Load environment variables from .env or Render environment
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

app = Flask(__name__)
CORS(app)
app.config["MONGO_URI"] = MONGO_URI
mongo = PyMongo(app)

# 🔁 Register the API blueprint
app.register_blueprint(location_bp)

# 🧠 Custom admin view
class ReadOnlyModelView(ModelView):
    column_list = ('Location_Lat', 'Location_Lon', 'Accessibility_Type_Name', 'Metadata', 'Tags')
    can_create = False
    can_edit = False
    can_delete = False

    def scaffold_form(self):
        return Form

# 🛠 Setup Flask Admin
admin = Admin(app, name="MobilityMate Admin", template_mode="bootstrap4")
admin.add_view(ReadOnlyModelView(mongo.db["toilets-victoria"], "Toilets"))
admin.add_view(ReadOnlyModelView(mongo.db["trains-victoria"], "Trains"))
admin.add_view(ReadOnlyModelView(mongo.db["trams-victoria"], "Trams"))
admin.add_view(ReadOnlyModelView(mongo.db["medical-victoria"], "Hospitals"))

@app.route('/')
def home():
    return redirect("/admin")  # Default landing page

if __name__ == "__main__":
    app.run(debug=True)
