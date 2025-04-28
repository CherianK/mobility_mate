from flask_admin.contrib.pymongo import ModelView
from wtforms import Form

class ReadOnlyModelView(ModelView):
    """Admin view for read-only access to MongoDB collections with limited editing capabilities."""
    
    column_list = ('Location_Lat', 'Location_Lon', 'Accessibility_Type_Name', 'Metadata', 'Tags')
    can_create = True
    can_edit = True
    can_delete = False

    def scaffold_form(self):
        return Form 