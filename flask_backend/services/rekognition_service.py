import boto3
import os

def moderate_image_s3(bucket_name, image_key, min_confidence=80):
    """
    Checks an image in S3 for inappropriate content using AWS Rekognition.
    Returns (is_clean, labels):
      - is_clean: True if no inappropriate content, False otherwise
      - labels: List of moderation labels (if any)
    """
    rekognition = boto3.client(
        'rekognition',
        aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY'),
        region_name=os.environ.get('S3_REGION')
    )
    response = rekognition.detect_moderation_labels(
        Image={
            'S3Object': {
                'Bucket': bucket_name,
                'Name': image_key
            }
        },
        MinConfidence=min_confidence
    )
    labels = response.get('ModerationLabels', [])
    is_clean = len(labels) == 0
    return is_clean 