DB_NAME='postgres'
USER_NAME='postgres'

DATA_FOLDER="project_files/data_files"

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy warehouse from '${DATA_FOLDER}/warehouse.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy district from '${DATA_FOLDER}/district.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy customer from '${DATA_FOLDER}/customer.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order\" from '${DATA_FOLDER}/order.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy item from '${DATA_FOLDER}/item.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy stock from '${DATA_FOLDER}/stock.csv' with csv null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order-line\" from '${DATA_FOLDER}/order-line.csv' with csv null 'null'"
