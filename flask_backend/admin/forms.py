from wtforms import Form, StringField, PasswordField, validators

class LoginForm(Form):
    username = StringField('Username', [
        validators.InputRequired(message="Username is required")
    ])
    password = PasswordField('Password', [
        validators.InputRequired(message="Password is required")
    ])