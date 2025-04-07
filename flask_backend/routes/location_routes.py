# location_routes.py
from flask import Blueprint, jsonify
from services.db_service import get_collection

# Create a Blueprint to group related endpoints
location_bp = Blueprint('location_routes', __name__)

# Reference your collection name:
locations = get_collection("test-location-db")

@location_bp.route('/location-points', methods=['GET'])
def get_location_points():
    """
    Fetches the single document and returns the 'elements' array.
    """
    # find_one({}) -> grabs the first document in this collection
    # {"_id": 0, "elements": 1} -> project only the 'elements' field, hide the '_id'
    doc = locations.find_one({}, {"_id": 0, "elements": 1})
    
    if not doc:
        # If no document was found, return empty list
        return jsonify([])
    
    # Return the contents of the 'elements' array
    return jsonify(doc["elements"])
