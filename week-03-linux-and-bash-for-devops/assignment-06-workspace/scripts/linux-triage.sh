#!/bin/bash
#
# linux-triage.sh — read-only Linux & Nginx health check.
# Usage: ./scripts/linux-triage.sh [report-path]

full_name="Chukwuka Miracle Unigwe"
service_name="nginx"
http_url="http://localhost"
disk_path="/"
disk_warn_threshold=70
disk_fail_threshold=90
load_warn_threshold=1.5
load_fail_threshold=3.0

report_path="${1:-reports/linux-triage-report.txt}"
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

checks=("service_status" "port_listening" "http_response" "disk_usage" "system_load")

declare -A check_status
declare -A check_evidence

check_service_status() {
    local state
    state=$(systemctl is-active "$service_name" 2>&1)
    check_evidence[service_status]="systemctl is-active $service_name -> $state"
    if [ "$state" == "active" ]; then
        check_status[service_status]="HEALTHY"
    else
        check_status[service_status]="FAIL"
    fi
}

check_port_listening() {
    local listening
    listening=$(ss -ltn 2>/dev/null | grep ':80 ')
    if [ -n "$listening" ]; then
        check_evidence[port_listening]="ss -ltn | grep ':80' -> $listening"
        check_status[port_listening]="HEALTHY"
    else
        check_evidence[port_listening]="ss -ltn | grep ':80' -> no listener found on port 80"
        check_status[port_listening]="FAIL"
    fi
}

check_http_response() {
    local status_line
    status_line=$(curl -Is --max-time 3 "$http_url" 2>&1 | head -n 1)
    check_evidence[http_response]="curl -I $http_url -> ${status_line:-no response}"
    if echo "$status_line" | grep -q "200"; then
        check_status[http_response]="HEALTHY"
    else
        check_status[http_response]="FAIL"
    fi
}

check_disk_usage() {
    local usage
    usage=$(df -h "$disk_path" | awk 'NR==2 {print $5}' | tr -d '%')
    check_evidence[disk_usage]="df -h $disk_path -> ${usage}% used"
    if [ "$usage" -ge "$disk_fail_threshold" ]; then
        check_status[disk_usage]="FAIL"
    elif [ "$usage" -ge "$disk_warn_threshold" ]; then
        check_status[disk_usage]="WARN"
    else
        check_status[disk_usage]="HEALTHY"
    fi
}

check_system_load() {
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    check_evidence[system_load]="uptime -> 1-min load average $load"
    if (( $(echo "$load >= $load_fail_threshold" | bc -l) )); then
        check_status[system_load]="FAIL"
    elif (( $(echo "$load >= $load_warn_threshold" | bc -l) )); then
        check_status[system_load]="WARN"
    else
        check_status[system_load]="HEALTHY"
    fi
}

print_summary() {
    local overall="HEALTHY"
    for check in "${checks[@]}"; do
        case "${check_status[$check]}" in
            FAIL) overall="FAIL" ;;
            WARN) [ "$overall" != "FAIL" ] && overall="WARN" ;;
        esac
    done
    echo "$overall"
}

mkdir -p "$(dirname "$report_path")"

for check in "${checks[@]}"; do
    "check_$check"
done
overall_status=$(print_summary)

{
    echo "===================================================="
    echo "Linux & Nginx Triage Report"
    echo "===================================================="
    echo "Full Name: $full_name"
    echo "Timestamp: $timestamp"
    echo ""

    for check in "${checks[@]}"; do
        echo "[${check_status[$check]}] $check"
        echo "  Evidence: ${check_evidence[$check]}"
    done

    echo ""
    echo "Overall Status: $overall_status"
} | tee "$report_path"

case "$overall_status" in
    HEALTHY) exit 0 ;;
    WARN) exit 1 ;;
    FAIL) exit 2 ;;
esac
