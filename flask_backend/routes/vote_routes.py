from flask import Blueprint, request, jsonify
from datetime import datetime
from services.db_service import get_collection
from bson import ObjectId

vote_bp = Blueprint('vote', __name__)

@vote_bp.route('/api/vote', methods=['POST'])
def submit_vote():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['device_id', 'location_id', 'image_url', 'is_accurate']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400

        # Get votes collection
        votes_collection = get_collection('votes')

        # Check if this device has already voted on this image
        existing_vote = votes_collection.find_one({
            'device_id': data['device_id'],
            'image_url': data['image_url']
        })

        if existing_vote:
            # Return error if device has already voted
            return jsonify({
                'error': 'You have already voted on this image',
                'accurate_count': votes_collection.count_documents({
                    'image_url': data['image_url'],
                    'is_accurate': True
                }),
                'inaccurate_count': votes_collection.count_documents({
                    'image_url': data['image_url'],
                    'is_accurate': False
                }),
                'device_vote_count': votes_collection.count_documents({
                    'device_id': data['device_id']
                })
            }), 400

        # Create new vote
        current_time = datetime.utcnow()
        vote_doc = {
            'device_id': data['device_id'],
            'location_id': data['location_id'],
            'image_url': data['image_url'],
            'is_accurate': data['is_accurate'],
            'created_at': current_time,
            'updated_at': current_time
        }
        votes_collection.insert_one(vote_doc)

        # Get vote counts for this image
        accurate_count = votes_collection.count_documents({
            'image_url': data['image_url'],
            'is_accurate': True
        })
        inaccurate_count = votes_collection.count_documents({
            'image_url': data['image_url'],
            'is_accurate': False
        })

        # Get total votes by this device
        device_vote_count = votes_collection.count_documents({
            'device_id': data['device_id']
        })

        return jsonify({
            'message': 'Vote recorded successfully',
            'accurate_count': accurate_count,
            'inaccurate_count': inaccurate_count,
            'device_vote_count': device_vote_count
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@vote_bp.route('/api/votes/<path:image_url>', methods=['GET'])
def get_votes(image_url):
    try:
        # Get votes collection
        votes_collection = get_collection('votes')

        # Get vote counts for this image
        accurate_count = votes_collection.count_documents({
            'image_url': image_url,
            'is_accurate': True
        })
        inaccurate_count = votes_collection.count_documents({
            'image_url': image_url,
            'is_accurate': False
        })

        return jsonify({
            'accurate_count': accurate_count,
            'inaccurate_count': inaccurate_count
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@vote_bp.route('/api/votes/device/<device_id>', methods=['GET'])
def get_device_votes(device_id):
    try:
        # Get votes collection
        votes_collection = get_collection('votes')

        # Get all votes for this device
        votes = list(votes_collection.find(
            {'device_id': device_id},
            {'_id': 0, 'image_url': 1, 'is_accurate': 1, 'created_at': 1}
        ))

        return jsonify(votes), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500 