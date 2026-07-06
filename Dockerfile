FROM php:8.2-apache

# Install SQLite system library
RUN apt-get update && apt-get install -y libsqlite3-dev && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_sqlite

# Fix MPM conflict — mod_php requires prefork, disable others
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

# Remove local Windows binaries
RUN rm -rf /var/www/html/mariadb-10.11.7-winx64

# Make startup script executable
RUN chmod +x /var/www/html/start.sh

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && chmod +x /var/www/html/start.sh

EXPOSE 80
CMD ["/var/www/html/start.sh"]
