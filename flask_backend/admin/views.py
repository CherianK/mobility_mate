from flask_admin import expose, AdminIndexView, BaseView
from flask_admin.contrib.pymongo import ModelView
from flask_login import current_user, login_user, logout_user
from flask import url_for, redirect, request, flash, render_template
from .forms import LoginForm
from .auth import User
from bson import ObjectId
from datetime import datetime


# 🔒 Secure model view requiring login
class SecureModelView(ModelView):
    def is_accessible(self):
        return current_user.is_authenticated

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for('admin.login_view', next=request.url))


# 🏠 Admin Dashboard with login/logout support
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
        form = LoginForm()
        if request.method == 'POST' and form.validate():
            user_data = self.mongo.db.users.find_one({"username": form.username.data})
            if user_data and form.password.data == user_data.get("password"):
                user = User(user_data["username"])
                login_user(user)
                return redirect(url_for('.index'))
            flash("Invalid username or password", "danger")
        return self.render('admin/login.html', form=form)

    @expose('/logout/')
    def logout_view(self):
        logout_user()
        return redirect(url_for('.index'))


# ✅ Simple Inline Image Approval View
class ApprovalAdminView(BaseView):
    def __init__(self, mongo, collection_name, **kwargs):
        super().__init__(**kwargs)
        self.mongo = mongo
        self.collection = mongo.db[collection_name]

    @expose('/')
    def index(self):
        if not current_user.is_authenticated:
            return redirect(url_for('admin.login_view'))

        locations = list(self.collection.find({
            "Images": {"$elemMatch": {"approved_status": False}}
        }))
        return self.render('admin/approve_list.html', locations=locations)

    @expose('/approve/<location_id>/<int:image_index>/', methods=['POST'])
    def approve_image(self, location_id, image_index):
        if not current_user.is_authenticated:
            return redirect(url_for('admin.login_view'))

        update_result = self.collection.update_one(
            {"_id": ObjectId(location_id)},
            {"$set": {
                f"Images.{image_index}.approved_status": True,
                f"Images.{image_index}.image_approved_time": datetime.utcnow().isoformat() + "Z"
            }}
        )

        if update_result.modified_count > 0:
            flash("✅ Image approved successfully", "success")
        else:
            flash("⚠️ Failed to approve image", "danger")

        return redirect(url_for(f'{request.endpoint.split(".")[0]}.index'))
