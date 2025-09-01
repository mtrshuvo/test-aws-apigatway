#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=".github/config/lambdas.json"
MODE="${1:-force}"
shift || true

# Load Lambda names
LAMBDAS=($(jq -r '.lambdas | keys[]' "$CONFIG_FILE"))

# Determine targets
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

# Deploy lambda loop
for lambda in "${TARGETS[@]}"; do
  echo "Processing $lambda (mode=$MODE)..."

  TMP_DIR=$(mktemp -d)
  cp -r "$lambda"/* "$TMP_DIR"

  RUNTIME=$(jq -r ".lambdas[\"$lambda\"].runtime" "$CONFIG_FILE")
  if [[ -f "$TMP_DIR/requirements.txt" ]]; then
    docker run --rm -v "$TMP_DIR":/var/task -w /var/task python:$RUNTIME \
      bash -c "pip install -r requirements.txt -t ."
    sudo chown -R $(id -u):$(id -g) "$TMP_DIR"
  fi

  cd "$TMP_DIR" && zip -r "$GITHUB_WORKSPACE/$lambda.zip" . && cd -
  rm -rf "$TMP_DIR"

  # env vars to json structure dynamically
  ENV_JSON=$(jq -r ".lambdas[\"$lambda\"].env" "$CONFIG_FILE" | envsubst)
  jq -n --argjson vars "$ENV_JSON" '{"Variables": $vars}' > env.json

  aws lambda update-function-configuration --function-name "$lambda" --environment file://env.json
  rm env.json
  aws lambda wait function-updated --function-name "$lambda"

  aws lambda update-function-code --function-name "$lambda" --zip-file fileb://"$lambda.zip" --publish
  aws lambda wait function-updated --function-name "$lambda"

  VERSION=$(aws lambda publish-version --function-name "$lambda" --query Version --output text)
  aws lambda update-alias --function-name "$lambda" --name "$ENV" --function-version "$VERSION"
done
