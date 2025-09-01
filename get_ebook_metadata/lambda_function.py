import boto3
import os
import json

from lambda_response_utils import error_response, status, success_response

s3 = boto3.client("s3")
cognito_client = boto3.client('cognito-idp')

BUCKET = os.environ["EBOOK_BUCKET"] 
ALLOWED_ORIGIN = os.environ['ORIGIN']
BOOK_KEY = os.environ['BOOK_KEY']


def get_cognito_info(user_name):
    return cognito_client.admin_get_user(
    UserPoolId=USER_POOL_ID,
    Username=user_name
    )

def get_user_transaction_id(user_info):
    transaction_id = None
    for attr in user_info["UserAttributes"]:
        if attr["Name"] == "custom:transaction_id":
            transaction_id = attr["Value"]
    return transaction_id

def lambda_handler(event, context):
    base_header = {
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN
        }
    # ebook_id = event["pathParameters"]["ebook_id"]
    key = BOOK_KEY

    try:
        obj = s3.get_object(Bucket=BUCKET, Key=key)

        cognito_username = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('cognito:username', '')

        if not cognito_username:
            return error_response(
                status_code=status.HTTP_400_BAD_REQUEST,
                headers=base_header,
                details= "User name not found"
            )
        # user_info = get_cognito_info(cognito_username) [future implementation]
        data = obj["Body"].read()
        metadata = json.loads(data)
        return success_response(
            data = {
                "metadata": metadata
            },
            status_code = status.HTTP_200_OK,
            headers = base_header,
        )

    except s3.exceptions.NoSuchKey:
        return error_response(
            status_code=status.HTTP_404_NOT_FOUND,
            headers=base_header,
            details= "Metadata not found"
        )
    except Exception as e:
        return error_response(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            headers=base_header,
            details= str(e)
        )
