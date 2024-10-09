#!/usr/bin/env bash

coordinator_node=$1
HOSTNAME=$(hostname)
REMAINDER=$(($SLURM_PROCID % 5))

INSTALLDIR=$HOME/pgsql
SCRIPTSDIR="$HOME/project_files/scripts"
LOGDIR=/tmp/team${TEAM_ID}-log
LOGFILE=${LOGDIR}/log.txt
LOCKFILE=/tmp/citus-init.lock  # Lock file for synchronization

# Check if Citus is already initialized
if [ ! -d "$PGDATA" ]; then
    # Acquire the lock if it's the first node running the initialization
    if [ ! -f "${LOCKFILE}" ]; then
        # Create the lock file
        echo "Initializing Citus on ${HOSTNAME}" > "${LOCKFILE}"

        # Run the init script
        # echo "Initializing Citus for ${HOSTNAME} at $PGDATA"
        source ${SCRIPTSDIR}/init-citus-db.sh

        # After initialization, remove the lock file to signal completion
        rm -f "${LOCKFILE}"
    else
        # Wait for the lock file to be removed (i.e., wait for init to finish)
        # echo "Waiting for Citus initialization to complete on ${HOSTNAME}"
        while [ -f "${LOCKFILE}" ]; do
            sleep 5
        done
        # echo "Citus initialization completed. Proceeding on ${HOSTNAME}"
    fi
fi

# create log directory
if [ ! -d "${LOGDIR}" ]; then
	mkdir -p ${LOGDIR}
fi

# Cleanup old lock files
rm -f /tmp/.s.PGSQL.$PGPORT.lock
rm -f $PGDATA/postmaster.pid # Remove the postmaster.pid if it exists


# Start PostgreSQL server
${INSTALLDIR}/bin/pg_ctl -D $PGDATA -l ${LOGFILE} -o "-p ${PGPORT}" start
# ${INSTALLDIR}/bin/postgres -D $PGDATA -p $PGPORT > ${LOGFILE} 2>&1 &
# sleep 30  # Wait for the server to start

# Wait for PostgreSQL to start
until ${INSTALLDIR}/bin/pg_isready -p $PGPORT; do
    sleep 2
done

# Create the database 'project'
${INSTALLDIR}/bin/createdb -U $PGUSER $PGDATABASE

# Create the Citus extension if it does not exist
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "CREATE EXTENSION citus;"

# if [ ${REMAINDER} -eq 0 ]; then
# 	if [ "${HOSTNAME}" = "$coordinator_node" ]; then
# 		echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as the Citus coordinator node"
# 		${INSTALLDIR}/bin/psql -c "SELECT citus_set_coordinator_host('${HOSTNAME}', $PGPORT);"
# 		${INSTALLDIR}/bin/psql -c "SELECT * FROM citus_get_active_worker_nodes();"
# 	else
# 		echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a Citus worker node"
# 		${INSTALLDIR}/bin/psql -c "SELECT master_add_node('${HOSTNAME}', $PGPORT);"
# 	fi
# else
if [ ${REMAINDER} -eq 0 ]; then
    if [ "${HOSTNAME}" = "$coordinator_node" ]; then
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as the Citus coordinator node"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT citus_set_coordinator_host('${HOSTNAME}', $PGPORT);"

        # Collect and add worker nodes
		sleep 60
        for worker_node in "${worker_nodes[@]}"; do
            echo "Adding worker node: ${worker_node} to the coordinator"
            ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT master_add_node('${worker_node}', $PGPORT);"
        done

        echo "Coordinator node setup complete. Active worker nodes:"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT * FROM citus_get_active_worker_nodes();"
    else
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a Citus worker node"
        # Store the worker node information for the coordinator to add later
        worker_nodes+=("${HOSTNAME}")
    fi
else
	echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a client issuing transactions" 
fi
