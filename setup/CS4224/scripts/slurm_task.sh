#!/usr/bin/env bash

coordinator_node=$1
HOSTNAME=$(hostname)
REMAINDER=$(($SLURM_PROCID % 5))

TEAM_ID=b
INSTALLDIR=$HOME/pgsql
SCRIPTSDIR="$HOME/project_files/scripts"
LOGDIR=$HOME/team${TEAM_ID}-logs
LOGFILE=${LOGDIR}/log.txt
LOCKFILE=/tmp/citus-init.lock  # Lock file for synchronization

NODELIST=$(scontrol show hostname $SLURM_NODELIST) # Gets a list of hostnames
NODE_ARRAY=($NODELIST) # Convert the list into an array

# Check if Citus is already initialized
if [ ! -d "$PGDATA" ]; then
    # Acquire the lock if it's the first node running the initialization
    if [ ! -f "${LOCKFILE}" ]; then
        # Create the lock file
        echo "Initializing Citus on ${HOSTNAME}" > "${LOCKFILE}"
        # Run the init script
        source ${SCRIPTSDIR}/init-citus-db.sh
        # After initialization, remove the lock file to signal completion
        rm -f "${LOCKFILE}"
    else
        # Wait for the lock file to be removed (i.e., wait for init to finish)
        while [ -f "${LOCKFILE}" ]; do
            sleep 5
        done
    fi
fi

# create log directory
if [ ! -d "${LOGDIR}" ]; then
	mkdir -p ${LOGDIR}
fi

# Cleanup old lock files
rm -rf /tmp/.s.PGSQL.$PGPORT.lock
rm -f $PGDATA/postmaster.pid # Remove the postmaster.pid if it exists

if [ ${REMAINDER} -eq 0 ]; then
    # worker nodes and coordinator node will start & create the database
    ${INSTALLDIR}/bin/pg_ctl -D $PGDATA -l ${LOGFILE} -o "-p ${PGPORT}" start
    ${INSTALLDIR}/bin/createdb -U $PGUSER $PGDATABASE
    if [ "${HOSTNAME}" = "$coordinator_node" ]; then
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as the Citus coordinator node"

        # Create the Citus extension if it does not exist
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "CREATE EXTENSION citus;"
        ${INSTALLDIR}/bin/psql -c "SELECT citus_set_coordinator_host('${HOSTNAME}', $PGPORT);"
        # set up the worker nodes
        sleep 20
        for ((i=1; i<${SLURM_NNODES}; i++)); do
            ${INSTALLDIR}/bin/psql -c "SELECT * from citus_add_node('${NODE_ARRAY[$i]}', $PGPORT);"
        done
        ${INSTALLDIR}/bin/psql -c "SELECT * from citus_get_active_worker_nodes();"
        ${INSTALLDIR}/bin/pg_ctl -D $PGDATA -l ${LOGFILE} -o "-p ${PGPORT}" stop
    else
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a Citus worker node"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "CREATE EXTENSION citus;"
        sleep 120
        echo "Starting worker node on ${HOSTNAME} (probably terminated after this)"
    fi
else
	echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a client issuing transactions" 
fi
