# use node:10-slim as the first build layer
FROM node:10-slim as intermediate
RUN echo "Trigger rebuild" > /tmp/rebuild
# copy package.json and package-lock.json from the app root
COPY package*.json /usr/src/app/
# set the app root as the work directory
WORKDIR /usr/src/app

# install git and openssh in the build layer. Git is required to install private npm packages
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list
RUN apt update && apt install -qy git openssh-client python make g++

# SSH private key for the private git repo, passed as a build argument
# https://github.com/moby/moby/issues/6396
ARG GIT_SSH_PRIVATE_KEY
RUN mkdir /root/.ssh/
RUN echo "$GIT_SSH_PRIVATE_KEY" > /root/.ssh/id_rsa
RUN chmod 400 /root/.ssh/id_rsa
RUN echo 'host git.example.com\n\
  StrictHostKeyChecking no\n\
  UserKnownHostsFile=/dev/null\n\
  HostName git.example.com\n\
  IdentityFile /root/.ssh/id_rsa\n\
  User git\n'\
  >> tmp /root/.ssh/config

# accept the git host key
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan -t rsa git.example.com >> /root/.ssh/known_hosts

# install packages
RUN npm install --production
# copy the src directory into the app root
COPY src/ /usr/src/app/src
RUN ln -s /usr/src/app/.payments /root/.payments

# use node:10-slim as the final build layer
FROM node:10-slim
# add bash so wait-for-it.sh can run
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list
RUN apt update && apt install -qy bash mysql-client
# copy the app from the previous image
COPY --from=intermediate /usr/src/app /usr/src/app
# set the app root as the work directory
WORKDIR /usr/src/app
# expose port 3000
EXPOSE 3000
# start the server
CMD [ "npm", "start" ]
