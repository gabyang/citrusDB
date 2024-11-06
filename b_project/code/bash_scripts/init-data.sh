INSTALLDIR=$HOME/pgsql
DATA_FOLDER=$HOME/b_project/code/data_files
SCHEMA_FOLDER=$HOME/b_project/code

${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\i ${SCHEMA_FOLDER}/schema_v4.sql"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\dt"

# For schema v4
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy warehouse from '${DATA_FOLDER}/warehouse.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy district from '${DATA_FOLDER}/base_district.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"district_2-5\" from '${DATA_FOLDER}/district_2-5.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy customer from '${DATA_FOLDER}/base_customer.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"customer_2-7\" from '${DATA_FOLDER}/customer_2-7.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"customer_2-8\" from '${DATA_FOLDER}/customer_2-8.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order\" from '${DATA_FOLDER}/order.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy item from '${DATA_FOLDER}/item.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy stock from '${DATA_FOLDER}/base_stock.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"stock_2-5\" from '${DATA_FOLDER}/stock_2-5.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order-line\" from '${DATA_FOLDER}/order-line.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order-line-item-constraint\" from '${DATA_FOLDER}/order_line_item_constraint.csv' with csv header null 'null'"