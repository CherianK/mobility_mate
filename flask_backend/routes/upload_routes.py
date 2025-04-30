# flask_backend/routes/upload_routes.py

from flask import Blueprint, request, jsonify
import boto3
import os
from datetime import datetime
from services.db_service import get_collection  

upload_bp = Blueprint('upload', __name__)

# Map of accessibility types to collection names
COLLECTION_MAP = {
    'healthcare': 'medical-victoria',
    'toilets': 'toilets-victoria',
    'trains': 'trains-victoria',
    'trams': 'trams-victoria'
}

@upload_bp.route('/generate-upload-url', methods=['POST'])
def generate_upload_url():
    try:
        # 1. Parse request
        data = request.get_json()
        filename = data.get('filename')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        accessibility_type = data.get('accessibility_type')
        content_type = data.get('content_type', 'image/jpeg')

        if not all([filename, latitude, longitude, accessibility_type]):
            return jsonify({'error': 'Filename, latitude, longitude, and accessibility_type are required'}), 400

        # 2. Get the appropriate collection
        collection_name = COLLECTION_MAP.get(accessibility_type.lower())
        if not collection_name:
            return jsonify({'error': f'Invalid accessibility type: {accessibility_type}'}), 400

        collection = get_collection(collection_name)

        # 3. Verify the location exists
        location = collection.find_one({
            'Location_Lat': float(latitude),
            'Location_Lon': float(longitude),
            'Accessibility_Type_Name': accessibility_type
        })

        if not location:
            return jsonify({'error': 'No matching location found with the specified coordinates and accessibility type'}), 404

        # 4. Setup S3 client
        s3_client = boto3.client(
            's3',
            aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY'),
            region_name=os.environ.get('S3_REGION')
        )
        bucket_name = os.environ.get('S3_BUCKET_NAME')

        # 5. Generate S3 key
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        key = f"uploads/{timestamp}_{filename}"

        # 6. Create a pre-signed PUT URL
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': key,
                'ContentType': content_type,
            },
            ExpiresIn=3600  # 1 hour expiry
        )

        # 7. Generate public URL
        public_url = f"https://{bucket_name}.s3.{os.environ.get('S3_REGION')}.amazonaws.com/{key}"

        # 8. Update the document using _id for efficiency
        result = collection.update_one(
            {'_id': location['_id']},  # 🔥 Only using _id now
            {'$push': {'Images': public_url}}
        )

        if result.modified_count == 0:
            return jsonify({'error': 'Failed to update location with new image'}), 500

        # 9. Respond to frontend
        return jsonify({
            "upload_url": presigned_url,
            "public_url": public_url
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500