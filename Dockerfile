# builder container
FROM arm64v8/node:23-bookworm as build

# Install set of dependencies to support building Xen Orchestra
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y build-essential python3-minimal libpng-dev ca-certificates git fuse libfuse-dev jq

# Fetch Xen-Orchestra sources from git stable branch
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

# clean any previous install, configure yarn, then install deps
RUN --mount=type=cache,target=/usr/local/share/.cache \
  cd /etc/xen-orchestra && \
  rm -rf node_modules && \
  yarn cache clean --all || true && \
  yarn config set network-timeout 300000 && \
  yarn install --verbose --update-checksums --no-lockfile

# link fuse packages after install (links need node_modules present), then run build
RUN --mount=type=cache,target=/usr/local/share/.cache \
  cd /etc/xen-orchestra && \
  yarn link "fuse-native" && \
  yarn link "fuse-shared-library-linux" && \
  yarn && yarn build

# Install plugins
RUN find /etc/xen-orchestra/packages/ -maxdepth 1 -mindepth 1 \
    -not -name "xo-server" \
    -not -name "xo-web" \
    -not -name "xo-server-cloud" \
    -not -name "xo-server-test" \
    -not -name "xo-server-test-plugin" \
    -exec ln -s {} /etc/xen-orchestra/packages/xo-server/node_modules \;

# Runner container
FROM arm64v8/node:23-bookworm-slim

MAINTAINER Andrei Telteu <andrei@telteu.ro>
LABEL org.opencontainers.image.source https://github.com/andreitelteu/xen-orchestra-docker-arm

# Install set of dependencies for running Xen Orchestra
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y redis-server libvhdi-utils python3-minimal python3-jinja2 lvm2 nfs-common netbase cifs-utils ca-certificates monit procps curl ntfs-3g

# Install forever for starting/stopping Xen-Orchestra
RUN npm install forever -g

# Copy built xen orchestra from builder
COPY --from=build /etc/xen-orchestra /etc/xen-orchestra
COPY --from=build /usr/local/share/.config /usr/local/share/.config
COPY --from=build /etc/fuse-native /etc/fuse-native
COPY --from=build /etc/fuse-shared-library-linux /etc/fuse-shared-library-linux
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
ADD run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /etc/xen-orchestra/packages/xo-server

EXPOSE 80

CMD ["/run.sh"]