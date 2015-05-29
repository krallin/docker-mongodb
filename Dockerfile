FROM quay.io/aptible/debian:wheezy

ENV DATA_DIRECTORY /var/db

# Install latest MongoDB from custom package repo
ADD templates/mongodb.list /etc/apt/sources.list.d/mongodb.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10 && \
    apt-get update && apt-get install -y adduser mongodb-org && mkdir -p "$DATA_DIRECTORY"

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["$DATA_DIRECTORY"]
EXPOSE 27017

ADD run-database.sh /usr/bin/
ADD utilities.sh /usr/bin/
ENTRYPOINT ["run-database.sh"]
