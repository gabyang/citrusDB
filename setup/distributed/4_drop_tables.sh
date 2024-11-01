DB_NAME='postgres'
USER_NAME='postgres'

psql -U postgres -d postgres -c "\dt"
psql -U postgres -d postgres -c "\i reset.sql"
psql -U postgres -d postgres -c "\dt"
