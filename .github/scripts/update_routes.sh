# #!/usr/bin/env bash
# set -euo pipefail

# CONFIG_FILE=".github/config/lambdas.json"

# for route in $(jq -r '.routes | keys[]' "$CONFIG_FILE"); do
#   RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $REST_API_ID --query "items[?path=='$route'].id" --output text)
#   METHODS=$(jq -r ".routes[\"$route\"].methods | keys[]" "$CONFIG_FILE")

#   for method in $METHODS; do
#     TYPE=$(jq -r ".routes[\"$route\"].methods[\"$method\"].type" "$CONFIG_FILE")
#     case "$TYPE" in
#       lambda)
#         LAMBDA_NAME=$(jq -r ".routes[\"$route\"].methods[\"$method\"].lambda_name" "$CONFIG_FILE")
#         LAMBDA_ARN="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:300080618312:function:$LAMBDA_NAME:$ENV/invocations"
        
#         SAFE_ROUTE=$(echo "$route" | sed 's|/|-|g' | sed 's|^-||')  # replace / with - and remove leading -
#         STATEMENT_ID="apigateway-$ENV-$SAFE_ROUTE-$method"

#         aws lambda add-permission \
#           --function-name "$LAMBDA_NAME:$ENV" \
#           --statement-id "$STATEMENT_ID" \
#           --action lambda:InvokeFunction \
#           --principal apigateway.amazonaws.com \
#           --source-arn "arn:aws:execute-api:$REGION:300080618312:$REST_API_ID/*/$method$route" || true


        
#         aws apigateway put-integration \
#           --rest-api-id $REST_API_ID \
#           --resource-id $RESOURCE_ID \
#           --http-method $method \
#           --type AWS_PROXY \
#           --integration-http-method POST \
#           --uri $LAMBDA_ARN
#         ;;
#       cors)
#         ORIGIN=$(jq -r ".routes[\"$route\"].methods[\"$method\"].origin" "$CONFIG_FILE")
#         aws apigateway put-integration-response \
#           --rest-api-id $REST_API_ID \
#           --resource-id $RESOURCE_ID \
#           --http-method OPTIONS \
#           --status-code 200 \
#           --response-parameters "{
#             \"method.response.header.Access-Control-Allow-Headers\":\"'Content-Type,Authorization'\",
#             \"method.response.header.Access-Control-Allow-Methods\":\"'GET,OPTIONS'\",
#             \"method.response.header.Access-Control-Allow-Origin\":\"'$ORIGIN'\"
#           }"
#         ;;
#     esac
#   done
# done

# aws apigateway create-deployment --rest-api-id $REST_API_ID --stage-name $ENV --description "Updated all routes for $ENV"












#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=".github/config/lambdas.json"

# Loop through all routes defined in JSON
for route in $(jq -r '.routes | keys[]' "$CONFIG_FILE"); do
  RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $REST_API_ID \
    --query "items[?path=='$route'].id" \
    --output text)

  METHODS=$(jq -r ".routes[\"$route\"].methods | keys[]" "$CONFIG_FILE")

  for method in $METHODS; do
    TYPE=$(jq -r ".routes[\"$route\"].methods[\"$method\"].type" "$CONFIG_FILE")
    AUTHORIZE_NAME=$(jq -r ".routes[\"$route\"].methods[\"$method\"].authorizer // empty" "$CONFIG_FILE")

    echo "Configuring $method $route (type=$TYPE, authorizer=$AUTHORIZE_NAME)..."
    
    case "$TYPE" in
      lambda)
        LAMBDA_NAME=$(jq -r ".routes[\"$route\"].methods[\"$method\"].lambda_name" "$CONFIG_FILE")
        LAMBDA_ARN="arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:300080618312:function:$LAMBDA_NAME:$ENV/invocations"

        aws apigateway put-integration \
          --rest-api-id $REST_API_ID \
          --resource-id $RESOURCE_ID \
          --http-method $method \
          --type AWS_PROXY \
          --integration-http-method POST \
          --uri $LAMBDA_ARN

        # If authorizer is defined, attach Cognito authorizer
        if [[ -n "$AUTHORIZE_NAME" && "$method" != "OPTIONS" ]]; then
          AUTHORIZE_NAME=${AUTHORIZE_NAME//\$\{ENV\}/$ENV}

          AUTHORIZE_ID=$(aws apigateway get-authorizers \
            --rest-api-id $REST_API_ID \
            --query "items[?name=='$AUTHORIZE_NAME'].id" \
            --output text)
          
          aws apigateway update-method \
            --rest-api-id $REST_API_ID \
            --resource-id $RESOURCE_ID \
            --http-method $method \
            --patch-operations \
              op=replace,path=/authorizationType,value=COGNITO_USER_POOLS \
              op=replace,path=/authorizerId,value=$AUTHORIZE_ID
        fi
        ;;
      cors)
        ORIGIN=$(jq -r ".routes[\"$route\"].methods[\"$method\"].origin" "$CONFIG_FILE")
        aws apigateway put-integration-response \
          --rest-api-id $REST_API_ID \
          --resource-id $RESOURCE_ID \
          --http-method OPTIONS \
          --status-code 200 \
          --response-parameters "{
            \"method.response.header.Access-Control-Allow-Headers\":\"'Content-Type,Authorization'\",
            \"method.response.header.Access-Control-Allow-Methods\":\"'GET,OPTIONS'\",
            \"method.response.header.Access-Control-Allow-Origin\":\"'$ORIGIN'\"
          }"
        ;;
      *)
        echo "Unknown integration type: $TYPE for $route $method"
        ;;
    esac
  done
done

# Deploy API Gateway stage
aws apigateway create-deployment \
  --rest-api-id $REST_API_ID \
  --stage-name $ENV \
  --description "Updated all routes for $ENV"
