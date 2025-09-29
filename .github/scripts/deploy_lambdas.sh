#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=".github/config/lambdas.json"
MODE="${1:-force}"
shift || true

# Load Lambda names
LAMBDAS=($(jq -r '.lambdas | keys[]' "$CONFIG_FILE"))

# Determine targets
case "$MODE" in
force)
    TARGETS=("${LAMBDAS[@]}")
    ;;
  select)
    if [[ $# -eq 0 ]]; then
      echo "ERROR: In select mode, provide function names!" >&2
      exit 1
    fi
    TARGETS=("$@")
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac


# Deploy lambda loop
for lambda in "${TARGETS[@]}"; do
  echo "Processing $lambda (mode=$MODE)..."

  TMP_DIR=$(mktemp -d)
  cp -r "$lambda"/* "$TMP_DIR"

  if [[ -n "${REQ_FILE:-}" ]]; then
    DEP_FILE="$REQ_FILE"
  elif [[ -f "$lambda/uv.lock" ]]; then
    DEP_FILE="uv.lock"
  elif [[ -f "$lambda/requirements.txt" ]]; then
    DEP_FILE="requirements.txt"
  else
    DEP_FILE=""
  fi

  RUNTIME=$(jq -r ".lambdas[\"$lambda\"].runtime" "$CONFIG_FILE")
  if [[ -n "$DEP_FILE" && -f "$TMP_DIR/$DEP_FILE" ]]; then
    echo "[INFO] Installing dependencies from $DEP_FILE using docker ($RUNTIME)..."
    docker run --rm -v "$TMP_DIR":/var/task -w /var/task python:$RUNTIME \
      bash -c "pip install -r $DEP_FILE -t ."
    sudo chown -R $(id -u):$(id -g) "$TMP_DIR"
  else
    echo "[WARN] No dependency file found for $lambda, skipping dependency install."
  fi

  echo "[INFO] Packaging code for $lambda..."
  cd "$TMP_DIR" && zip -r "$GITHUB_WORKSPACE/$lambda.zip" . && cd -
  rm -rf "$TMP_DIR"

  echo "[INFO] Updating environment variables for $lambda..."
  ENV_JSON=$(jq -r ".lambdas[\"$lambda\"].env" "$CONFIG_FILE" | envsubst)
  jq -n --argjson vars "$ENV_JSON" '{"Variables": $vars}' > env.json
  aws lambda update-function-configuration --function-name "$lambda" --environment file://env.json
  rm env.json
  aws lambda wait function-updated --function-name "$lambda"

  echo "[INFO] Updating function code for $lambda..."
  aws lambda update-function-code --function-name "$lambda" --zip-file fileb://"$lambda.zip" --publish
  aws lambda wait function-updated --function-name "$lambda"

  VERSION=$(aws lambda publish-version --function-name "$lambda" --query Version --output text)

  echo "[INFO] Updating alias $ENV → version $VERSION for $lambda..."
  aws lambda update-alias --function-name "$lambda" --name "$ENV" --function-version "$VERSION"

  echo "=== Finished deploying $lambda ==="
done
