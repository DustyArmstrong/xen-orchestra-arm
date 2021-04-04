#!/bin/sh

cd /home/node/xen-orchestra/packages/xo-server

# storage directory and fix perms
mkdir -p /var/lib/xo-server/data 
chown -R ${USER}:${USER} /var/lib/xo-server/data

# Start Xen Orchestra
echo "Starting Xen Orchestra..."
cd /home/node/xen-orchestra/packages/xo-server && exec yarn start
