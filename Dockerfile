FROM wordpress:latest

# install the PHP extensions we need
RUN apt-get update
RUN apt-get -y dist-upgrade
RUN apt-get -y install libzip-dev gnupg
RUN docker-php-ext-install zip

# Install and configure apache cloudflare module
RUN apt-get -y install wget libtool apache2-dev
RUN wget https://www.cloudflare.com/static/misc/mod_cloudflare/mod_cloudflare.c -O /tmp/mod_cloudflare.c
RUN apxs2 -a -i -c /tmp/mod_cloudflare.c

# Configure cloudflare
RUN wget https://www.cloudflare.com/static/misc/mod_cloudflare/debian/mod_cloudflare-jessie-amd64.latest.deb -O /tmp/mod_cloudflare-amd64.latest.deb
RUN dpkg -x /tmp/mod_cloudflare-amd64.latest.deb /tmp/cloudflare
RUN cp /tmp/cloudflare/etc/apache2/mods-available/cloudflare.conf /etc/apache2/mods-enabled/cloudflare.conf 
RUN sed -i -e 's/CloudFlareRemoteIPTrustedProxy/CloudFlareRemoteIPTrustedProxy 172.16.0.0\/12 192.168.0.0\/16 10.0.0.0\/8/' /etc/apache2/mods-enabled/cloudflare.conf
RUN a2enmod cloudflare

# Configure apache to start with one process + one spare server to conserve memory
RUN sed -i -e 's/StartServers.*/StartServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf
RUN sed -i -e 's/MinSpareServers.*/MinSpareServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf
RUN sed -i -e 's/MaxSpareServers.*/MaxSpareServers\t1/' /etc/apache2/mods-enabled/mpm_prefork.conf


# Enable apache mod_proxy
RUN a2enmod proxy
RUN a2enmod proxy_http

VOLUME /var/www/html
EXPOSE 80

CMD ["apache2-foreground"]
