from flask_admin.contrib.pymongo import ModelView
from flask_admin import expose, AdminIndexView
from flask_login import current_user, login_user, logout_user
from flask import url_for, redirect, request
from .forms import LoginForm
from .auth import User
from wtforms import Form

class AdminBaseView:
    def is_accessible(self):
        return current_user.is_authenticated

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for('admin.login_view', next=request.url))

class AdminIndexView(AdminIndexView):
    def __init__(self, mongo, **kwargs):
        super().__init__(**kwargs)
        self.mongo = mongo

    @expose('/')
    def index(self):
        if not current_user.is_authenticated:
            return redirect(url_for('.login_view'))
        return super().index()

    @expose('/login/', methods=('GET', 'POST'))
    def login_view(self):
        form = LoginForm(request.form)
        if request.method == 'POST' and form.validate():
            user_data = self.mongo.db.users.find_one({"username": form.username.data})
            if user_data and user_data['password'] == form.password.data:
                user = User(form.username.data)
                login_user(user)
                return redirect(url_for('.index'))
        return self.render('login.html', form=form)

    @expose('/logout/')
    def logout_view(self):
        logout_user()
        return redirect(url_for('.index'))

class ReadOnlyModelView(AdminBaseView, ModelView):
    column_list = ('Location_Lat', 'Location_Lon', 'Accessibility_Type_Name', 'Metadata', 'Tags')
    can_create = False
    can_edit = False
    can_delete = False

    def scaffold_form(self):
        return Form