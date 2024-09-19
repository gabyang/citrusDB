# citrusDB
🍋🍋🍋

# Setup CitusDB (Docker)
- Run the bash script to build the docker image with the csv and sql files, and start the container
```
build.sh
```
- Open another terminal and access the docker container
```
docker exec -it citus bash
```
- Check the following files exist
```
root@e90f226887ac:/app# ls
ads.csv  campaigns.csv	clicks.csv  companies.csv  geo_ips.csv	impressions.csv  init.sh  schema.sql
```
- Run the bash script to create the tables and seed the data into each table
```
bash init.sh
```
- Run the following command to access postgres shell 
```
psql -U postgres
```
- Check the following query give the same output
```
postgres=# SELECT name, cost_model, state, monthly_budget FROM campaigns WHERE company_id = 5 ORDER BY monthly_budget DESC LIMIT 10;
             name              |     cost_model      |  state   | monthly_budget 
-------------------------------+---------------------+----------+----------------
 Captain Annihilus             | cost_per_click      | archived |           9352
 Supah Scorpion Wolf           | cost_per_impression | running  |           7420
 Dark Groot Boy                | cost_per_impression | running  |           6496
 Supah Bat Lord                | cost_per_impression | archived |           4307
 Giant Toxin Girl              | cost_per_click      | running  |           4057
 Shocker                       | cost_per_impression | paused   |           3914
 Giant Maya Herrera I          | cost_per_click      | archived |           3712
 Agent Rachel Pirzad of Hearts | cost_per_click      | archived |           3538
 Lyja                          | cost_per_click      | archived |           2369
(9 rows)
```
- Note to change the following line in `Dockerfile` from `setup/tutorials/` to `setup/CS4224/` to initialise the database with actual data
```
COPY setup/tutorials/ .
```
- Note to delete exited containers if you encounter an error that says docker container with name citus exist
```
docker container prune
```

# Reference
- https://docs.citusdata.com/en/v11.1/use_cases/multi_tenant.html
- https://docs.citusdata.com/en/v12.1/installation/single_node_docker.html
- https://docs.citusdata.com/en/v5.1/installation/production_deb.html
- https://docs.citusdata.com/en/v5.1/installation/single_machine_osx.html