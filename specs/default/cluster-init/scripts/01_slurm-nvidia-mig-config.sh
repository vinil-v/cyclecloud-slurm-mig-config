#!/bin/sh
# Title: Slurm with MIG Mode Configuration
# Description: This script configures Slurm with MIG mode enabled and sets up MIG profiles.

# Retrieve the MIG profile from the Jetpack configuration
MIGMODEPROFILE=$(jetpack config mig.profile)

if [ -z "$MIGMODEPROFILE" ]; then
    echo "Error: MIGMODEPROFILE variable is not set."
    exit 1
fi
# Determine the number of MIG instances based on the MIG profile
# Assigning the appropriate number of instances according to the profile's specifications
case $MIGMODEPROFILE in
    "1g.12gb")
        NUM_MIG_INSTANCES=7 ;;
    "1g.24gb")
        NUM_MIG_INSTANCES=4 ;;
    "2g.24gb")
        NUM_MIG_INSTANCES=3 ;;
    "3g.47gb")
        NUM_MIG_INSTANCES=2 ;;
    "4g.47gb" | "7g.94gb")
        NUM_MIG_INSTANCES=1 ;;
    *)
        NUM_MIG_INSTANCES=1 ;;
esac

SCHED_PATH=$(ls -ld /sched/* | cut -d '/' -f3)
SCHEDULER_HOST=$(jetpack config slurm.node_prefix)scheduler

# Specify the number of MIG instances


# Create the MIG config string
MIG_CONFIG=""

for i in $(seq 1 $NUM_MIG_INSTANCES); do
    if [ -n "$MIG_CONFIG" ]; then
        MIG_CONFIG="$MIG_CONFIG,"
    fi
    MIG_CONFIG="$MIG_CONFIG$MIGMODEPROFILE"
done

echo "MIG config string: $MIG_CONFIG"

# Enable MIG mode and configure MIG instances
/usr/bin/nvidia-smi -pm 1
/usr/bin/nvidia-smi -mig 1
/usr/bin/nvidia-smi mig -dci
/usr/bin/nvidia-smi mig -cgi $MIG_CONFIG
/usr/bin/nvidia-smi mig -cci

# Clone repository for gres.conf setup
rm -rf slurm-mig-discovery
git clone https://gitlab.com/nvidia/hpc/slurm-mig-discovery.git
cd slurm-mig-discovery/
gcc -g -o mig -I/usr/local/cuda/include -I/usr/cuda/include mig.c -lnvidia-ml
./mig

# Copy gres.conf and cgroup_allowed_devices_file.conf
echo "Creating gres.conf and cgroup_allowed_devices_file.conf"
cp gres.conf /sched/$SCHED_PATH/
cp cgroup_allowed_devices_file.conf /sched/$SCHED_PATH/
unlink /etc/slurm/gres.conf
unlink /etc/slurm/cgroup_allowed_devices_file.conf
ln -s /sched/$SCHED_PATH/gres.conf /etc/slurm/gres.conf
ln -s /sched/$SCHED_PATH/cgroup_allowed_devices_file.conf /etc/slurm/cgroup_allowed_devices_file.conf

# Update azure.conf with MIG settings
MIGMODEFROMGRESCONF=$(awk -F '[= ]' '/Name/{print $4; exit}' /etc/slurm/gres.conf)
SLURMGRESCONF=$(grep Gres /etc/slurm/azure.conf | awk '{print $7}')
sed -i "s/$SLURMGRESCONF/Gres=gpu:$MIGMODEFROMGRESCONF:$NUM_MIG_INSTANCES/" /sched/$SCHED_PATH/azure.conf

# Restart slurmd
echo "Restarting slurmd"
systemctl restart slurmd

