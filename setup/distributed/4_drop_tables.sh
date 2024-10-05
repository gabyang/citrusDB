DB_NAME='postgres'
USER_NAME='postgres'

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP SCHEMA public CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "CREATE SCHEMA public;"
