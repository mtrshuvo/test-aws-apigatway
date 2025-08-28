import os
import urllib.parse
from typing import Any, Dict, List, Optional

from lambda_response_utils import error_response, success_response, status

ALLOWED_ORIGIN = os.environ['ORIGIN']

def lambda_handler(event, context):
    base_header = {
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN
        }
    
    try:
        headers = event.get("headers", {})
        print(f"headers:{headers}")

        params = event.get("queryStringParameters") or {}
        flow = params.get("flow", "login")
        login_hint = params.get("login_hint", "")

        cognito_domain = os.environ["COGNITO_DOMAIN"]
        client_id = os.environ["COGNITO_CLIENT_ID"]
        redirect_uri = os.environ["COGNITO_REDIRECT_URI"]

        prompt_map = {
            "login": "consent",
            "register": "consent"
        }
        prompt = prompt_map.get(flow, "consent")

        query_params = {
            "response_type": "token",
            "client_id": client_id,
            "identity_provider": "Google",
            "redirect_uri": redirect_uri,
            "scope": "openid email profile",
            "prompt": prompt,
            "login_hint": login_hint
        }

        encoded_query = urllib.parse.urlencode(query_params)
        url = f"{cognito_domain}/oauth2/authorize?{encoded_query}"

        return success_response(
            data = {
                "redirect_url": url
            },
            status_code = status.HTTP_200_OK,
            headers = base_header,
        )

    except Exception as e:
        return error_response(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            headers=base_header,
            details= str(e)
        )

