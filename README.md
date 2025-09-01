# Generic API Gateway Lambda Deployment Template

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Configuration (`lambdas.json`)](#configuration-lambdasjson)
3. [Folder Naming Rules](#folder-naming-rules)
4. [Environment Variables](#environment-variables)
5. [Adding a New Lambda](#adding-a-new-lambda)
6. [Deployment](#deployment)
7. [Development Notes](#development-notes)
8. [API Gateway Updates](#api-gateway-updates)
9. [Example Lambda & Routes Table](#example-lambda--routes-table)

---

## Repository Structure

```
project-root/
├── .github/
│   ├── config/
│   │   └── lambdas.json       # Lambda configuration
│   ├── scripts/
│   │   ├── deploy_lambdas.sh  # Deploy Lambda functions
│   │   └── update_routes.sh   # Update API Gateway routes
├── lambda_function_1/         # Generic Lambda folder
│   ├── app.py
│   └── requirements.txt
├── lambda_function_2/         # Another generic Lambda folder
│   ├── app.py
│   └── requirements.txt
├── README.md
└── workflow.yml               # GitHub Actions workflow
```

---

## Configuration (`lambdas.json`)

All Lambda functions and API Gateway routes are defined in **`.github/config/lambdas.json`**.

* Each lambda key is the function name.
* Each route can define multiple HTTP methods.
* `authorizer` field attaches Cognito authorization if needed.

Generic example:

```json
{
  "lambdas": {
    "lambda_function_1": {
      "runtime": "3.13",
      "env": {"VAR1": "${VAR1}", "VAR2": "${VAR2}"}
    },
    "lambda_function_2": {
      "runtime": "3.13",
      "env": {"VAR3": "${VAR3}"}
    }
  },
  "routes": {
    "/generic_route_1": {
      "methods": {
        "GET": {"type": "lambda", "lambda_name": "lambda_function_1", "authorizer": "auth_${ENV}"},
        "OPTIONS": {"type": "cors", "origin": "${CORS_ORIGIN}"}
      }
    },
    "/generic_route_2": {
      "methods": {
        "POST": {"type": "lambda", "lambda_name": "lambda_function_2"}
      }
    }
  }
}
```

---

## Folder Naming Rules

* Folder **must match the Lambda function name** in `lambdas.json`.
* Each folder contains `app.py` and optional `requirements.txt`.
* Example: `lambda_function_1/`.

---

## Environment Variables

* Set via GitHub Actions secrets or workflow environment.
* Referenced in `lambdas.json` using `${VAR_NAME}`.
* Generic variables: `VAR1`, `VAR2`, `VAR3`, `CORS_ORIGIN`, etc.

---

## Adding a New Lambda

1. Create folder named after the lambda function.
2. Add `app.py` and optionally `requirements.txt`.
3. Update `lambdas.json` with runtime, env, and optional routes.

Example:

```json
"lambda_function_3": { "runtime": "3.13", "env": {"VAR4": "${VAR4}"} }
```

---

## Deployment

* Workflow supports selecting environment (`staging` / `prod`) and lambdas (`all` or comma-separated list).
* Examples:

```bash
# Deploy all
bash .github/scripts/deploy_lambdas.sh all

# Deploy selected
bash .github/scripts/deploy_lambdas.sh select lambda_function_1,lambda_function_2
```

---

## Development Notes

* `deploy_lambdas.sh`:

  * Builds Lambda packages from folders.
  * Installs dependencies using Docker.
  * Updates Lambda configuration and code.
* `update_routes.sh`:

  * Configures API Gateway integrations.
  * Sets CORS headers for OPTIONS.
  * Attaches authorizers if defined.

---

## API Gateway Updates

* CORS headers for OPTIONS:

```
Access-Control-Allow-Headers: Content-Type,Authorization
Access-Control-Allow-Methods: GET,POST,OPTIONS
Access-Control-Allow-Origin: ${CORS_ORIGIN}
```

* Lambda integration type: AWS\_PROXY
* Cognito authorizers attached if specified in `lambdas.json`.

---

## Example Lambda & Routes Table

| Lambda Function     | Route              | HTTP Method | Authorizer    |
| ------------------- | ------------------ | ----------- | ------------- |
| lambda\_function\_1 | /generic\_route\_1 | GET         | auth\_\${ENV} |
| lambda\_function\_1 | /generic\_route\_1 | OPTIONS     | -             |
| lambda\_function\_2 | /generic\_route\_2 | POST        | -             |
| lambda\_function\_3 | /generic\_route\_3 | GET         | auth\_\${ENV} |

---
