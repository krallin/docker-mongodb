FROM quay.io/aptible/ubuntu:12.04

# Install latest MongoDB from custom package repo
ADD templates/mongodb.list /etc/apt/sources.list.d/mongodb.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10 && \
    apt-get update && apt-get install -y mongodb-org && mkdir -p /data/db

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["/var/lib/postgresql"]
EXPOSE 27017

CMD ["/usr/bin/mongod --dbpath /data/db --auth"]
