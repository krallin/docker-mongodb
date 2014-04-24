# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/mongodb

[![Docker Repository on Quay.io](https://quay.io/repository/aptible/mongodb/status)](https://quay.io/repository/aptible/mongodb)

MongoDB on Docker

## Installation and Usage

    docker pull quay.io/aptible/mongodb
    docker run quay.io/aptible/mongodb

### Specifying a password at runtime

    docker run -P quay.io/aptible/mongodb /bin/sh -c "/usr/bin/mongod --dbpath /data/db --fork --syslog && mongo --eval \"db.addUser('username', 'password')\""

## Available Tags

* `latest`: Currently MongoDB 2.6.0

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make release

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com), [Frank Macreery](https://github.com/fancyremarker), and contributors.
