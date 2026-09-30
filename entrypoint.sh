#!/bin/bash
set -e

HERMES_CONFIG_FILE="/opt/data/config.yaml"
AGENTHR_SKILL_SOURCE_DIR="/incommingconfig/skills/agenthr"
AGENTHR_SKILL_DIR="/opt/data/skills/agenthr"


echo "Logging into Vault"
###SECRET_VALUE=$(/usr/local/bin/qvault kv get -mount=kv -field="homenet/agents/openclaw/accessedbyopenclaw" "gatewaytoken"  2>&1)
##echo "AAA${SECRET_VALUE}"

if [ ! -f /incommingconfig/config.yaml ]; then
  echo "ERROR container could not find /incommingconfig/config.yaml"
  exit 1
fi

VAULT_ENV_FILE="/incommingconfig/vaultenvlookups.env"

if [ ! -f "$VAULT_ENV_FILE" ]; then
    echo "No Vault environment file found: $VAULT_ENV_FILE"
    exit 1
fi

if [ ! -f /incommingconfig/SOUL.md ]; then
  echo "ERROR container could not find /incommingconfig/SOUL.md"
  exit 1
fi
cp /incommingconfig/SOUL.md /opt/data/SOUL.md


# echo "Fetching OpenAI key"
#
# export OPENAI_API_KEY=$(vault kv get \
#     -field=value \
#     secret/hermes/openai_api_key)

GATEWAY_PASSWORD_LOCATION=homenet/agents/openclaw/accessedbyopenclaw:gatewaytoken
cp /incommingconfig/config.yaml ${HERMES_CONFIG_FILE}

echo "Fetching gateway password from ${GATEWAY_PASSWORD_LOCATION}"
RESULTS=$(printf '{"ids":["%s"]}' "$GATEWAY_PASSWORD_LOCATION" | qvaultfromopenclaw)
RES=$?
if [ $RES -ne 0 ]; then
    exit $RES
fi
GATEWAY_PASSWORD=$(echo "$RESULTS" | jq -r --arg key "$GATEWAY_PASSWORD_LOCATION" '.values[$key]')
HASHED_PASSWORD=$(python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('${GATEWAY_PASSWORD}'))")
sed -i "s|REPLACE_WITH_REAL_GATEWAY_PASSWORD_HASH|${HASHED_PASSWORD}|" ${HERMES_CONFIG_FILE}
###cat /root/.hermes/config.yaml

####################### Load in vault secrets

echo "Loading secrets from Vault mapping"

while IFS='=' read -r ENV_VAR VAULT_LOCATION; do

    # Skip blank lines
    [ -z "$ENV_VAR" ] && continue

    # Skip comments
    case "$ENV_VAR" in
        \#*) continue ;;
    esac

    echo "Fetching $ENV_VAR from Vault"

    RESULTS=$(printf '{"ids":["%s"]}' "$VAULT_LOCATION" | qvaultfromopenclaw)

    if [ $? -ne 0 ]; then
        echo "ERROR retrieving $VAULT_LOCATION"
        exit 1
    fi

    VALUE=$(echo "$RESULTS" | jq -r --arg key "$VAULT_LOCATION" '.values[$key]')

    if [ "$VALUE" = "null" ] || [ -z "$VALUE" ]; then
        echo "ERROR: Secret not found for $ENV_VAR"
        exit 1
    fi

    export "$ENV_VAR=$VALUE"

done < "$VAULT_ENV_FILE"

####################### End of vault in secrets

################ Start of skill transfer ##########
if [ -d "${AGENTHR_SKILL_DIR}" ]; then
  echo "Removing existing skills from data dir"
  rm -rf "${AGENTHR_SKILL_DIR}"
fi
if [ -d "${AGENTHR_SKILL_SOURCE_DIR}" ]; then
  echo "Transferring skills from config into data dir"
  mkdir -p "${AGENTHR_SKILL_DIR}" || exit 1
  cp -R "${AGENTHR_SKILL_SOURCE_DIR}/." "${AGENTHR_SKILL_DIR}" || exit 1
else
    echo "No AgentHR skills configured"
fi
################ End of skill transfer ##########

# Map matrix vars
export MATRIX_HOMESERVER="https://${MATRIX_HOMESERVER_RAW}"
export MATRIX_USER_ID="@${MATRIX_USERNAME_RAW}:${MATRIX_HOMESERVER_RAW}"
echo "Using MATRIX_USER_ID=${MATRIX_USER_ID}"

echo "Starting Hermes dashboard..."
hermes dashboard --host 0.0.0.0 --port 18789 &
DASHBOARD_PID=$!

echo "Starting Hermes gateway..."
hermes "$@" &
GATEWAY_PID=$!

cleanup() {
    STATUS=${1:-0}
    echo "Stopping Hermes..."

    kill -TERM "$DASHBOARD_PID" 2>/dev/null || true
    kill -TERM "$GATEWAY_PID" 2>/dev/null || true

    wait "$DASHBOARD_PID" 2>/dev/null || true
    wait "$GATEWAY_PID" 2>/dev/null || true

    exit "$STATUS"
}

trap cleanup INT TERM

# Wait until either process exits
wait -n "$DASHBOARD_PID" "$GATEWAY_PID"
STATUS=$?

echo "One Hermes process exited."

cleanup "$STATUS"

exit "$STATUS"
