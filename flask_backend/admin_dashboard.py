from flask import Flask, redirect
from flask_pymongo import PyMongo
from flask_admin import Admin
from flask_admin.contrib.pymongo import ModelView
from flask_cors import CORS
from dotenv import load_dotenv
from wtforms import Form
import os

# Load environment variables
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

app = Flask(__name__)
CORS(app)
app.config["MONGO_URI"] = MONGO_URI
mongo = PyMongo(app)

admin = Admin(app, name="MobilityMate Admin", template_mode="bootstrap4")

# Shared base view
class ReadOnlyView(ModelView):
    column_list = ('Location_Lat', 'Location_Lon', 'Accessibility_Type_Name', 'Metadata', 'Tags')

    can_create = False
    can_edit = False
    can_delete = True  # ✅ Enable delete functionality

    def scaffold_form(self):
        return Form  # disables edit form generation to prevent NotImplementedError

# Register views for each collection
admin.add_view(ReadOnlyView(mongo.db["toilets-victoria"], 'Toilets'))
admin.add_view(ReadOnlyView(mongo.db["trains-victoria"], 'Trains'))
admin.add_view(ReadOnlyView(mongo.db["trams-victoria"], 'Trams'))
admin.add_view(ReadOnlyView(mongo.db["medical-victoria"], 'Hospitals'))

@app.route('/')
def home():
    return redirect('/admin')

if __name__ == "__main__":
    app.run(debug=False)
