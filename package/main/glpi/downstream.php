<?php

/**
 * Filesystem defaults for the packaged GLPI tree.
 *
 * GLPI reads this file after environment variables and config/local_define.php,
 * so either of those still overrides every value here.
 */

if (!defined('GLPI_CONFIG_DIR')) {
    define('GLPI_CONFIG_DIR', '/etc/glpi');
}

if (!defined('GLPI_VAR_DIR')) {
    define('GLPI_VAR_DIR', '/var/lib/glpi');
}

if (!defined('GLPI_MARKETPLACE_DIR')) {
    define('GLPI_MARKETPLACE_DIR', '/var/lib/glpi/marketplace');
}

if (!defined('GLPI_LOG_DIR')) {
    define('GLPI_LOG_DIR', '/var/log/glpi');
}

// Reported by opt-in telemetry and GLPI Network registration; GLPI would
// otherwise claim an upstream TARBALL install.
if (!defined('GLPI_INSTALL_MODE')) {
    define('GLPI_INSTALL_MODE', 'DHI');
}
