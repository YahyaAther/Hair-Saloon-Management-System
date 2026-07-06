FROM php:8.2-apache

# Install system dependencies needed for SQLite
RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*

# Enable PDO and SQLite extensions
RUN docker-php-ext-install pdo pdo_sqlite

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Fix Apache VirtualHost to allow .htaccess overrides in /var/www/html
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN echo '<Directory /var/www/html>\n\tOptions -Indexes +FollowSymLinks\n\tAllowOverride All\n\tRequire all granted\n</Directory>' \
    >> /etc/apache2/conf-available/docker-php.conf \
    && a2enconf docker-php

# Copy project files
COPY . /var/www/html/

# Remove local Windows binaries from image
RUN rm -rf /var/www/html/mariadb-10.11.7-winx64

# Give www-data write access for SQLite DB file creation
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

EXPOSE 80
CMD ["apache2-foreground"]
