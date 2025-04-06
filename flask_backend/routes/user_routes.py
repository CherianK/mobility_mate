from flask import Blueprint, request, jsonify
from services.db_service import get_collection

user_bp = Blueprint('user_routes', __name__)
users = get_collection("users")

@user_bp.route('/add_user', methods=['POST'])
def add_user():
    data = request.json
    users.insert_one(data)
    return jsonify({"status": "success", "message": "User added"}), 200

@user_bp.route('/get_users', methods=['GET'])
def get_users():
    all_users = list(users.find({}, {'_id': 0}))
    return jsonify(all_users)