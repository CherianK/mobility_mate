from flask_login import UserMixin, LoginManager
from flask import redirect, request, url_for

login_manager = LoginManager()

class User(UserMixin):
    def __init__(self, username):
        self.username = username

    def get_id(self):
        return self.username

def init_login(app, mongo):
    login_manager.init_app(app)
    login_manager.login_view = 'admin.login_view'

@login_manager.user_loader
def load_user(username):
    from flask import current_app
    mongo = current_app.mongo
    user_data = mongo.db.users.find_one({"username": username})
    if user_data:
        return User(user_data["username"])
    return None