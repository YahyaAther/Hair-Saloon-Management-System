FROM php:8.2-apache

# Install SQLite system library
RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_sqlite

# Fix MPM conflict — mod_php requires prefork
RUN a2dismod mpm_event mpm_worker 2>/dev/null || true \
    && a2enmod mpm_prefork

# Enable mod_rewrite
RUN a2enmod rewrite

# Fix AllowOverride so .htaccess works
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Add Directory block for /var/www/html
RUN { \
    echo '<Directory /var/www/html>'; \
    echo '  Options -Indexes +FollowSymLinks'; \
    echo '  AllowOverride All'; \
    echo '  Require all granted'; \
    echo '</Directory>'; \
    } > /etc/apache2/conf-available/site.conf \
    && a2enconf site

# Copy project files
COPY . /var/www/html/

# Remove local Windows files and old start script (not needed inside container)
RUN rm -rf /var/www/html/mariadb-10.11.7-winx64 /var/www/html/start.bat /var/www/html/start.sh

# Create the startup script INSIDE Docker (avoids Windows CRLF line-ending crash)
RUN printf '#!/bin/sh\n\
set -e\n\
PORT=${PORT:-80}\n\
sed -i "s/Listen 80/Listen $PORT/g" /etc/apache2/ports.conf\n\
sed -i "s/:80>/:$PORT>/g" /etc/apache2/sites-available/000-default.conf\n\
exec apache2-foreground\n' > /start.sh \
    && chmod +x /start.sh

# Permissions — web root writable so SQLite DB can be created at runtime
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

EXPOSE 80
CMD ["/start.sh"]
