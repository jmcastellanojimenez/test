#!/bin/bash

## Mandatory variables ##
#AWX_BASE_URL
#AWX_JOB_TEMPLATE_ID

## Optional variables ##
#AWX_WAIT_FOR_JOB
#AWX_WAIT_FOR_JOB_TIMEOUT
#AWX_WAIT_TIMEOUT_TRIES
#AWX_CLUSTER

# Functions
## Logging Events
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Wait Loop for AWX Job Conclusion
check_exit_conditions() {
    local response_code=$1
    local failed=$(jq -r '.failed' <<<"$2")
    local finished=$(jq -r '.finished' <<<"$2")

    # The 'failed' and 'finished' values are only populated once the AWX Job finishes executing.
    if [ "$response_code" -eq 200 ] && [ -n "$failed" ] && [ "$finished" != "null" ]; then
        return 0 # Conditions met, exit loop
    fi

    return 1 # Conditions not met, continue loop
}

declare -A main_args=(
    [AWX_WAIT_FOR_JOB]="true"
    [AWX_WAIT_FOR_JOB_TIMEOUT]="true"
    [AWX_WAIT_TIMEOUT_TRIES]=5
)
declare -A variables_args=(
    [debug_mode]="true"
)

required_keys=(AWX_BASE_URL AWX_JOB_TEMPLATE_ID)

parsing_variables=false

for arg in "$@"; do
    if [[ "$arg" == "--variables" ]]; then
        parsing_variables=true
        continue
    fi

    if ! $parsing_variables; then
        key="${arg%%=*}"
        value="${arg#*=}"
        main_args["$key"]="$value"
    else
        if [[ "$arg" == *:* ]]; then
            key="${arg%%:*}"
            value="${arg#*:}"
        else
            key="${arg%%=*}"
            value="${arg#*=}"
        fi
        variables_args["$key"]="$value"
    fi
done

# Validation
missing_keys=()
for key in "${required_keys[@]}"; do
    if [[ -z "${main_args[$key]}" ]]; then
        missing_keys+=("$key")
    fi
done

if [[ ${#missing_keys[@]} -gt 0 ]]; then
    log "Error: Missing required arguments: ${missing_keys[*]}"
    exit 1
fi

log "--- Main Arguments ---"
for key in "${!main_args[@]}"; do
    log "$key = ${main_args[$key]}"
done

log "--- Variables Arguments ---"
for key in "${!variables_args[@]}"; do
    log "$key = ${variables_args[$key]}"
done

# Validate AWX cluster
if [[ "${main_args[AWX_BASE_URL]}" == *"staging"* ]]; then

  AWX_CLUSTER="pequod"
else
    AWX_CLUSTER="fram"
fi

# Grab Vault-stored Variables
main_args["AWX_USER"]=$(curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" "https://vault.internal.epo.org/v1/secret/$AWX_CLUSTER/ansible-awx/web-administrator-credentials" -k --silent | jq -r '.data.login')
main_args["AWX_PASSWORD"]=$(curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" "https://vault.internal.epo.org/v1/secret/$AWX_CLUSTER/ansible-awx/web-administrator-credentials" -k --silent | jq -r '.data.password')

# Define the extra_vars for the Job
json_vars="{"
for key in "${!variables_args[@]}"; do
    value="${variables_args[$key]}"
    json_vars+="\\\"$key\\\": \\\"$value\\\","
done
# Remove trailing comma
json_vars="${json_vars%,}"
json_vars+="}"

log "--- START EXECUTION ---"

# Call AWX API to execute the Job Template
AWX_EXECUTION_RESPONSE=$(curl -s -f -k -H "Content-Type: application/json" \
  -X POST --user "${main_args[AWX_USER]}:${main_args[AWX_PASSWORD]}" \
  -d "{\"extra_vars\": \"$json_vars\"}" \
  "https://${main_args[AWX_BASE_URL]}/api/v2/job_templates/${main_args[AWX_JOB_TEMPLATE_ID]}/launch/")

# Check if the Initial Execution Request was successful
if [ $? -ne 0 ]; then
    log "Error: Failed to execute AWX Job Template."
    exit 1
fi

# Grab Job Execution ID
AWX_JOB_EXECUTION_ID=$(echo "$AWX_EXECUTION_RESPONSE" | jq -r .job)

# only Wait for AWX Job Execution if specified
if [ "${main_args[AWX_WAIT_FOR_JOB]}" == "true" ]; then
    # Initialize an empty tries variable to exit the loop if tried tries exceed
    tries=0
    # Loop to Check AWX Job Execution Status
    while true; do
        # Only Increment "tries" if indeed we set an AWX Job execution timeout condition.
        # If not specified, this while loop will run forever.
        if [ "${main_args[AWX_WAIT_FOR_JOB_TIMEOUT]}" == "true" ]; then
            ((tries++))
        fi

        # Make API request and capture response
        api_response=$(curl -s -k -H 'Content-Type: application/json' -o /dev/null -w "%{http_code}\n" \
            -XGET --user "${main_args[AWX_USER]}:${main_args[AWX_PASSWORD]}" \
            "https://${main_args[AWX_BASE_URL]}/api/v2/jobs/$AWX_JOB_EXECUTION_ID/")
        api_data=$(curl -s -k -H 'Content-Type: application/json' \
            -XGET --user "${main_args[AWX_USER]}:${main_args[AWX_PASSWORD]}" \
            "https://${main_args[AWX_BASE_URL]}/api/v2/jobs/$AWX_JOB_EXECUTION_ID/")

        # Check exit conditions
        if check_exit_conditions "$api_response" "$api_data"; then
            log "Info: Exiting loop. AWX Job finished executing."
            break
        fi

        # Check if the timeout limit is reached
        if [ "$tries" -ge "${main_args[AWX_WAIT_TIMEOUT_TRIES]}" ]; then
            log "Warn: Timeout reached. Exiting loop."
            break
        fi

        log "Info: Job Execution Conditions are not met yet. Retrying in 10 seconds..."
        sleep 10
    done
fi

# Print and Save Relevant Output
AWX_JOB_EXECUTION_URL="https://${main_args[AWX_BASE_URL]}/#/jobs/playbook/$AWX_JOB_EXECUTION_ID/output"
if [ "${main_args[AWX_WAIT_FOR_JOB]}" == "true" ]; then
    AWX_JOB_FAILED_STATUS="$(echo $api_data | jq -r '.failed')"
    AWX_JOB_EXECUTION_FINISH_TIME="$(echo $api_data | jq -r '.finished')"
fi

if [ "${main_args[AWX_WAIT_FOR_JOB]}" == "true" ]; then
    if [ "$AWX_JOB_EXECUTION_FINISH_TIME" == "null" ]; then
        log "AWX Job Failed: null (Execution Timeout Reached)"
        log "Warn: AWX Job did not finish on the specified timeout window. Use the Job URL and check its output for further information."
    else
        log "AWX Job Execution Finished Time: $AWX_JOB_EXECUTION_FINISH_TIME"
        log "AWX Job Failed: $AWX_JOB_FAILED_STATUS"
        # Show the Execution Recap Logs
        log "AWX Job Execution Output Recap: "
        curl -s -k -H 'Content-Type: application/json' \
            -XGET --user "${main_args[AWX_USER]}:${main_args[AWX_PASSWORD]}" \
            "https://${main_args[AWX_BASE_URL]}/api/v2/jobs/$AWX_JOB_EXECUTION_ID/stdout/?format=txt" | awk '/PLAY RECAP/,0'
    fi
else
    log "AWX Job Failed: null (Skipped Job Completion Check)"
fi
