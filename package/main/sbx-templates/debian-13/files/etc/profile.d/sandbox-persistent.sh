if [ -f /etc/sandbox-persistent.sh ]; then
    . /etc/sandbox-persistent.sh
fi
export BASH_ENV=/etc/sandbox-persistent.sh
