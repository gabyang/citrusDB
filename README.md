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
SELECT citus_set_coordinator_host('master', 5432);
SELECT master_add_node('citusdb-worker-1', 5432);
SELECT master_add_node('citusdb-worker-2', 5432);
SELECT master_add_node('citusdb-worker-3', 5432);
SELECT master_add_node('citusdb-worker-4', 5432);
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

- Create the schema
```sql
\i schema_modified.sql
```

- Populate the data into the tables
```sql
\copy warehouse from '/warehouse.csv' with csv header
\copy district from '/district.csv' with csv header
\copy customer from '/customer.csv' with csv header
\copy "order" from '/order.csv' with csv header null 'null'
\copy item from '/item.csv' with csv header
\copy stock from '/stock.csv' with csv header
\copy "order-line" from '/order-line.csv' with csv header null 'null'
```
- Create distributed tables
```sql
select * from master_get_active_worker_nodes(); -- Check if the worker nodes are active and connected
SELECT create_distributed_table('warehouse', 'w_id');
SELECT * FROM pg_dist_shard_placement; -- Check the data is placed in which shard
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