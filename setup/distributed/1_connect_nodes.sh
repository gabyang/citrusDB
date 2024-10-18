DB_NAME='postgres'
USER_NAME='postgres'

PREFIX="citrusdb"
MASTER_NODE_NAME="${PREFIX}-master"
WORKER1_NODE_NAME="${PREFIX}-worker-1"
WORKER2_NODE_NAME="${PREFIX}-worker-2"
WORKER3_NODE_NAME="${PREFIX}-worker-3"
WORKER4_NODE_NAME="${PREFIX}-worker-4"

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT citus_set_coordinator_host('${MASTER_NODE_NAME}', 5432);"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT master_add_node('${WORKER1_NODE_NAME}', 5432);"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT master_add_node('${WORKER2_NODE_NAME}', 5432);"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT master_add_node('${WORKER3_NODE_NAME}', 5432);"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT master_add_node('${WORKER4_NODE_NAME}', 5432);"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "SELECT * FROM master_get_active_worker_nodes();"
