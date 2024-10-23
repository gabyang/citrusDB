#!/usr/bin/env bash

coordinator_node=$1
HOSTNAME=$(hostname)
REMAINDER=$(($SLURM_PROCID % 5))

INSTALLDIR=$HOME/pgsql
SCRIPTSDIR="$HOME/project_files/scripts"
LOGDIR=$HOME/tyx021
LOGFILE=${LOGDIR}/log.txt
LOCKFILE=/tmp/citus-init.lock  # Lock file for synchronization
DATA_FOLDER=$HOME/tyx021/data_files

NODELIST=$(scontrol show hostname $SLURM_NODELIST) # Gets a list of hostnames
NODE_ARRAY=($NODELIST) # Convert the list into an array

SIGNAL_DIR="../$SLURM_JOB_ID"
ADD_TABLE_SIGNAL_FILE=${SIGNAL_DIR}/add_table_signal

signal_worker_done() {
    touch ${ADD_TABLE_SIGNAL_FILE}
}

wait_worker_done() {
    while [ ! -f ${ADD_TABLE_SIGNAL_FILE} ]; do
        sleep 5
    done
}

# create log directory
if [ ! -d "${LOGDIR}" ]; then
	mkdir -p ${LOGDIR}
fi

if [ ! -d "${SIGNAL_DIR}" ]; then
    mkdir -p ${SIGNAL_DIR}
fi



if [ ${REMAINDER} -eq 0 ]; then
    rm -rf /tmp/.s.PGSQL.5098.lock
    bash ${SCRIPTSDIR}/init-citus-db.sh

    # worker nodes and coordinator node will start & create the database
    ${INSTALLDIR}/bin/pg_ctl -D $PGDATA -l ${LOGFILE} -o "-p ${PGPORT}" start
    ${INSTALLDIR}/bin/createdb -U $PGUSER $PGDATABASE
    ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "CREATE EXTENSION citus;"

    if [ "${HOSTNAME}" = "$coordinator_node" ]; then
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as the Citus coordinator node"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT citus_set_coordinator_host('${HOSTNAME}', $PGPORT);"
        # set up the worker nodes
        sleep 30 # wait for the worker nodes to start
        for ((i=1; i<${SLURM_NNODES}; i++)); do
            ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT * from citus_add_node('${NODE_ARRAY[$i]}', $PGPORT);"
        done
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT * from citus_get_active_worker_nodes();"

        bash $HOME/tyx021/init-data.sh
        signal_worker_done
    else
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a Citus worker node"
        wait_worker_done
    fi
else
	echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a client issuing transactions" 
fi
