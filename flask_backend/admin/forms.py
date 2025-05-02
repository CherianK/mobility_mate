from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField
from wtforms.validators import InputRequired

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[
        InputRequired(message="Username is required")
    ])
    password = PasswordField('Password', validators=[
        InputRequired(message="Password is required")
    ])
