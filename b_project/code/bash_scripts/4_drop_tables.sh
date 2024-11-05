DB_NAME='postgres'
USER_NAME='postgres'

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\i reset.sql"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
