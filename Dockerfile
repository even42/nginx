FROM alpine:3.11

LABEL maintainer="Steven Lucol <lucol.steven@gmail.com>"

ENV NGINX_VERSION 1.16.1	
ENV ZLIB_VERSION 1.2.11
ENV PCRE_VERSION 8.44
ENV OPENSSL_VERSION 1.1.1d
ENV NGINX_VTS_MODULE_VERSION 0.1.18

RUN apk update 
#&& apk add ca-certificates wget && update-ca-certificates

#init directory
RUN mkdir -p /usr/src && cd /usr/src

#init group
RUN addgroup -S nginx \
&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

# install libs
RUN apk --no-cache add --virtual .build-deps \
        build-base \
        bash \
        git \
        curl \
        tar \
        perl \
        make \
        musl-dev \
        libtool \
        gzip \
        g++ \
        automake \
        autoconf \
        libtool \
        patch \
        rust \
        cargo \
        pkgconf \
        linux-headers

# install openssl
RUN cd /usr/src && wget http://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz \
&& tar -zxf openssl-$OPENSSL_VERSION.tar.gz -C /tmp \
&& cd /tmp/openssl-$OPENSSL_VERSION \
&& ./config \
&& make \
&&  make install

# install PCRE
RUN cd /usr/src && wget https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VERSION.tar.gz \
&& tar -zxf pcre-$PCRE_VERSION.tar.gz -C /tmp \
&& cd /tmp/pcre-$PCRE_VERSION \
&& ./configure \
&& make \
&& make install

# install zlib
RUN cd /usr/src && wget http://zlib.net/zlib-$ZLIB_VERSION.tar.gz \
&& tar -zxf zlib-$ZLIB_VERSION.tar.gz -C /tmp  \
&& cd /tmp/zlib-$ZLIB_VERSION \
&& ./configure \
&& make \
&& make install

# install nginx modules
RUN curl -fSL https://github.com/vozlt/nginx-module-vts/archive/v$NGINX_VTS_MODULE_VERSION.tar.gz | tar xzf - -C /tmp

#install nginx
RUN cd /tmp && wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && tar zxf nginx-$NGINX_VERSION.tar.gz \
&& cd nginx-$NGINX_VERSION \
&& ./configure \
\
--user=www-data \
--group=www-data \
\
--prefix=/etc/nginx \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib/nginx/modules \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
\
--http-client-body-temp-path=/var/cache/nginx/client_temp \
--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
\
--with-zlib=../zlib-$ZLIB_VERSION \
--with-openssl=../openssl-$OPENSSL_VERSION \
--with-pcre=../pcre-$PCRE_VERSION \
\
--with-pcre-jit \
--with-compat \
--with-file-aio \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_realip_module \
--with-openssl-opt=enable-ec_nistp_64_gcc_128 \
--with-openssl-opt=no-nextprotoneg \
--with-openssl-opt=no-weak-ssl-ciphers \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_auth_request_module \
--with-http_stub_status_module \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_gunzip_module \
--with-http_slice_module \
--with-http_addition_module \
--with-stream \
--with-stream_ssl_module \
--with-debug \
--with-threads \
\
--with-cc-opt='-g -O2 -fPIE -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2' \
--with-ld-opt='-Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now' \
\
--add-module=../nginx-module-vts-$NGINX_VTS_MODULE_VERSION \
&& make -j$(getconf _NPROCESSORS_ONLN) \
&& make \
&& make install \
&& sed -i -e 's/#access_log  logs\/access.log  main;/access_log \/dev\/stdout;/' -e 's/#error_log  logs\/error.log  notice;/error_log stderr notice;/' /etc/nginx/nginx.conf \
&& apk del .build-deps \
&& rm -rf /tmp/*

RUN mkdir -p /etc/nginx/sites-enabled
RUN mkdir -p /etc/nginx/conf.d
RUN mkdir -p /var/cache/nginx
RUN mkdir -p /var/www/html

RUN adduser -H -D www-data
RUN addgroup www-data www-data

ADD nginx.conf /etc/nginx/
#ADD default.conf /etc/nginx/sites-enabled/
ADD metrics.conf /etc/nginx/sites-enabled/

WORKDIR /var/www/html

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]

