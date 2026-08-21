#!/bin/bash
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/config.yml:/app/user-data/conf.yml \
  --name my-dashboard \
  --restart=always \
  lissy93/dashy:latest
