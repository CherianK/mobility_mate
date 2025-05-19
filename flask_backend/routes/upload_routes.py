from flask import Blueprint, request, jsonify
import boto3
import os
from datetime import datetime
from services.db_service import get_collection
from services.rekognition_service import moderate_image_s3

upload_bp = Blueprint('upload', __name__)

# Map of accessibility types to collection names
COLLECTION_MAP = {
    'healthcare': 'medical-victoria',
    'toilet': 'toilets-victoria',
    'toilets': 'toilets-victoria',
    'train': 'trains-victoria',
    'trains': 'trains-victoria',
    'tram': 'trams-victoria',
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
        device_id = data.get('device_id')
        username = data.get('username')

        if not all([filename, latitude, longitude, accessibility_type]):
            return jsonify({'error': 'Filename, latitude, longitude, and accessibility_type are required'}), 400

        # 2. Get collection
        collection_name = COLLECTION_MAP.get(accessibility_type.lower())
        if not collection_name:
            return jsonify({'error': f'Invalid accessibility type: {accessibility_type}'}), 400
        collection = get_collection(collection_name)

        # 3. Validate location
        possible_types = [accessibility_type]
        if accessibility_type.endswith('s'):
            possible_types.append(accessibility_type[:-1])
        else:
            possible_types.append(accessibility_type + 's')

        location = collection.find_one({
            'Location_Lat': float(latitude),
            'Location_Lon': float(longitude),
            'Accessibility_Type_Name': {'$in': possible_types}
        })

        if not location:
            return jsonify({'error': 'No matching location found'}), 404

        # 4. Setup S3
        aws_key = os.environ.get('AWS_ACCESS_KEY_ID')
        aws_secret = os.environ.get('AWS_SECRET_ACCESS_KEY')
        region = os.environ.get('S3_REGION')
        if not all([aws_key, aws_secret, region]):
            raise EnvironmentError("Missing AWS credentials or region in environment variables.")
        s3_client = boto3.client(
            's3',
            aws_access_key_id=aws_key,
            aws_secret_access_key=aws_secret,
            region_name=region
        )
        bucket_name = os.environ.get('S3_BUCKET_NAME')

        # 5. Generate key + presigned URL
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        key = f"uploads/{timestamp}_{filename}"
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': key,
                'ContentType': content_type,
            },
            ExpiresIn=3600
        )
        public_url = f"https://{bucket_name}.s3.{region}.amazonaws.com/{key}"

        # 6.1 Moderate image using Rekognition
        s3_key = key  # Already constructed above
        try:
            is_clean = moderate_image_s3(bucket_name, s3_key)
        except Exception as e:
            # log to console so you still see it in your Flask logs
+           app.logger.error(f"Rekognition failed: {e}", exc_info=True)
+           # return the actual AWS error back to the client for debugging
+           return jsonify({'error': str(e)}), 500

        if not is_clean:
            # Delete the image from S3
            s3_client.delete_object(Bucket=bucket_name, Key=s3_key)
            return jsonify({
                'error': 'Image failed moderation and was deleted.'
            }), 400

        # 6.2 Add image object to Images array (only if clean)
        image_data = {
            "image_url": public_url,
            "image_upload_time": datetime.utcnow().isoformat() + "Z",
            "approved_status": False,  # Always False, pending admin approval
            "image_approved_time": None,
            "device_id": device_id,
            "username": username,
        }

        result = collection.update_one(
            {'_id': location['_id']},
            {'$push': {'Images': image_data}}
        )

        if result.modified_count == 0:
            return jsonify({'error': 'Failed to update location with new image'}), 500

        # 7. Return upload + public URL to frontend
        return jsonify({
            "upload_url": presigned_url,
            "public_url": public_url
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
