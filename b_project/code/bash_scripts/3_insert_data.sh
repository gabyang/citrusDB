DB_NAME='postgres'
USER_NAME='postgres'

DATA_FOLDER="project_files/data_files"

# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy warehouse from '${DATA_FOLDER}/warehouse.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy district from '${DATA_FOLDER}/district.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy customer from '${DATA_FOLDER}/customer.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order\" from '${DATA_FOLDER}/order.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy item from '${DATA_FOLDER}/item.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy stock from '${DATA_FOLDER}/stock.csv' with csv header null 'null'"
# psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order-line\" from '${DATA_FOLDER}/order-line.csv' with csv header null 'null'"

psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy warehouse from '${DATA_FOLDER}/warehouse.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy district from '${DATA_FOLDER}/base_district.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"district_2-5\" from '${DATA_FOLDER}/district_2-5.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy customer from '${DATA_FOLDER}/base_customer.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"customer_2-7\" from '${DATA_FOLDER}/customer_2-7.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"customer_2-8\" from '${DATA_FOLDER}/customer_2-8.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order\" from '${DATA_FOLDER}/order.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy item from '${DATA_FOLDER}/item.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy stock from '${DATA_FOLDER}/base_stock.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"stock_2-5\" from '${DATA_FOLDER}/stock_2-5.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order-line\" from '${DATA_FOLDER}/order-line.csv' with csv header null 'null'"
psql -U "${USER_NAME}" -d "${DB_NAME}" -c "\copy \"order-line-item-constraint\" from '${DATA_FOLDER}/order_line_item_constraint.csv' with csv header null 'null'"