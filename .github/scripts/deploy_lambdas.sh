# set -euo pipefail

# # ==============================
# # Usage:
# #   ./deploy.sh force
# #   ./deploy.sh select get_google_sign_in_url get_ebook_metadata
# # ==============================

# MODE="${1:-force}"  # default is force
# shift || true      # shift args so $@ contains function names in select mode

# # Define lambda functions name
# LAMBDAS=("get_google_sign_in_url" "get_ebook_metadata")

# declare -A RUNTIME=(
#   ["get_google_sign_in_url"]="3.13"
#   ["get_ebook_metadata"]="3.13"
# )

# # Lambda environments
# declare -A ENV_VARS
# ENV_VARS["get_google_sign_in_url"]=$(jq -n \
#   --arg allowed "$ALLOWED_ORIGINS" \
#   --arg client "$COGNITO_CLIENT_ID" \
#   --arg domain "$COGNITO_DOMAIN" \
#   --arg redirect "$COGNITO_REDIRECT_URI" \
#   --arg origin "$ORIGIN" \
#   '{Variables: {ALLOWED_ORIGINS: $allowed, COGNITO_CLIENT_ID: $client, COGNITO_DOMAIN: $domain, COGNITO_REDIRECT_URI: $redirect, ORIGIN: $origin}}')

# ENV_VARS["get_ebook_metadata"]=$(jq -n \
#   --arg book "$BOOK_KEY" \
#   --arg bucket "$EBOOK_BUCKET" \
#   --arg origin "$ORIGIN" \
#   --arg userpool "$USER_POOL_ID" \
#   '{Variables: {BOOK_KEY: $book, EBOOK_BUCKET: $bucket, ORIGIN: $origin, USER_POOL_ID: $userpool}}')

# # Functions to process
# TARGETS=()

# if [[ "$MODE" == "force" ]]; then
#   TARGETS=("${LAMBDAS[@]}")

# elif [[ "$MODE" == "select" ]]; then
#   if [[ $# -eq 0 ]]; then
#     echo "ERROR: In select mode, provide function names!"
#     exit 1
#   fi
#   TARGETS=("$@")
# else
#   echo "Unknown mode: $MODE"
#   exit 1
# fi

# # Deploy loop
# for lambda in "${TARGETS[@]}"; do
#   HASH_FILE=".github/.${lambda}.hash"
#   echo "Processing $lambda (mode=$MODE)..."


#   echo "Deploying $lambda..."
#   TMP_DIR=$(mktemp -d)
#   cp -r $lambda/* "$TMP_DIR"

#   if [[ -f "$TMP_DIR/requirements.txt" ]]; then
#     docker run --rm -v "$TMP_DIR":/var/task -w /var/task python:${RUNTIME[$lambda]} \
#       bash -c "pip install -r requirements.txt -t ."
#     sudo chown -R $(id -u):$(id -g) "$TMP_DIR"
#   fi

#   cd "$TMP_DIR" && zip -r "$GITHUB_WORKSPACE/$lambda.zip" . && cd -
#   rm -rf "$TMP_DIR"

#   echo "${ENV_VARS[$lambda]}" > env.json
  
#   aws lambda update-function-configuration --function-name $lambda --environment file://env.json
#   rm env.json
#   aws lambda wait function-updated --function-name $lambda

#   aws lambda update-function-code --function-name $lambda --zip-file fileb://$lambda.zip --publish
#   aws lambda wait function-updated --function-name $lambda

#   VERSION=$(aws lambda publish-version --function-name $lambda --query Version --output text)
#   aws lambda update-alias --function-name $lambda --name $ENV --function-version $VERSION

# done




#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=".github/config/lambdas.json"
MODE="${1:-force}"
shift || true

# Load Lambda names from JSON
LAMBDAS=($(jq -r '.lambdas | keys[]' "$CONFIG_FILE"))

# Select targets based on mode
TARGETS=()
if [[ "$MODE" == "force" ]]; then
  TARGETS=("${LAMBDAS[@]}")
elif [[ "$MODE" == "select" ]]; then
  if [[ $# -eq 0 ]]; then
    echo "ERROR: In select mode, provide function names!"
    exit 1
  fi
  TARGETS=("$@")
else
  echo "Unknown mode: $MODE"
  exit 1
fi

# Deploy Lambdas
for lambda in "${TARGETS[@]}"; do
  HASH_FILE=".github/.${lambda}.hash"
  echo "Processing $lambda (mode=$MODE)..."

  TMP_DIR=$(mktemp -d)
  cp -r "$lambda"/* "$TMP_DIR"

  # Install requirements
  RUNTIME=$(jq -r ".lambdas[\"$lambda\"].runtime" "$CONFIG_FILE")
  if [[ -f "$TMP_DIR/requirements.txt" ]]; then
    docker run --rm -v "$TMP_DIR":/var/task -w /var/task python:$RUNTIME \
      bash -c "pip install -r requirements.txt -t ."
    sudo chown -R $(id -u):$(id -g) "$TMP_DIR"
  fi

  cd "$TMP_DIR" && zip -r "$GITHUB_WORKSPACE/$lambda.zip" . && cd -
  rm -rf "$TMP_DIR"

  # Build env JSON from config
  jq -n "$(jq -r ".lambdas[\"$lambda\"].env" "$CONFIG_FILE")" > env.json
  aws lambda update-function-configuration --function-name "$lambda" --environment file://env.json
  rm env.json
  aws lambda wait function-updated --function-name "$lambda"

  aws lambda update-function-code --function-name "$lambda" --zip-file fileb://"$lambda.zip" --publish
  aws lambda wait function-updated --function-name "$lambda"

  VERSION=$(aws lambda publish-version --function-name "$lambda" --query Version --output text)
  aws lambda update-alias --function-name "$lambda" --name "$ENV" --function-version "$VERSION"
done
