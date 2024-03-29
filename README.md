# Xen Orchestra ARM (Raspberry Pi)

[![](https://img.shields.io/badge/xen--orchestra-master-green.svg)](https://xen-orchestra.com) ![](https://img.shields.io/docker/image-size/lautrecofcarim/alpine-xoa) ![](https://img.shields.io/badge/Alpine%20version-3.18-green.svg) ![](https://img.shields.io/badge/XO%20version-5.85-red.svg)

<img src="http://i.imgur.com/tRffA5y.png" width="150"> <img src="https://i.imgur.com/06fRgbd.png" width="80">

**Note - Sept 2023 - I have found from my more thorough testing that no recent version of XO will run properly on ARM, even if I can build it successfully. I would suggest using either [this](https://hub.docker.com/layers/ronivay/xen-orchestra/5.102.3/images/sha256-6a0452350e8b0be2a549fca604bd4778ebe8961caf08693eb30e42f2ebddbf98?context=explore) build or [this](https://hub.docker.com/layers/ezka77/xen-orchestra-ce/5.100/images/sha256-fbb8af8657efaf18dfeb96ed901ff77bc77b12c42ffa29ee354d73ae0905b8d1?context=explore) build if you want more recent functionality until such time ARM is supported again.**

**Note - Feb 2024 - Containers still don't build on ARM as of early 2024. Those looking to run the latest XO on an ARM device should try Binfmt emulation. I am having success with this using Ronivay's images. Simply run `docker run --privileged --rm tonistiigi/binfmt --install amd64` and update your `docker-compose.yaml` file to include `platform: linux/amd64` on a sufficiently powerful system (I am using a Pi4). Load averages seem very good, it is slightly slower than native but really does work.**

**The only working tag in this repo is _armhf_.**

This is a repository for a dockerized Xen Orchestra. Build using Alpine as a base. 

Currently running XO 5.78.2. 

Built for Raspberry Pi 32bit and 64bit. 

## Getting Started

You can get this immediately using this docker-compose file. This brings up the service on port 8000. For SSL, read on.

```
version: '3'
services:
        xen-orchestra:
                image: lautrecofcarim/alpine-xoa:aarch64latest
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
                     - "6789:6789"
                command: redis-server --appendonly yes
                volumes:
                       - "./xoredisdata:/data"
```

## Tags

`:latest` - Arm 64bit

`:aarch64latest` - Arm 64bit

`:armhf` - Arm 32bit - last working config

`:armlatest` - Arm 32 bit (broken)

## Reverse Proxy HTTPS with NGINX Configuration

I'm personally running this with an Nginx container. A shared container network is **required.** The docker-compose file for Nginx is as follows:

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
networks:
        default:
                external:
                        name: containershare
```

Place your signed certificates in `/etc/nginx/certs`. Refer to them under `/etc/nginx/conf.d/default.conf`, as below. You will need to add IP DNS aliases your DNS server to accomodate. Create the nginx volume folders _before_ starting the container, ideally create the default.conf to some extent (or copy the below). This configuration assumes the certificates have been created and you have a 404 file present under `/ngconf` or `/etc/nginx/conf.d/default.conf/` or it **will not work.**

```
map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
}

server {
        listen 80 default_server;
        server_name _;
        return 301 https://$host$request_uri;
}

server {
        listen 443 ssl default_server;
        server_name _;

        ssl_certificate /etc/nginx/certs/raspiserver/raspiserver.crt;
        ssl_certificate_key /etc/nginx/certs/raspiserver/raspiserverkey.key;

        error_page 404 /better404.html;
        location = /better404.html {
                root /etc/nginx/conf.d;
                internal;
        }
}

server {
        listen 443 ssl;
        server_name xo.your.domain;

        ssl_certificate /etc/nginx/certs/xo/xo.crt;
        ssl_certificate_key /etc/nginx/certs/xo/xo.key;

        ssl_session_cache  builtin:1000  shared:SSL:10m;
        ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
        ssl_prefer_server_ciphers on;

        location / {
        proxy_pass "http://xoa:80/";
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        }
}
```

You can modify your docker-compose file for XO to the following, as mapped host ports aren't required under this configuration.

```
version: '3'
services:
        xen-orchestra:
                image: lautrecofcarim/alpine-xoa:aarch64latest
                restart: always
                container_name: xoa
                user: node
                depends_on:
                     - redis
                environment:
                     - NODE_ENV=production
                volumes:
                     - ./xodata:/var/lib/xo-server/data
        redis:
                container_name: redis
                restart: always
                image: redis:alpine
                command: redis-server --appendonly yes
                volumes:
                       - "./xoredisdata:/data"
networks:
        default:
               external:
                       name: containershare
```

## With Thanks

Project contains aspects of https://github.com/Ezka77/xen-orchestra-ce and https://github.com/interlegis/docker-xo to get a working system.

Help is welcomed and appreciated!
