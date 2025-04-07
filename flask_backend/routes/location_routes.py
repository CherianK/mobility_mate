# location_routes.py
from flask import Blueprint, jsonify
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
        # Retrieve all documents in the collection, excluding the _id field
        docs = list(toilet_locations.find({}, {"_id": 0}))
        if not docs:
            logger.info("No documents found in the collection.")
            return jsonify([])
        logger.info(f"Retrieved {len(docs)} documents.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching toilet locations: {e}")
        return jsonify({"error": str(e)}), 500