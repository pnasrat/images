#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail -x

# Define the image name variable
IMAGE_NAME=cgr.dev/chainguard/cassandra:latest

# Start a Cassandra container
CASSANDRA_CONTAINER=$(docker run -d -e CASSANDRA_START_RPC=true $IMAGE_NAME)

# Wait for Cassandra to start
sleep 120

# Check if Cassandra is running
if ! docker exec "$CASSANDRA_CONTAINER" nodetool status; then
  echo "Error: Cassandra is not running properly"
  docker logs "$CASSANDRA_CONTAINER"
  docker stop "$CASSANDRA_CONTAINER"
  docker rm "$CASSANDRA_CONTAINER"
  exit 1
fi

# Create a keyspace and table, insert data, and query it
docker exec -i "$CASSANDRA_CONTAINER" cqlsh <<EOF
CREATE KEYSPACE testkeyspace WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
USE testkeyspace;
CREATE TABLE users (user_id UUID PRIMARY KEY, name text);
INSERT INTO users (user_id, name) VALUES (uuid(), 'Chainguard');
SELECT * FROM users;
EOF

# Check if the data was inserted and queried correctly
RESULT=$(docker exec "$CASSANDRA_CONTAINER" cqlsh -e "USE testkeyspace; SELECT * FROM users;")
if [[ "$RESULT" != *"Chainguard"* ]]; then
  echo "Error: Data insertion/query failed"
  docker logs "$CASSANDRA_CONTAINER"
  docker stop "$CASSANDRA_CONTAINER"
  docker rm "$CASSANDRA_CONTAINER"
  exit 1
fi

# Clean up
docker stop "$CASSANDRA_CONTAINER"
docker rm "$CASSANDRA_CONTAINER"

echo "Cassandra functionality test passed!"
