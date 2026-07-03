FROM php:8.2-apache

# Enable SQLite3 and PDO SQLite
RUN docker-php-ext-install pdo pdo_sqlite

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Allow .htaccess overrides
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Copy project files
COPY . /var/www/html/

# Remove local Windows binaries from the image
RUN rm -rf /var/www/html/mariadb-10.11.7-winx64

# Set permissions — www-data needs write access for SQLite DB creation
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 80
