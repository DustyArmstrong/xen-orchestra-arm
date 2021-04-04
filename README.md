# Xen Orchestra ARM (Raspberry Pi)

<img src="http://i.imgur.com/tRffA5y.png" width="150"> <img src="https://i.imgur.com/06fRgbd.png" width="100">



This is a repository for a dockerized Xen Orchestra. Build using Alpine as a base. 

Currently running XO 5.78.2. 

Built for Raspberry Pi 32bit and 64bit.

## Getting Started

You can get this immediately using this docker-compose file.

```
version: '3'
services:
        xen-orchestra:
                image: lautrecofcarim/alpine-xoa:latest
                container_name: xoa
                user: node
                ports:
                     - "8000:80"
                depends_on:
                     - redis
                environment:
                     - NODE_ENV=production
                volumes:
                     - "./xodata:/var/lib/xo-server/data"
        redis:
                container_name: redis
                image: redis:alpine
                ports:
                     - "6379:6379"
                command: redis-server --appendonly yes
                volumes:
                       - "./xoredisdata:/data"
```

## Tags

`:latest` - Arm 32bit

`:aarch64` - Arm 64bit

## With thanks

Project contains aspects of https://github.com/Ezka77/xen-orchestra-ce and https://github.com/interlegis/docker-xo to get a working system.
