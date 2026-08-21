FROM mirror.gcr.io/node
RUN npm install -g newman
COPY . . 
RUN newman run -e test.postman_environment.json flow.postman_collection.json
