#!/bin/sh

# Check if hostname contains "scheduler"
if hostname | grep -q "scheduler"; then
    # Write script to check and restart slurmctld to a file
    cat <<'EOF' > /opt/mig_check_and_restart_slurmctld.sh 
    #!/bin/sh

    # Path to the azure.conf file
    SCHED_PATH=$(ls -ld /sched/* | cut -d '/' -f3)
    AZURE_CONF="/sched/$SCHED_PATH/azure.conf"

    # Check if the file has been modified
    if [ -f "$AZURE_CONF" ]; then
        if [ "$AZURE_CONF" -nt /var/run/slurmctld.pid ]; then
            # Restart slurmctld service
            systemctl restart slurmctld
            echo "slurmctld restarted."
        else
            echo "azure.conf has not been modified."
        fi
    else
        echo "Error: $AZURE_CONF not found."
    fi
    EOF

    # Add the cron job and make the script executable
    echo "* * * * * /opt/mig_check_and_restart_slurmctld.sh >/dev/null 2>&1" | crontab -
    chmod +x /opt/mig_check_and_restart_slurmctld.sh
else
    echo "Hostname does not contain 'scheduler'. Exiting."
fi