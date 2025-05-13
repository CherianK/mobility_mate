from flask import Blueprint, request, jsonify
import requests
import os
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
TICKETMASTER_API_KEY = os.getenv("TICKETMASTER_API_KEY")

events_bp = Blueprint('events', __name__)
BASE_URL = "https://app.ticketmaster.com/discovery/v2/events.json"

@events_bp.route('/events', methods=['POST'])
def get_events():
    try:
        # Get current date in YYYY-MM-DD format
        current_date = datetime.now().strftime('%Y-%m-%d')

        # Build query parameters with hardcoded values
        params = {
            'apikey': TICKETMASTER_API_KEY,
            'postalcode': '3000',  # Melbourne CBD
            'radius': 100,  # 100km radius
            'unit': 'km',
            'countryCode': 'AU',
            'stateCode': 'VIC',
            'startDateTime': f"{current_date}T00:00:00Z",  # Use current date
            'size': 100  # Maximum allowed by Ticketmaster API
        }

        # Make request to Ticketmaster API
        response = requests.get(BASE_URL, params=params)
        response.raise_for_status()
        
        # Return the raw JSON response
        return response.json()

    except requests.exceptions.RequestException as e:
        return jsonify({"error": f"Error fetching events: {str(e)}"}), 500
    except Exception as e:
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500 