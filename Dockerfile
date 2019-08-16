FROM alpine:3.9

LABEL maintainer="Andrew Avdeev <andrewwww.avdeev@gmail.com>"

# Docker Build Arguments
ARG RESTY_VERSION="1.15.8.1"
ARG OPENSSL_VERSION="1.1.1c"
ARG PCRE_VERSION="8.42"
ARG GEOIPUPDATE_VERSION="4.0.3"
ARG MAKE_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-compat \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    --add-dynamic-module=/tmp/ngx_http_geoip2_module \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${OPENSSL_VERSION} --with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre/lib -Wl,-rpath,/usr/local/openresty/pcre/lib' \
    "

LABEL resty_version="${RESTY_VERSION}"
LABEL openssl_version="${OPENSSL_VERSION}"
LABEL pcre_version="${PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"
LABEL resty_config_deps="${_RESTY_CONFIG_DEPS}"

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN apk add --no-cache --virtual .build-deps \
    bash \
    build-base \
    coreutils \
    curl \
    gd-dev \
    geoip-dev \
    git \
    libxslt-dev \
    linux-headers \
    make \
    perl-dev \
    readline-dev \
    zlib-dev

RUN apk add --no-cache \
    gd \
    geoip \
    libgcc \
    libxslt \
    zlib

RUN cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl-${OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && git clone https://github.com/leev/ngx_http_geoip2_module.git \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz -o pcre-${PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre-${PCRE_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/pcre \
        --disable-cpp \
        --enable-jit \
        --enable-utf \
        --enable-unicode-properties \
    && make -j${MAKE_J} \
    && make -j${MAKE_J} install \
    && cd /tmp \
    && mkdir -p /usr/share/GeoIP/ \
    && wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz \
    && tar xzf GeoLite2-City.tar.gz \
    && mv GeoLite2-City_20190813/GeoLite2-City.mmdb /usr/share/GeoIP/ \
    && wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz \
    && tar xzf GeoLite2-Country.tar.gz \
    && mv GeoLite2-Country_20190813/GeoLite2-Country.mmdb /usr/share/GeoIP/ \
    && cd /tmp \
    && wget https://github.com/maxmind/geoipupdate/releases/download/v${GEOIPUPDATE_VERSION}/geoipupdate_${GEOIPUPDATE_VERSION}_linux_amd64.tar.gz \
    && tar zxvf geoipupdate_${GEOIPUPDATE_VERSION}_linux_amd64.tar.gz \
    && cp geoipupdate_${GEOIPUPDATE_VERSION}_linux_amd64/geoipupdate /usr/local/bin \
    && cd /tmp \
    && wget https://github.com/maxmind/libmaxminddb/releases/download/1.3.2/libmaxminddb-1.3.2.tar.gz \
    && tar xzf libmaxminddb-1.3.2.tar.gz \
    && cd libmaxminddb-1.3.2 \
    && ./configure \
    && make \
    && make install \
    && ldconfig /usr/local/lib \
    && cd /tmp \
    && curl -fSL https://github.com/openresty/headers-more-nginx-module/archive/v0.33.tar.gz -o headers-more-nginx-module.tar.gz \
    && tar xzf headers-more-nginx-module.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && if [[ "1.1.1" == $(echo -e "${OPENSSL_VERSION}\n1.1.1" | sort -V | head -n1) ]] ; then \
        echo 'patching Nginx for OpenSSL 1.1.1' \
        && cd bundle/nginx-1.15.8 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/nginx-1.15.8-ssl_cert_cb_yield.patch | patch -p1 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/nginx-1.15.8-ssl_sess_cb_yield.patch | patch -p1 \
        && cd ../.. ; \
    fi \
    && eval ./configure -j${MAKE_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} ${RESTY_LUAJIT_OPTIONS} \
    && make -j${MAKE_J} \
    && make -j${MAKE_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${OPENSSL_VERSION} \
        openssl-${OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${PCRE_VERSION}.tar.gz pcre-${PCRE_VERSION} \
    && apk del .build-deps \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# Copy nginx configuration files
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT
