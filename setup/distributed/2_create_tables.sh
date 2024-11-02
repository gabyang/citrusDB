DB_NAME='postgres'
USER_NAME='postgres'

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "select * from master_get_active_worker_nodes();"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\i schema_v4.sql"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
