#!/usr/bin/env bash
set -euo pipefail

declare -A ROUTES_METHODS=(
  ["/ebooks"]="GET:lambda:get_ebook_metadata OPTIONS:cors"
  ["/signin_url"]="GET:lambda:get_google_sign_in_url"
)

declare -A ROUTES_AUTHORIZE=(
  ["/ebooks"]="GET:teen_${ENV}_authorizer"
)

declare -A ROUTES_ORIGIN=(
  ["/ebooks"]=$OPTIONS_CORS_DOMAIN
  ["/signin_url"]=$OPTIONS_CORS_DOMAIN
)

for route in "${!ROUTES_METHODS[@]}"; do
  RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $REST_API_ID --query "items[?path=='$route'].id" --output text)
  METHODS=(${ROUTES_METHODS[$route]})

  for entry in "${METHODS[@]}"; do
    IFS=':' read -r HTTP_METHOD TYPE TARGET <<< "$entry"

    case "$TYPE" in
      lambda)
        LAMBDA_ARN="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:300080618312:function:$TARGET:$ENV/invocations"
        aws apigateway put-integration \
          --rest-api-id $REST_API_ID \
          --resource-id $RESOURCE_ID \
          --http-method $HTTP_METHOD \
          --type AWS_PROXY \
          --integration-http-method POST \
          --uri $LAMBDA_ARN
        ;;
      cors)
        ORIGIN="${ROUTES_ORIGIN[$route]}"
        aws apigateway put-integration-response \
          --rest-api-id $REST_API_ID \
          --resource-id $RESOURCE_ID \
          --http-method OPTIONS \
          --status-code 200 \
          --response-parameters "{\"method.response.header.Access-Control-Allow-Origin\":\"'$ORIGIN'\"}"
        ;;
    esac
  done
done

aws apigateway create-deployment --rest-api-id $REST_API_ID --stage-name $ENV --description "Updated all routes for $ENV"
