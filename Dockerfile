# Pin the base image to a specific PHP version.
# `wordpress:latest` re-resolves on every build and drifts onto EOL PHP (the site was
# running PHP 8.2, which reached end-of-life in Nov 2023). A pinned tag is reproducible
# and stays on supported PHP until we deliberately bump it.
FROM wordpress:7.1.2-php8.4-apache

# ---- Security fix 1/3: bump PHP off EOL (see above) ----

# install the PHP extensions we need
RUN apt-get update \
 && apt-get -y dist-upgrade \
 && apt-get -y install libzip-dev gnupg \
 && docker-php-ext-install zip \
 && rm -rf /var/lib/apt/lists/*   # shrink image / remove package cache

# Install and configure apache cloudflare module
RUN apt-get -y install wget libtool apache2-dev
RUN wget https://raw.githubusercontent.com/cloudflare/mod_cloudflare/master/mod_cloudflare.c -O /tmp/mod_cloudflare.c
RUN apxs2 -a -i -c /tmp/mod_cloudflare.c

# Configure cloudflare
#RUN wget https://www.cloudflare.com/static/misc/mod_cloudflare/debian/mod_cloudflare-jessie-amd64.latest.deb -O /tmp/mod_cloudflare-amd64.latest.deb
#RUN dpkg -x /tmp/mod_cloudflare-amd64.latest.deb /tmp/cloudflare
#RUN cp /tmp/cloudflare/etc/apache2/mods-available/cloudflare.conf /etc/apache2/mods-enabled/cloudflare.conf
#RUN sed -i -e 's/CloudFlareRemoteIPTrustedProxy/CloudFlareRemoteIPTrustedProxy 172.16.0.0/12 192.168.0.0/16 10.0.0.0/8/' /etc/apache2/mods-enabled/cloudflare.conf

RUN echo "LoadModule cloudflare_module  /usr/lib/apache2/modules/mod_cloudflare.so" > /etc/apache2/mods-enabled/cloudflare.load
RUN echo "\
<IfModule mod_cloudflare.c> \n\
    CloudFlareRemoteIPHeader CF-Connecting-IP \n\
    CloudFlareRemoteIPTrustedProxy 172.16.0.0/12 192.168.0.0/16 10.0.0.0/8 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 104.16.0.0/12 108.162.192.0/18 131.0.72.0/22 141.101.64.0/18 162.158.0.0/15 172.64.0.0/13 173.245.48.0/20 188.114.96.0/20 190.93.240.0/20 197.234.240.0/22 198.41.128.0/17 199.27.128.0/21 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 \n\
    #DenyAllButCloudFlare \n\
</IfModule>" > /etc/apache2/mods-enabled/cloudflare.conf
RUN a2enmod cloudflare

# ---- Security fix 2/3: add security headers ----
# WordPress core already emits `X-Frame-Options: SAMEORIGIN`; the container adds the rest.
# These can also be set at the Cloudflare edge (cheaper, and where HSTS is best tuned).
RUN a2enmod headers
RUN printf '%s\n' \
  'Header always set X-Frame-Options "SAMEORIGIN"' \
  'Header always set X-Content-Type-Options "nosniff"' \
  'Header always set Referrer-Policy "strict-origin-when-cross-origin"' \
  'Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"' \
  'Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"' \
  > /etc/apache2/conf-available/security-headers.conf
RUN a2enconf security-headers

# Configure apache to start with one process + one spare server to conserve memory
RUN sed -i -e 's/StartServers.*/StartServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf
RUN sed -i -e 's/MinSpareServers.*/MinSpareServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf
RUN sed -i -e 's/MaxSpareServers.*/MaxSpareServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf


# Enable apache mod_proxy
RUN a2enmod proxy
RUN a2enmod proxy_http

# ---- Security fix 3/3: disable XML-RPC ----
# WordPress enables XML-RPC by default. A content site that doesn't publish via desktop/
# mobile apps doesn't need it; xmlrpc.php is a login brute-force and pingback-DDoS vector.
# This mu-plugin is auto-loaded by WordPress and survives docroot/volume changes.
RUN mkdir -p /usr/src/wordpress/wp-content/mu-plugins
RUN printf '%s\n' '<?php // Disable XML-RPC. add_filter("xmlrpc_enabled", "__return_false");' > /usr/src/wordpress/wp-content/mu-plugins/disable-xmlrpc.php

VOLUME /var/www/html
EXPOSE 80

CMD ["apache2-foreground"]
