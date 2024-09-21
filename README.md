# Project DistribuShop
An e-commerce application for processing transactions and distributing data in a sharded database using CitusDB.

# First Time Setup CitusDB (Docker)

Run docker-compose to build image with 5 nodes. 1 master and 4 worker nodes.
```
docker-compose up -d --scale worker=4
```

### Understanding the role of the master and worker nodes:
#### Master Node (Coordinator)
**Role:** The master node acts as the coordinator in a Citus cluster. It's the entry point for all client connections and queries.
**Function:** It holds metadata about the distributed tables, plans queries, and dispatches them to the worker nodes.
**Data Storage:** By default, the master node doesn't store data of distributed tables; it only stores metadata and handles query planning.

#### Worker Nodes
**Role:** Worker nodes store the actual data of the distributed tables.
**Function:** They execute the parts of queries dispatched by the master node, handling data storage and processing.
**Data Storage:** Each worker node stores shards (partitions) of the distributed tables.

**Note:** 
Since we aren't using the manager node, we need to manually register each worker node with the master.


### Connect to the Master Node
```
docker exec -it citus_master psql -U postgres
```

Register Master and Workers:
```
-- Once Connected to the master node's PostgreSQL instance
SELECT master_add_node('master', 5432);
SELECT master_add_node('worker_1', 5432);
SELECT master_add_node('worker_2', 5432);
SELECT master_add_node('worker_3', 5432);
SELECT master_add_node('worker_4', 5432);
```
Note: The hostnames worker_1, worker_2, etc., are automatically assigned by Docker when scaling services. Ensure these match your actual container hostnames.
Register the Master as a Worker (if not already done):

### Verify the Cluster Setup
After registering the nodes, verify that all nodes are active:
```
SELECT * FROM master_get_active_worker_nodes();
```
This should list all worker nodes, including the master.

### Set up distributed schema and data

Run the bash script to create the tables and seed the data into each table
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

**Note:** to delete exited containers if you encounter an error that says docker container with name citus exist
```
docker container prune
```

# Reference
- https://docs.citusdata.com/en/v11.1/use_cases/multi_tenant.html
- https://docs.citusdata.com/en/v12.1/installation/single_node_docker.html
- https://docs.citusdata.com/en/v5.1/installation/production_deb.html
- https://docs.citusdata.com/en/v5.1/installation/single_machine_osx.html