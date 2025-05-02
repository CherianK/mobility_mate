from flask_admin import expose, AdminIndexView
from flask_admin.contrib.pymongo import ModelView
from flask_login import current_user, login_user, logout_user
from flask import url_for, redirect, request, flash
from .forms import LoginForm
from .auth import User
from wtforms import Form


# 🔒 Base view with authentication checks for secure admin views
class SecureModelView(ModelView):
    def is_accessible(self):
        return current_user.is_authenticated

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for('admin.login_view', next=request.url))


# 🏠 Custom admin dashboard (with login/logout)
class AdminIndexView(AdminIndexView):
    def __init__(self, mongo, **kwargs):
        super().__init__(**kwargs)
        self.mongo = mongo

    @expose('/')
    def index(self):
        print(">> current_user:", current_user)
        print(">> authenticated:", current_user.is_authenticated)

        if not current_user.is_authenticated:
            return redirect(url_for('.login_view'))

        return super().index()

    @expose('/login/', methods=('GET', 'POST'))
    def login_view(self):
        form = LoginForm()

        if request.method == 'POST':
            if form.validate():
                user_data = self.mongo.db.users.find_one({"username": form.username.data})

                if user_data:
                    if form.password.data == user_data["password"]:  # 🔐 Replace with check_password_hash if hashed
                        user = User(user_data["username"])
                        login_user(user)
                        next_url = request.args.get('next')
                        if next_url:
                            return redirect(next_url)
                        return redirect(url_for('.index'))
                    else:
                        flash('Invalid password', 'danger')
                else:
                    flash('User not found', 'danger')
            else:
                for field, errors in form.errors.items():
                    for error in errors:
                        flash(f'{field.title()}: {error}', 'warning')

        return self.render('admin/login.html', form=form)

    @expose('/logout/')
    def logout_view(self):
        logout_user()
        return redirect(url_for('.index'))


# 📋 View for MongoDB collections with read-only access
class ReadOnlyModelView(SecureModelView):
    column_list = ('Location_Lat', 'Location_Lon', 'Accessibility_Type_Name', 'Metadata', 'Tags')
    can_create = False
    can_edit = False
    can_delete = False

    def scaffold_form(self):
        return Form
