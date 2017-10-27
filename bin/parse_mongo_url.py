#!/usr/bin/env python
"""
The output from this script is meant to be eval'd by a shell to parse out MongoDB options
from a connection string.

>>> mongo_url = urlparse.urlparse("mongodb://aptible:foobar@localhost:123/db?ssl=true&x-sslVerify=false")
>>> options = prepare_options(mongo_url)
>>> assert options["host"] == "localhost"
>>> assert options["port"] == 123
>>> assert options["username"] == "aptible"
>>> assert options["password"] == "foobar"
>>> assert "--sslAllowInvalidCertificates" in options["mongo_options"]
>>> assert "--ssl" in options["mongo_options"]

>>> mongo_url = urlparse.urlparse("mongodb://aptible:foobar@localhost:123/db?ssl=true")
>>> options = prepare_options(mongo_url)
>>> assert "--sslAllowInvalidCertificates" not in options["mongo_options"]
>>> assert "--ssl" in options["mongo_options"]
"""

import sys
import urlparse
from pipes import quote # pipes.quote is deprecated in 2.7, if upgrading to 3.x, use shlex.quote


DEFAULT_MONGO_PORT = 27017
SSL_CA_FILE = "/etc/ssl/certs/ca-certificates.crt"


def qs_uses_ssl(qs):
    """
    By default, we don't use SSL. If ?ssl=true is found, we do.
    """
    for ssl_value in qs.get('ssl', []):
        if ssl_value == "true":
            return True
    return False


def qs_checks_ssl(qs):
    """
    By default, we check SSL certificate validity. If ?x-sslVerify=false is found, we don't.
    We prepend x- to the option because it's non-standard in MongoDB connection strings.
    """
    for check_ssl_value in qs.get("x-sslVerify", []):
        if check_ssl_value == "false":
            return False
    return True


def prepare_options(u):
    qs = urlparse.parse_qs(u.query)
    use_ssl = qs_uses_ssl(qs)
    check_ssl = qs_checks_ssl(qs)

    # Prepare our Mongo options
    options = [
        "--host", u.hostname,
        "--port", str(u.port or DEFAULT_MONGO_PORT),
    ]

    for opt, val in zip(["username", "password"], [u.username, u.password]):
        if val:
            options.extend(["--{0}".format(opt), val])

    if use_ssl:
        options.extend(["--ssl", "--sslCAFile", SSL_CA_FILE])
        if not check_ssl:
            options.append("--sslAllowInvalidCertificates")

    return {
        "host": u.hostname,
        "port": u.port,
        "username": u.username,
        "password": u.password,
        "database": u.path.lstrip('/'),
        "mongo_options": options
    }


def sanity_check(u):
    if u.hostname is None:
        print >> sys.stderr, "URL must include hostname"
        sys.exit(1)


def main(mongo_url):
    u = urlparse.urlparse(mongo_url)

    sanity_check(u)

    # And now provide this to the shell
    for k, v in prepare_options(u).items():
        if isinstance(v, list):
            array = "({0})".format(" ".join([quote(o) for o in v]))
            print "{0}={1}".format(k, array)
        else:
            print "{0}={1}".format(k, quote(str(v)))



if __name__ == "__main__":
    main(sys.argv[1])
