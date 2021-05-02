# Xen Orchestra ARM (Raspberry Pi)

[![](https://img.shields.io/badge/xen--orchestra-master-green.svg)](https://xen-orchestra.com) ![](https://img.shields.io/docker/image-size/lautrecofcarim/alpine-xoa) ![](https://img.shields.io/badge/Alpine%20version-3.13-green.svg) ![](https://img.shields.io/badge/XO%20version-5.78.2-red.svg)

<img src="http://i.imgur.com/tRffA5y.png" width="150"> <img src="https://i.imgur.com/06fRgbd.png" width="80">



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

## NGINX Configuration

I'm personally running this with a standalone Nginx container. The docker-compose file is as follows:

```
version: '3'
services:
        nginx:
             image: nginx:latest
             container_name: nginx
             volumes:
                    - ./ngconf:/etc/nginx/conf.d
                    - ./ngcerts:/etc/nginx/certs
             ports:
                    - 80:80
                    - 443:443
```

Place your signed certificates in `/etc/nginx/certs`. Refer to them under `/etc/nginx/conf.d/default.conf`, as below. You will need to modify your DNS to accomodate. 

```
server {
        listen 443 ssl;
        server_name newsslxo.domain.lan;

        ssl_certificate /etc/nginx/certs/xo/xo.crt;
        ssl_certificate_key /etc/nginx/certs/xo/xo.key;

        ssl_session_cache  builtin:1000  shared:SSL:10m;
        ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
        ssl_prefer_server_ciphers on;

        location / {
        proxy_pass "http://originalxoserver.domain.lan:8000/";
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        }
}
```

## With Thanks

Project contains aspects of https://github.com/Ezka77/xen-orchestra-ce and https://github.com/interlegis/docker-xo to get a working system.

Help is welcomed and appreciated!
