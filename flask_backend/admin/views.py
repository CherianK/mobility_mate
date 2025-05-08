# views.py

from flask_admin import expose, AdminIndexView, BaseView
from flask_admin.contrib.pymongo import ModelView
from flask_login import current_user, login_user, logout_user
from flask import url_for, redirect, request, flash, render_template
from .forms import LoginForm, ApprovalForm
from .auth import User
from bson import ObjectId
from datetime import datetime

# 🔒 Secured base model view
class SecureModelView(ModelView):
    def is_accessible(self):
        return current_user.is_authenticated

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for('admin.login_view', next=request.url))


# 🏠 Admin dashboard with login/logout views
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


# ✅ Image Approval View (instead of edit)
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

    @expose('/approve/<location_id>/<int:image_index>/', methods=['GET', 'POST'])
    def approve_image(self, location_id, image_index):
        if not current_user.is_authenticated:
            return redirect(url_for('admin.login_view'))

        location = self.collection.find_one({"_id": ObjectId(location_id)})
        if not location:
            flash("Location not found", "danger")
            return redirect(url_for('.index'))

        try:
            image_data = location.get("Images", [])[image_index]
        except IndexError:
            flash("Image not found at the specified index", "danger")
            return redirect(url_for('.index'))

        form = ApprovalForm(
            image_url=image_data.get("image_url"),
            location_id=str(location_id),
            image_index=str(image_index),
            approved_status=image_data.get("approved_status", False)
        )

        if form.validate_on_submit():
            approved = form.approved_status.data
            approved_time = datetime.utcnow().isoformat() + "Z" if approved else None
            self.collection.update_one(
                {"_id": ObjectId(location_id)},
                {"$set": {
                    f"Images.{image_index}.approved_status": approved,
                    f"Images.{image_index}.image_approved_time": approved_time
                }}
            )
            flash("Image approval updated", "success")
            return redirect(url_for('.index'))

        return self.render('admin/approve_image.html', form=form, image=image_data)