from flask import Blueprint, request, jsonify
from services.db_service import get_collection
import datetime

report_bp = Blueprint('report_routes', __name__)

# Get reference to the new MongoDB collection
reports_collection = get_collection("reports-victoria")

@report_bp.route('/report-issue', methods=['POST'])
def report_issue():
    try:
        data = request.get_json()

        # Add a timestamp automatically
        data['timestamp'] = datetime.datetime.utcnow()

        reports_collection.insert_one(data)

        return jsonify({"message": "Report submitted successfully!"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500