# location_routes.py
from flask import Blueprint, jsonify
from services.db_service import get_collection
import logging

# Create a Blueprint to group related endpoints
location_bp = Blueprint('location_routes', __name__)

# Reference your collection names:
toilet_locations = get_collection("toilets-victoria")
train_locations = get_collection("trains-victoria")
tram_locations = get_collection("trams-victoria")
medical_locations = get_collection("medical-victoria")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@location_bp.route('/toilet-location-points', methods=['GET'])
def get_toilet_location_points():
    """Returns documents from 'toilets-victoria'."""
    try:
        docs = list(toilet_locations.find({}, {"_id": 0}))
        logger.info(f"Retrieved {len(docs)} toilet documents.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching toilet locations: {e}")
        return jsonify({"error": str(e)}), 500

@location_bp.route('/train-location-points', methods=['GET'])
def get_train_location_points():
    """Returns documents from 'trains-victoria'."""
    try:
        docs = list(train_locations.find({}, {"_id": 0}))
        logger.info(f"Retrieved {len(docs)} train documents.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching train locations: {e}")
        return jsonify({"error": str(e)}), 500

@location_bp.route('/tram-location-points', methods=['GET'])
def get_tram_location_points():
    """Returns documents from 'trams-victoria'."""
    try:
        docs = list(tram_locations.find({}, {"_id": 0}))
        logger.info(f"Retrieved {len(docs)} tram documents.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching tram locations: {e}")
        return jsonify({"error": str(e)}), 500

@location_bp.route('/medical-location-points', methods=['GET'])
def get_medical_location_points():
    """Returns documents from 'medical-victoria'."""
    try:
        docs = list(medical_locations.find({}, {"_id": 0}))
        logger.info(f"Retrieved {len(docs)} medical documents.")
        return jsonify(docs)
    except Exception as e:
        logger.error(f"Error fetching tram locations: {e}")
        return jsonify({"error": str(e)}), 500
