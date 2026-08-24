#!/bin/bash
# Check memory usage and alert if > 85%

export GOG_KEYRING_PASSWORD="xxx"
THRESHOLD=85
WEBHOOK_URL="https://discord.com/api/webhooks/..."

USAGE=$(free | awk 'NR==2{printf "%.0f\n", ($3/$2)*100}')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
    CURRENT_TIME=$(date "+%d %B %Y %H:%M")
    MEM_TOTAL=$(free -h | awk 'NR==2{print $2}' | sed 's/Mi//')
    MEM_USED=$(free -h | awk 'NR==2{print $3}')
    MEM_FREE=$(free -h | awk 'NR==2{print $4}')
    SWAP_TOTAL=$(free -h | awk 'NR==3{print $2}' | sed 's/Mi//')
    SWAP_USED=$(free -h | awk 'NR==3{print $3}')
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    
    # Table 1: USER, PID, PROCESS, %CPU, %MEM, RSS(MB), NOTES
    TOP_PROCS1=$(ps aux --sort=-%mem | head -101 | awk -v threshold=1 '{
        user=$1; pid=$2; cpu=$3; mem=$4; rss=int($6/1024); cmd=$11;
        if (mem >= threshold) {
            if(cmd ~ /openclaw/) notes="Main app"
            else if(cmd ~ /tailscaled/) notes="VPN service"
            else if(cmd ~ /dockerd/) notes="Container daemon"
            else if(cmd ~ /exim|postfix/) notes="Mail server"
            else if(cmd ~ /containerd/) notes="Container runtime"
            else if(cmd ~ /snapd/) notes="Snap daemon"
            else if(cmd ~ /systemd/) notes="System manager"
            else if(cmd ~ /sshd/) notes="SSH daemon"
            else if(cmd ~ /cron/) notes="Cron daemon"
            else if($0 ~ /fail2ban-server/) notes="Fail2ban server"
            else if(cmd ~ /ncpa_listener/) notes="NCPA Listener"
            else notes=""
            printf "| %-8s | %-6s | %-26s | %5s%% | %5s%% | %7s MB | %-16s |\n", user, pid, cmd, cpu, mem, rss, notes
        }
    }')
    
    # Table 2: USER, PID, PROCESS, START, TIME, NOTES
    TOP_PROCS2=$(ps aux --sort=-%mem | head -101 | awk -v threshold=1 '{
        user=$1; pid=$2; start=$9; time=$10; cmd=$11; mem=$4;
        if (mem >= threshold) {
            if(cmd ~ /openclaw/) notes="Main app"
            else if(cmd ~ /tailscaled/) notes="VPN service"
            else if(cmd ~ /dockerd/) notes="Container daemon"
            else if(cmd ~ /exim|postfix/) notes="Mail server"
            else if(cmd ~ /containerd/) notes="Container runtime"
            else if(cmd ~ /snapd/) notes="Snap daemon"
            else if(cmd ~ /systemd/) notes="System manager"
            else if(cmd ~ /sshd/) notes="SSH daemon"
            else if(cmd ~ /cron/) notes="Cron daemon"
            else if($0 ~ /fail2ban-server/) notes="Fail2ban server"
            else if(cmd ~ /ncpa_listener/) notes="NCPA Listener"
            else notes=""
            printf "| %-8s | %-6s | %-26s | %-5s | %-5s | %-16s |\n", user, pid, cmd, start, time, notes
        }
    }')
    
    MESSAGE="*** ${CURRENT_TIME} ***
Memory Alert: ${USAGE}% used (threshold: ${THRESHOLD}%)
RAM: ${MEM_USED} / ${MEM_TOTAL}Mi (free: ${MEM_FREE})
Swap: ${SWAP_USED} / ${SWAP_TOTAL}Mi
Load: ${LOAD}

[Table 1: CPU/MEM]
| USER    | PID   | PROCESS                    | %CPU  | %MEM  | RSS(MB) | NOTES            |
|---------|-------|----------------------------|-------|-------|---------|------------------|
${TOP_PROCS1}

[Table 2: START/TIME]
| USER    | PID   | PROCESS                    | START | TIME  | NOTES            |
|---------|-------|----------------------------|-------|-------|------------------|
${TOP_PROCS2}
"
    
    # Truncate message if too long (Discord limit is 2000 chars)
    if [ ${#MESSAGE} -gt 1950 ]; then
        MESSAGE="${MESSAGE:0:1950}"
        MESSAGE="$MESSAGE... [Discord limit reached]"
    fi
    
    # Send Discord webhook using jq for proper JSON escaping
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$(/usr/bin/jq -n --arg msg "$MESSAGE" '{content: $msg}')"
    
    # Send email alert
    #/home/linuxbrew/.linuxbrew/bin/gog gmail send --to user@gmail.com --subject "⚠️ Memory Alert: ${USAGE}%" --body "$MESSAGE"
    echo "$MESSAGE" | mail -s "⚠️ Memory Alert: ${USAGE}%" user@gmail.com

fi
