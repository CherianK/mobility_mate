# location_routes.py
from flask import Blueprint, jsonify, request
from services.db_service import get_collection
import logging

# Create a Blueprint to group related endpoints
location_bp = Blueprint('location_routes', __name__)

# Reference your collection name:
toilet_locations = get_collection("toilets-victoria")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@location_bp.route('/toilet-location-points', methods=['GET'])
def get_toilet_location_points():
    try:
        # Get bounding box from frontend (map viewport)
        min_lat = float(request.args.get("minLat"))
        max_lat = float(request.args.get("maxLat"))
        min_lon = float(request.args.get("minLon"))
        max_lon = float(request.args.get("maxLon"))

        # Filter only documents within the visible map area
        query = {
            "Location_Lat": { "$gte": min_lat, "$lte": max_lat },
            "Location_Lon": { "$gte": min_lon, "$lte": max_lon }
        }

        # Return only essential fields
        projection = {
            "_id": 0,
            "Location_Lat": 1,
            "Location_Lon": 1,
            "Tags": 1,
            "Accessibility_Type_Name": 1  #  include this field
        }

        # Limit results for performance (can adjust depending on zoom level)
        docs = list(toilet_locations.find(query, projection).limit(200))

        logger.info(f"Returned {len(docs)} toilets within bounds.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching toilet locations: {e}")
        return jsonify({"error": str(e)}), 500
