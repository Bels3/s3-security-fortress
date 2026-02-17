import json
import boto3
import os
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')

BUCKET_NAME = os.environ['BUCKET_NAME']
EXPIRATION_TIME = int(os.environ.get('EXPIRATION_TIME', 300))
KMS_KEY_ID = os.environ.get('KMS_KEY_ID', '')

def lambda_handler(event, context):
    """
    Generate presigned URL for downloading from S3
    
    Expected input:
    {
        "object_key": "uploads/2024/02/13/document.pdf",
        "response_content_disposition": "attachment; filename=document.pdf"  # Optional
    }
    """
    
    try:
        # Parse request body
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        object_key = body.get('object_key')
        response_content_disposition = body.get('response_content_disposition')
        
        # Validation
        if not object_key:
            return error_response(400, 'object_key is required')
        
        # Check if object exists
        try:
            s3_client.head_object(Bucket=BUCKET_NAME, Key=object_key)
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return error_response(404, 'Object not found')
            raise
        
        # Generate presigned URL parameters
        params = {
            'Bucket': BUCKET_NAME,
            'Key': object_key
        }
        
        # Add custom response headers if specified
        if response_content_disposition:
            params['ResponseContentDisposition'] = response_content_disposition
        
        # Generate presigned URL
        download_url = s3_client.generate_presigned_url(
            'get_object',
            Params=params,
            ExpiresIn=EXPIRATION_TIME
        )
        
        return success_response({
            'download_url': download_url,
            'object_key': object_key,
            'expires_in': EXPIRATION_TIME
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
