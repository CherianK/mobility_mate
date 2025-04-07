from flask import Blueprint, jsonify
from services.db_service import get_collection

location_bp = Blueprint('location_routes', __name__)
locations = get_collection("locations")

@location_bp.route('/get_all_locations', methods=['GET'])
def get_all_locations():
    
    projection = {
        "_id": 0,
        "id": 1,
        "lat": 1,
        "lon": 1,
        "tags": 1
    }

    results = list(locations.find({}, projection))  # Empty query: fetch all

    # Step 2: Simplify output for frontend
    simplified = []
    for loc in results:
        simplified.append({
            "id": loc.get("id"),
            "latitude": loc.get("lat"),
            "longitude": loc.get("lon"),
            "type": loc.get("tags", {}).get("amenity", "unknown"),
            "name": loc.get("tags", {}).get("name", "Unknown Location"),
            "wheelchair": loc.get("tags", {}).get("wheelchair", "unknown"),
            "unisex": loc.get("tags", {}).get("unisex", "unknown"),
        })

    return jsonify(simplified)
