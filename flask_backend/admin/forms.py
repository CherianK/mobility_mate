from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField
from wtforms.validators import InputRequired
from wtforms import Form

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[
        InputRequired(message="Username is required")
    ])
    password = PasswordField('Password', validators=[
        InputRequired(message="Password is required")
    ])

class EditForm(Form):
    Location_Lat = StringField('Latitude')
    Location_Lon = StringField('Longitude')
    Accessibility_Type_Name = StringField('Type')
    Metadata = StringField('Metadata')
    Tags = StringField('Tags')           