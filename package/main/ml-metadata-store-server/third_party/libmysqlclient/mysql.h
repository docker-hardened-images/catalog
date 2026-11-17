/* MLMD includes "mysql.h"; Debian installs it under mariadb/, Alpine under mysql/. */
#if __has_include(<mariadb/mysql.h>)
#include <mariadb/mysql.h>
#else
#include <mysql/mysql.h>
#endif
