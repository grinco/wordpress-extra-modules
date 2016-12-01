FROM wordpress:latest

# install the PHP extensions we need
RUN apt-get update && apt-get -y dist-upgrade
RUN docker-php-ext-install zip

# Install and configure apache cloudflare module
RUN wget https://www.cloudflare.com/static/misc/mod_cloudflare/debian/mod_cloudflare-jessie-amd64.latest.deb -O /tmp/mod_cloudflare-amd64.latest.deb
RUN dpkg -i /tmp/mod_cloudflare-amd64.latest.deb

# Configure cloudflare
RUN sed -i -e 's/CloudFlareRemoteIPTrustedProxy/CloudFlareRemoteIPTrustedProxy 172.16.0.0\/12 192.168.0.0\/16 10.0.0.0\/8/' /etc/apache2/mods-enabled/cloudflare.conf



VOLUME /var/www/html
EXPOSE 80

CMD ["apache2-foreground"]
