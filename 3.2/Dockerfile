FROM quay.io/aptible/debian:wheezy

ENV MONGO_VERSION 3.2.1

# Install latest MongoDB from custom package repo
ADD templates/mongodb.list /etc/apt/sources.list.d/mongodb.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv EA312927 && \
    apt-install adduser procps ca-certificates python \
      mongodb-org=$MONGO_VERSION mongodb-org-server=$MONGO_VERSION \
      mongodb-org-shell=$MONGO_VERSION mongodb-org-mongos=$MONGO_VERSION \
      mongodb-org-tools=$MONGO_VERSION

ENV MONGO_SSL_MODE requireSSL
ENV DATA_DIRECTORY /var/db
ENV SSL_DIRECTORY /etc/ssl/mongo
RUN mkdir -p "${DATA_DIRECTORY}" "${SSL_DIRECTORY}"

ADD run-database.sh /usr/bin/
ADD parse_mongo_url.py /usr/bin/
ADD utilities.sh /usr/bin/

# Integration tests
ADD test /tmp/test
RUN bats /tmp/test

VOLUME ["$DATA_DIRECTORY"]
VOLUME ["$SSL_DIRECTORY"]
EXPOSE 27017

ENTRYPOINT ["run-database.sh"]
