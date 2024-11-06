#!/usr/bin/env bash

coordinator_node=$1
HOSTNAME=$(hostname)
# REMAINDER=$(($SLURM_PROCID % 5))
REMAINDER=$(($SLURM_PROCID % $SLURM_NTASKS_PER_NODE))

INSTALLDIR=$HOME/pgsql
SCRIPTSDIR=$HOME/tyx021
XACTDIR=$HOME/project_files/xact_files
OUTPUTDIR=$HOME/output
CODEDIR=$HOME/tyx021/test-run

LOGFILE=${CODEDIR}/log.txt
NODELIST=$(scontrol show hostname $SLURM_NODELIST) # Gets a list of hostnames
NODE_ARRAY=($NODELIST) # Convert the list into an array

SIGNAL_DIR=$HOME/signal/$SLURM_JOB_ID
TABLE_SETUP_DONE_SIGNAL_FILE="${SIGNAL_DIR}/table_setup_done"
BARRIER_DIR=${SIGNAL_DIR}/barrier

signal_table_setup_done() {
    touch ${TABLE_SETUP_DONE_SIGNAL_FILE}
}

wait_table_setup() {
    while [ ! -f ${TABLE_SETUP_DONE_SIGNAL_FILE} ]; do
        sleep 5
    done
}

signal_barrier() {
    touch ${BARRIER_DIR}/node_${SLURM_PROCID}_ready
}

wait_barrier() {
    while [ $(ls ${BARRIER_DIR} | wc -l) -lt ${SLURM_NTASKS} ]; do
        sleep 5
    done
}

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
        echo "LOG: Start setting up the Citus cluster at $(date +"%Y-%m-%d %H:%M:%S")"
        echo "Process $SLURM_PROCID on ${HOSTNAME} will be executing as the Citus coordinator node"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT citus_set_coordinator_host('${HOSTNAME}', $PGPORT);"
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "ALTER DATABASE $PGDATABASE SET citus.enable_repartition_joins = 'true';"
        
        # set up the worker nodes
        sleep 30 # wait for the worker nodes to start
        for ((i=1; i<${SLURM_NNODES}; i++)); do
            ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT * from citus_add_node('${NODE_ARRAY[$i]}', $PGPORT);"
        done
        ${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "SELECT * from citus_get_active_worker_nodes();"

        # Remove and recreate the output folder
        rm -rf ${OUTPUTDIR}
        mkdir -p ${OUTPUTDIR}

        bash ${SCRIPTSDIR}/init-data.sh
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

    # Assign task file based on task_counter and execute respective txn
    task_file="${XACTDIR}/${task_counter}.txt"
    echo "LOG: Process $SLURM_PROCID is working on txn ${task_file} at $(date +"%Y-%m-%d %H:%M:%S")"
    python3 ${CODEDIR}/main.py ${task_counter} ${OUTPUTDIR} < ${task_file}
    wait
    echo "LOG: Process $SLURM_PROCID has finished running txn ${task_file} at $(date +"%Y-%m-%d %H:%M:%S")"
fi

# To prevent the script from exiting before all processes are done
signal_barrier
wait_barrier

# coordinator node will remove signal files
if [ ${REMAINDER} -eq 0 ] && [ "${HOSTNAME}" = "$coordinator_node" ]; then
    sleep 5
    rm -rf ${SIGNAL_DIR}
    echo "LOG: Removed signal directory"
    echo "LOG: Finished running at $(date +"%Y-%m-%d %H:%M:%S")"
fi
