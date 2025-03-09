# pull alpine build container
FROM arm64v8/node:alpine3.21 as build

# Install deps
RUN apk add --no-cache \
    build-base \
    python3 \
    libpng-dev \
    ca-certificates \
    git \
    fuse \
    fuse-dev \
    jq

# Pull XO from master
RUN git clone -b master https://github.com/vatesfr/xen-orchestra /etc/xen-orchestra && \
    git clone https://github.com/sagemathinc/fuse-native /etc/fuse-native && \
    git clone https://github.com/fuse-friends/fuse-shared-library-linux-arm /etc/fuse-shared-library-linux

RUN cd /etc/fuse-native && \
    jq '.name = "fuse-native"' package.json | \
    jq '.dependencies["napi-macros"] = "^2.2.2"' > package.temp.json && \
    mv package.temp.json package.json && \
    yarn install --update-checksums --no-lockfile && \
    yarn link

RUN cd /etc/fuse-shared-library-linux && \
    jq '.name = "fuse-shared-library-linux"' package.json > package.temp.json && \
    mv package.temp.json package.json && \
    yarn link

RUN cd /etc/xen-orchestra && \
    jq '.devDependencies["fuse-native"] = "file:/etc/fuse-native"' package.json | \
    jq '.devDependencies["napi-macros"] = "^2.2.2"' package.json | \
    jq '.devDependencies["fuse-shared-library-linux"] = "file:/etc/fuse-shared-library-linux"' > package.temp.json && \
    mv package.temp.json package.json

RUN cd /etc/xen-orchestra/@vates/fuse-vhd && \
    jq '.dependencies["fuse-native"] = "file:/etc/fuse-native"' package.json | \
    jq '.dependencies["napi-macros"] = "^2.2.2"' > package.temp.json && \
    cat package.temp.json && \
    mv package.temp.json package.json && \
    yarn install --update-checksums --no-lockfile && \
    yarn link "fuse-native"

ENV CXXFLAGS="-Wno-implicit-fallthrough"
RUN --mount=type=cache,target=/usr/local/share/.cache cd /etc/xen-orchestra && \
    yarn config set network-timeout 300000 && \
    yarn link "fuse-native" && \
    yarn link "fuse-shared-library-linux"
RUN --mount=type=cache,target=/usr/local/share/.cache cd /etc/xen-orchestra && yarn install --verbose --update-checksums --no-lockfile
RUN cd /etc/xen-orchestra && yarn build

# Install the plugins
RUN find /etc/xen-orchestra/packages/ -maxdepth 1 -mindepth 1 \
    -not -name "xo-server" \
    -not -name "xo-web" \
    -not -name "xo-server-cloud" \
    -not -name "xo-server-test" \
    -not -name "xo-server-test-plugin" \
    -exec ln -s {} /etc/xen-orchestra/packages/xo-server/node_modules \;
    
#LIBVHDI

FROM arm64v8/node:alpine3.21 as build-libvhdi

WORKDIR /home/node

RUN apk add --no-cache git g++ make bash automake autoconf libtool gettext-dev pkgconf fuse-dev fuse fuse3 fuse3-dev

RUN git clone https://github.com/libyal/libvhdi.git

RUN cd libvhdi && ./synclibs.sh && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

##LIBVHDI

FROM arm64v8/node:alpine3.21

MAINTAINER Dusty Armstrong <dusty@dustcloud.dev>
LABEL org.opencontainers.image.source https://github.com/dustyarmstrong/xen-orchestra-arm

# Install XO deps

RUN apk add --no-cache \
    redis \
    python3 \
    py3-jinja2 \
    lvm2 \
    nfs-utils \
    net-tools \
    cifs-utils \
    ca-certificates \
    monit \
    procps \
    curl \
    ntfs-3g

# Install forever for starting/stopping Xen-Orchestra
RUN npm install forever -g

# Copy built xen orchestra from builder
COPY --from=build /etc/xen-orchestra /etc/xen-orchestra
COPY --from=build /usr/local/share/.config /usr/local/share/.config
COPY --from=build /etc/fuse-native /etc/fuse-native
COPY --from=build /etc/fuse-shared-library-linux /etc/fuse-shared-library-linux
COPY --from=build-libvhdi /usr/local/bin/vhdimount /usr/local/bin/vhdiinfo /usr/local/bin/
COPY --from=build-libvhdi /usr/local/lib/libvhdi* /usr/local/lib/
RUN rm -rf /etc/fuse-native/.git /etc/fuse-shared-library-linux/.git

# Logging
RUN ln -sf /proc/1/fd/1 /var/log/redis/redis-server.log && \
    ln -sf /proc/1/fd/1 /var/log/xo-server.log && \
    ln -sf /proc/1/fd/1 /var/log/monit.log

# Healthcheck
ADD healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh
HEALTHCHECK --start-period=1m --interval=30s --timeout=5s --retries=2 CMD /healthcheck.sh

# Copy xo-server configuration template
ADD conf/xo-server.toml.j2 /xo-server.toml.j2

# Copy monit configuration
ADD conf/monit-services /etc/monit/conf.d/services

# Copy startup script
ADD start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /etc/xen-orchestra/packages/xo-server

EXPOSE 80

CMD ["/start.sh"]
