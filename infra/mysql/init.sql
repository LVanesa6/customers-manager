CREATE DATABASE IF NOT EXISTS customers_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'customers_user'@'%' IDENTIFIED BY 'customers_pass';
GRANT ALL PRIVILEGES ON customers_db.* TO 'customers_user'@'%';

CREATE USER IF NOT EXISTS 'keycloak'@'%' IDENTIFIED BY 'keycloak_pass';
GRANT ALL PRIVILEGES ON keycloak.* TO 'keycloak'@'%';

FLUSH PRIVILEGES;
