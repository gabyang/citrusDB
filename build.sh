docker build -t citus .
docker run --name citus -p 5500:5432 -e POSTGRES_PASSWORD=password citus