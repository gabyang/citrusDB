psql -U postgres -d postgres < schema.sql

psql -U postgres -d postgres -c "\\copy warehouse from 'warehouse.csv' with csv header"
psql -U postgres -d postgres -c "\\copy district from 'district.csv' with csv header"
psql -U postgres -d postgres -c "\\copy customer from 'customer.csv' with csv header"
psql -U postgres -d postgres -c "\\copy \"order\" from 'order.csv' with csv header null 'null'"
psql -U postgres -d postgres -c "\\copy item from 'item.csv' with csv header"
psql -U postgres -d postgres -c "\\copy \"order-line\" from 'order-line.csv' with csv header null 'null'"
psql -U postgres -d postgres -c "\\copy stock from 'stock.csv' with csv header"
