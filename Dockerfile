FROM wordpress:latest

# install the PHP extensions we need
RUN apt-get update && apt-get -y dist-upgrade
RUN docker-php-ext-install zip

VOLUME /var/www/html
EXPOSE 80

CMD ["apache2-foreground"]
