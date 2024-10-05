DB_NAME='postgres'
USER_NAME='postgres'

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\i schema.sql"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
