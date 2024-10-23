INSTALLDIR=$HOME/pgsql
DATA_FOLDER=$HOME/tyx021/data_files

${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\i schema_v3.sql"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\dt"


${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy warehouse from '${DATA_FOLDER}/warehouse.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy district from '${DATA_FOLDER}/district.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"district_2-5\" from '${DATA_FOLDER}/district_2-5.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy customer from '${DATA_FOLDER}/customer.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"customer_2-7\" from '${DATA_FOLDER}/customer_2-7.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"customer_2-8\" from '${DATA_FOLDER}/customer_2-8.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order\" from '${DATA_FOLDER}/order.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy item from '${DATA_FOLDER}/item.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy stock from '${DATA_FOLDER}/stock.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"stock_2-5\" from '${DATA_FOLDER}/stock_2-5.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order-line\" from '${DATA_FOLDER}/order-line.csv' with csv header null 'null'"
${INSTALLDIR}/bin/psql -U $PGUSER -d $PGDATABASE -c "\copy \"order-line-item-constraint\" from '${DATA_FOLDER}/order_line_item_constraint.csv' with csv header null 'null'"