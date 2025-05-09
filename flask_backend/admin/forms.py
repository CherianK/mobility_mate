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

class ApprovalForm(FlaskForm):
    image_url = StringField('Image URL', render_kw={'readonly': True})
    approved_status = BooleanField('Approve this image?')
    location_id = HiddenField('Location ID', validators=[DataRequired()])
    image_index = HiddenField('Image Index', validators=[DataRequired()])