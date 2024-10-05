DB_NAME='postgres'
USER_NAME='postgres'

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\dt"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS \"order-line\" CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS stock CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS item CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS \"order\" CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS customer CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS district CASCADE;"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "DROP TABLE IF EXISTS warehouse CASCADE;"
