#!/bin/bash
# Runs the services upstream's supervisord runs: the web server (nginx and
# php-fpm here) and /opt/glpi/cron-worker.sh. The container stops when any of
# them exits.
set -u -o pipefail

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: GLPI does not run as root. Start the container with --user 65532:65532." >&2
    exit 1
fi

# Each service gets its own process group, so the cron worker's scheduler
# loop and its children stop with it.
set -m

stopping=0
pids=()

stop() {
    stopping=1
    trap '' TERM INT QUIT
    # SIGQUIT is the graceful stop signal of both php-fpm and nginx.
    [ -n "${nginx_pid:-}" ] && kill -QUIT "$nginx_pid" 2>/dev/null
    [ -n "${fpm_pid:-}" ] && kill -QUIT "$fpm_pid" 2>/dev/null
    [ -n "${cron_pid:-}" ] && kill -TERM -- "-$cron_pid" 2>/dev/null
    return 0
}
trap stop TERM INT QUIT

/usr/sbin/php-fpm -F -y /etc/php-8.5/php-fpm.conf &
fpm_pid=$!
pids+=("$fpm_pid")

i=0
until [ -S /run/php/php-fpm.sock ]; do
    if ! kill -0 "$fpm_pid" 2>/dev/null; then
        wait "$fpm_pid"
        echo "ERROR: php-fpm exited before it opened its socket." >&2
        exit 1
    fi
    i=$((i + 1))
    if [ "$i" -gt 100 ]; then
        echo "ERROR: php-fpm did not open /run/php/php-fpm.sock within 10 seconds." >&2
        stop
        wait "${pids[@]}" 2>/dev/null
        exit 1
    fi
    sleep 0.1
done

/usr/sbin/nginx -e stderr -g 'daemon off;' &
nginx_pid=$!
pids+=("$nginx_pid")

/opt/glpi/cron-worker.sh &
cron_pid=$!
pids+=("$cron_pid")

status=0
while :; do
    exited=
    wait -n -p exited "${pids[@]}"
    rc=$?
    if [ "$stopping" -eq 1 ]; then
        break
    fi
    if [ -n "${exited:-}" ]; then
        case "$exited" in
            "$fpm_pid") name=php-fpm ;;
            "$nginx_pid") name=nginx ;;
            *) name=cron-worker ;;
        esac
        echo "ERROR: $name exited with status $rc; stopping the container." >&2
        status=1
        stop
        break
    fi
done

# The log forwarders the entrypoint started are not waited for; they end with
# PID 1.
wait "${pids[@]}" 2>/dev/null
exit "$status"
