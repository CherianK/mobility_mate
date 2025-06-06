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
        
        # Get username from request if available
        username = data.get('username')

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
            'username': username,  # Include username in vote record
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
    

@vote_bp.route('/api/votes/devices/summary', methods=['GET'])
def get_device_vote_summary():
    try:
        votes_collection = get_collection('votes')

        # Aggregate vote count per device_id, sorted by count ascending
        pipeline = [
            {
                '$group': {
                    '_id': '$device_id',
                    'vote_count': {'$sum': 1}
                }
            },
            {
                '$sort': {'vote_count': 1}
            }
        ]

        result = list(votes_collection.aggregate(pipeline))

        # Rename keys for clarity
        summary = [
            {
                'device_id': entry['_id'],
                'vote_count': entry['vote_count']
            }
            for entry in result
        ]

        return jsonify(summary), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@vote_bp.route('/api/leaderboard', methods=['GET'])
def get_leaderboard():
    try:
        # Get collections
        votes_collection = get_collection('votes')
        medical_collection = get_collection('medical-victoria')
        toilet_collection = get_collection('toilets-victoria')
        train_collection = get_collection('trains-victoria')
        tram_collection = get_collection('trams-victoria')
        
        # Get vote counts per username
        vote_pipeline = [
            {
                '$match': {
                    'username': {'$ne': None, '$exists': True}
                }
            },
            {
                '$group': {
                    '_id': '$username',
                    'vote_count': {'$sum': 1}
                }
            }
        ]
        
        vote_results = list(votes_collection.aggregate(vote_pipeline))
        
        # Create a dictionary to store username -> points
        user_points = {}
        
        # Process vote results (1 point per vote)
        for result in vote_results:
            username = result['_id']
            vote_count = result['vote_count']
            if username not in user_points:
                user_points[username] = 0
            user_points[username] += vote_count
        
        # Function to count uploads for a collection
        def count_uploads_for_collection(collection):
            upload_counts = {}
            # Find all documents with Images array
            cursor = collection.find({"Images": {"$exists": True, "$ne": []}})
            for doc in cursor:
                if 'Images' in doc:
                    for image in doc['Images']:
                        # Only count approved images for leaderboard points
                        if (image.get('approved_status') == True and 
                            'username' in image and image['username']):
                            username = image['username']
                            if username not in upload_counts:
                                upload_counts[username] = 0
                            upload_counts[username] += 1
            return upload_counts
        
        # Count uploads for each collection (5 points per upload)
        # Also aggregate upload counts per user for badge system
        user_upload_counts = {}
        for collection in [medical_collection, toilet_collection, train_collection, tram_collection]:
            upload_counts = count_uploads_for_collection(collection)
            for username, count in upload_counts.items():
                if username not in user_points:
                    user_points[username] = 0
                # 5 points per upload
                user_points[username] += count * 5
                # Aggregate upload counts for badge system
                if username not in user_upload_counts:
                    user_upload_counts[username] = 0
                user_upload_counts[username] += count
        
        # Convert to list and sort by points
        leaderboard = [
            {
                'username': username,
                'points': points,
                'approved_uploads': user_upload_counts.get(username, 0)  # Add approved upload count for badge system
            }
            for username, points in user_points.items()
        ]
        
        # Sort by points (descending)
        leaderboard.sort(key=lambda x: x['points'], reverse=True)
        
        # Add rank
        for i, entry in enumerate(leaderboard):
            entry['rank'] = i + 1
        
        return jsonify(leaderboard), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    

@vote_bp.route('/api/uploads/device/<device_id>', methods=['GET'])
def get_device_uploads(device_id):
    try:
        # Get collections
        medical_collection = get_collection('medical-victoria')
        toilet_collection = get_collection('toilets-victoria')
        train_collection = get_collection('trains-victoria')
        tram_collection = get_collection('trams-victoria')
        
        # Function to count uploads for a collection by device_id
        def count_uploads_for_collection(collection, device_id):
            upload_count = 0
            # Find all documents with Images array
            cursor = collection.find({"Images": {"$exists": True, "$ne": []}})
            for doc in cursor:
                if 'Images' in doc:
                    for image in doc['Images']:
                        # Count only approved images uploaded by this device
                        if (image.get('device_id') == device_id and 
                            image.get('approved_status') == True):
                            upload_count += 1
            return upload_count
        
        # Count total uploads across all collections
        total_uploads = (
            count_uploads_for_collection(medical_collection, device_id) +
            count_uploads_for_collection(toilet_collection, device_id) +
            count_uploads_for_collection(train_collection, device_id) +
            count_uploads_for_collection(tram_collection, device_id)
        )
        
        return jsonify({
            'device_id': device_id,
            'total_uploads': total_uploads
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@vote_bp.route('/api/uploads/device/<device_id>/images', methods=['GET'])
def get_device_uploaded_images(device_id):
    try:
        # Get collections
        medical_collection = get_collection('medical-victoria')
        toilet_collection = get_collection('toilets-victoria')
        train_collection = get_collection('trains-victoria')
        tram_collection = get_collection('trams-victoria')
        
        all_images = []
        
        def get_images_from_collection(collection, collection_type):
            images = []
            cursor = collection.find({"Images": {"$exists": True, "$ne": []}})
            for doc in cursor:
                if 'Images' in doc:
                    for image in doc['Images']:
                        if image.get('device_id') == device_id:
                            # Get location name from either Metadata or Tags
                            location_name = None
                            if 'Metadata' in doc and 'name' in doc['Metadata']:
                                location_name = doc['Metadata']['name']
                            elif 'Tags' in doc and 'name' in doc['Tags']:
                                location_name = doc['Tags']['name']
                            
                            image_data = {
                                'image_url': image.get('image_url'),
                                'location_name': location_name or 'Unknown Location',
                                'accessibility_type': doc.get('Accessibility_Type_Name', 'Not specified'),
                                'uploaded_at': image.get('image_upload_time'),
                                'approved_status': image.get('approved_status', False),
                                'approved_at': image.get('image_approved_time') if image.get('approved_status') else None
                            }
                            images.append(image_data)
            return images
        
        # Get images from all collections
        all_images.extend(get_images_from_collection(medical_collection, 'hospital'))
        all_images.extend(get_images_from_collection(toilet_collection, 'toilet'))
        all_images.extend(get_images_from_collection(train_collection, 'train'))
        all_images.extend(get_images_from_collection(tram_collection, 'tram'))
        
        # Sort images by upload time (most recent first)
        all_images.sort(key=lambda x: x['uploaded_at'] if x['uploaded_at'] else '', reverse=True)
        
        return jsonify({'images': all_images}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    

    