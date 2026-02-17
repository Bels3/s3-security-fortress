# Lambda function to generate presigned URLs for uploads
import json
import boto3
import os
from datetime import datetime
from botocore.exceptions import ClientError
from botocore.config import Config

S3_CONFIG = Config(
    signature_version='s3v4',
    region_name='us-east-1'
)
s3_client = boto3.client('s3', config=S3_CONFIG)

BUCKET_NAME = os.environ['BUCKET_NAME']
EXPIRATION_TIME = int(os.environ.get('EXPIRATION_TIME', 300))
MAX_FILE_SIZE = int(os.environ.get('MAX_FILE_SIZE', 10)) * 1024 * 1024  # Convert MB to bytes
ALLOWED_CONTENT_TYPES = json.loads(os.environ.get('ALLOWED_CONTENT_TYPES', '[]'))
KMS_KEY_ID = os.environ.get('KMS_KEY_ID', '')

def lambda_handler(event, context):
    """
    Generate presigned URL for uploading to S3
    
    Expected input:
    {
        "filename": "document.pdf",
        "content_type": "application/pdf",
        "metadata": {"user_id": "123"}  # Optional
    }
    """
    
    try:
        # Parse request body
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        filename = body.get('filename')
        content_type = body.get('content_type', 'application/octet-stream')
        metadata = body.get('metadata', {})
        
        # Validation
        if not filename:
            return error_response(400, 'filename is required')
        
        # Validate content type if restrictions exist
        if ALLOWED_CONTENT_TYPES and content_type not in ALLOWED_CONTENT_TYPES:
            return error_response(400, f'Content type {content_type} not allowed')
        
        # Generate unique key with timestamp
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H%M%S')
        object_key = f"uploads/{timestamp}/{filename}"
        
        # Prepare presigned POST parameters
        fields = {
            'Content-Type': content_type,
            'x-amz-meta-uploaded-at': datetime.utcnow().isoformat()
        }
        
        # Add custom metadata
        for key, value in metadata.items():
            fields[f'x-amz-meta-{key}'] = str(value)
        
        # Conditions for the upload
        conditions = [
            {'Content-Type': content_type},
            ['content-length-range', 1, MAX_FILE_SIZE],
            {'x-amz-meta-uploaded-at': fields['x-amz-meta-uploaded-at']}
        ]
            
            # Add KMS encryption if configured
        if KMS_KEY_ID:
            fields['x-amz-server-side-encryption'] = 'aws:kms'
            fields['x-amz-server-side-encryption-aws-kms-key-id'] = KMS_KEY_ID
            
            # Remove any existing encryption conditions to avoid duplicates
            conditions = [c for c in conditions if 'x-amz-server-side-encryption' not in str(c)]
            
            # Add them exactly once
            conditions.append({'x-amz-server-side-encryption': 'aws:kms'})
            conditions.append({'x-amz-server-side-encryption-aws-kms-key-id': KMS_KEY_ID})
        
        # Generate presigned POST
        response = s3_client.generate_presigned_post(
            Bucket=BUCKET_NAME,
            Key=object_key,
            Fields=fields,
            Conditions=conditions,
            ExpiresIn=EXPIRATION_TIME
        )
        
        return success_response({
            'upload_url': response['url'],
            'fields': response['fields'],
            'object_key': object_key,
            'expires_in': EXPIRATION_TIME,
            'max_file_size_mb': MAX_FILE_SIZE / (1024 * 1024)
        })
        
    except ClientError as e:
        print(f"Error generating presigned URL: {e}")
        return error_response(500, f'Error generating presigned URL: {str(e)}')
    except Exception as e:
        print(f"Unexpected error: {e}")
        return error_response(500, f'Unexpected error: {str(e)}')

def success_response(data):
    """Return successful API Gateway response"""
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST'
        },
        'body': json.dumps(data)
    }

def error_response(status_code, message):
    """Return error API Gateway response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'error': message
        })
    }
