#!/bin/bash

# Define the Docker container name
CONTAINER_NAME=citus_master

# Copy CSV files to the Docker container
for dataset in warehouse district customer order item order-line stock; do
  docker cp ${dataset}.csv citus_master:.
done

docker cp schema_modified.sql citus_master:.