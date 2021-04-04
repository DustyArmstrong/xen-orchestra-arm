FROM node:current-alpine3.13 as build
MAINTAINER Dusty

WORKDIR /home/node

RUN apk update && apk upgrade && \
    apk add --no-cache bash git build-base libstdc++ gcc yarn libpng-dev python2 g++ make libc6-compat curl

RUN npm install url-loader --save-dev

RUN git clone -b master --depth 1 http://github.com/vatesfr/xen-orchestra

COPY patches /home/node/xen-orchestra/patches

RUN cd /home/node/xen-orchestra \
    && git apply patches/gh_issue_redirect.diff \
    && rm -rf /home/node/xen-orchestra.git /home/node/xen-orchestra/patches
    
RUN cd /home/node/xen-orchestra && yarn config set network-timeout 30000000 && yarn && yarn build

COPY link_plugins.sh /home/node/xen-orchestra/packages/xo-server/link_plugins.sh
RUN chmod +x /home/node/xen-orchestra/packages/xo-server/link_plugins.sh && \
    /home/node/xen-orchestra/packages/xo-server/link_plugins.sh


#LIBVHDI
FROM node:current-alpine3.13 as build-libvhdi

WORKDIR /home/node

RUN apk add --no-cache git g++ make bash automake autoconf libtool gettext-dev pkgconf fuse-dev fuse

RUN git clone https://github.com/libyal/libvhdi.git

RUN cd libvhdi && ./synclibs.sh && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

##LIBVHDI

FROM node:current-alpine3.13

LABEL xo-server=5.7 xo-web=5.7

ENV USER=node USER_HOME=/home/node XOA_PLAN=5 DEBUG=xo:main

RUN mkdir -p /home/node

WORKDIR /home/node

RUN apk add --no-cache \
    su-exec \
    bash \
    util-linux \
    nfs-utils \
    lvm2 \
    fuse \
    gettext \
    cifs-utils \
    openssl

COPY --from=build /home/node/xen-orchestra /home/node/xen-orchestra
COPY --from=build /usr/local/bin/node /usr/bin/
COPY --from=build /usr/lib/libgcc* /usr/lib/libstdc* /usr/lib/

COPY --from=build-libvhdi /usr/local/bin/vhdimount /usr/local/bin/vhdiinfo /usr/local/bin/
COPY --from=build-libvhdi /usr/local/lib/libvhdi* /usr/local/lib/

COPY xo-server.config.yaml /home/node/xen-orchestra/packages/xo-server/.xo-server.yaml

ENV REDIS_SERVER="redis" \
    REDIS_PORT="6379"

EXPOSE 80

ADD start.sh /usr/local/bin/start.sh
RUN chmod a+x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
