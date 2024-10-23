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
BARRIER_DIR="${SIGNAL_DIR}/barrier"
TABLE_SETUP_DONE_SIGNAL_FILE="${SIGNAL_DIR}/table_setup_done"

signal_table_setup_done() {
    touch ${TABLE_SETUP_DONE_SIGNAL_FILE}
}

wait_table_setup() {
    while [ ! -f ${TABLE_SETUP_DONE_SIGNAL_FILE} ]; do
        sleep 5
    done
}

signal_barrier() {
    touch ${SIGNAL_DIR}/node_${SLURM_PROCID}_ready
}

wait_barrier() {
    while [ $(ls ${BARRIER_DIR} | wc -l) -lt ${SLURM_NNODES} ]; do
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

if [ ! -d "${BARRIER_DIR}" ]; then
    mkdir -p ${BARRIER_DIR}
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
        signal_table_setup_done
    else
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a Citus worker node"
        wait_table_setup
    fi
else
	echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as a client issuing transactions" 
    wait_table_setup

    # Initialize a task counter to map processes to text files
    task_counter=0

    # Calculate the task file based on the process ID
    for ((i=0; i<${SLURM_PROCID}; i++)); do
        if [ $((i % 5)) -ne 0 ]; then
            task_counter=$((task_counter + 1))
        fi
    done

    # Assign task file based on task_counter
    task_file="${task_counter}.TXT"
    echo "Process $SLURM_PROCID is working on task ${task_file}"

    # Execute a job related to the task file
    # python3 test-run/main.py ${coordinator_node} --input "${task_file}"
fi

# To prevent the script from exiting before all processes are done
signal_barrier
wait_barrier

# coordinator node will remove signal files
if [ ${REMAINDER} -eq 0 ] && [ "${HOSTNAME}" = "$coordinator_node" ]; then
    rm -rf ${SIGNAL_DIR}
fi
