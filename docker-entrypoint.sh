#!/bin/sh
set -e

chown -R 1000:1000 /app 2>/dev/null || true
chmod -R u+rwX,g+rwX,o+rX /app 2>/dev/null || true

exec /opt/docker/bin/entrypoint.sh "$@"
