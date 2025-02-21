#!/bin/bash

# Parameters
SERVICE_LSWS="lshttpd"
SERVICE_ADC="lslb"
LSHTTPD_BIN="/var/www/bin/lshttpd"
LSLBD_BIN="/var/www/bin/lslbd"
FLAG_LICENSE_ISSUE="/root/litespeed_license_issue.flag"
FLAG_SERVICE_STOPPED="/root/litespeed_stopped.flag"
JEM_API_CALL="/usr/bin/jem api apicall [API_DOMAIN]/1.0/environment/node/rest/sendevent --data-urlencode params={\"name\":\"license-issue\"}"
LOG_OUTPUT="/var/www/logs/monitor.log"
CURRENT_TIME=$(date +%s)
USER="litespeed"

# Log function
log() {
    sudo -u $USER bash -c "echo \"$(date '+%Y-%m-%d %H:%M:%S') - $1\" | tee -a \"$LOG_OUTPUT\""
}

# Function to handle license issues
handle_license_issue() {
    local issue_message="$1"
    log "License issue detected via $LICENSE_CHECK -V: $issue_message."
    if [[ ! -f "$FLAG_LICENSE_ISSUE" ]]; then
        log "Calling JEM API due to license issue."
        $JEM_API_CALL
        touch "$FLAG_LICENSE_ISSUE"
    else
        log "License issue already recorded. Doing nothing."
    fi
    exit 0
}

# Determine Litespeed type from /etc/jelastic/metainf.conf
META_INF_FILE="/etc/jelastic/metainf.conf"
if [[ -f "$META_INF_FILE" ]]; then
    COMPUTE_TYPE=$(grep "^COMPUTE_TYPE=" "$META_INF_FILE" | cut -d'=' -f2)
    if [[ "$COMPUTE_TYPE" == "litespeed" || "$COMPUTE_TYPE" == "LLSMP" ]]; then
        SERVICE="$SERVICE_LSWS"
        LICENSE_CHECK="$LSHTTPD_BIN"
    elif [[ "$COMPUTE_TYPE" == "litespeed_adc" ]]; then
        SERVICE="$SERVICE_ADC"
        LICENSE_CHECK="$LSLBD_BIN"
    else
        log "Unknown COMPUTE_TYPE: $COMPUTE_TYPE. Exiting."
        exit 1
    fi
else
    log "Meta information file not found. Exiting."
    exit 1
fi

# Check if the process is running
if systemctl is-active --quiet "$SERVICE"; then
    log "Process $SERVICE is running."
    rm -f "$FLAG_LICENSE_ISSUE" "$FLAG_SERVICE_STOPPED"
    exit 0
fi

# If the process is not running, check the license
if [[ -f "$FLAG_SERVICE_STOPPED" ]]; then
    log "Process is stopped but license is known to be valid. Skipping license check."
    exit 0
fi

if [[ -x "$LICENSE_CHECK" ]]; then
    LICENSE_OUTPUT=$("$LICENSE_CHECK" -V 2>&1)
    if echo "$LICENSE_OUTPUT" | grep -q "Invalid license"; then
        handle_license_issue "Invalid license"
    elif echo "$LICENSE_OUTPUT" | grep -q "Serial number is not active"; then
        handle_license_issue "Serial number is not active"
    elif echo "$LICENSE_OUTPUT" | grep -q "License key operation failure"; then
        handle_license_issue "License key operation failure"
    elif echo "$LICENSE_OUTPUT" | grep -q "Invalid serial number"; then
        handle_license_issue "Invalid serial number"
    elif echo "$LICENSE_OUTPUT" | grep -q "serial.no is missing"; then
        handle_license_issue "serial.no is missing"
    else
        log "Process is stopped. License check via $LICENSE_CHECK -V passed. No issues detected."
        touch "$FLAG_SERVICE_STOPPED"
    fi
else
    log "Binary not found or not executable. Skipping license check."
fi
