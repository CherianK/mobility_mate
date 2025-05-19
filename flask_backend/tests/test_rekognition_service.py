import unittest
from unittest.mock import patch, MagicMock
import os
import sys

# Add the parent directory to sys.path to import rekognition_service
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from services import rekognition_service

class TestModerateImageS3(unittest.TestCase):
    @patch('services.rekognition_service.boto3.client')
    def test_image_is_clean(self, mock_boto_client):
        mock_rekognition = MagicMock()
        mock_rekognition.detect_moderation_labels.return_value = {'ModerationLabels': []}
        mock_boto_client.return_value = mock_rekognition
        is_clean = rekognition_service.moderate_image_s3('bucket', 'key')
        self.assertTrue(is_clean)

    @patch('services.rekognition_service.boto3.client')
    def test_image_is_not_clean(self, mock_boto_client):
        mock_rekognition = MagicMock()
        mock_rekognition.detect_moderation_labels.return_value = {
            'ModerationLabels': [{'Name': 'Explicit Nudity', 'Confidence': 99.0}]
        }
        mock_boto_client.return_value = mock_rekognition
        is_clean = rekognition_service.moderate_image_s3('bucket', 'key')
        self.assertFalse(is_clean)

    @patch('services.rekognition_service.boto3.client')
    def test_aws_error(self, mock_boto_client):
        mock_rekognition = MagicMock()
        mock_rekognition.detect_moderation_labels.side_effect = Exception('AWS error')
        mock_boto_client.return_value = mock_rekognition
        # The original function does not handle exceptions, so this will raise
        with self.assertRaises(Exception):
            rekognition_service.moderate_image_s3('bucket', 'key')

    @patch.dict(os.environ, {}, clear=True)
    def test_missing_env_vars(self):
        # The original function does not check for missing env vars, but if you add that, this will test it
        with self.assertRaises(Exception):
            rekognition_service.moderate_image_s3('bucket', 'key')

if __name__ == '__main__':
    unittest.main() 