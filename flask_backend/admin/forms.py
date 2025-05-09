# forms.py
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, HiddenField
from wtforms.validators import DataRequired

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[
        DataRequired(message="Username is required")
    ])
    password = PasswordField('Password', validators=[
        DataRequired(message="Password is required")
    ])
