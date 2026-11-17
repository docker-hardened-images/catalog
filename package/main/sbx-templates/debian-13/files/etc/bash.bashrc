if [ -f /etc/sandbox-persistent.sh ]; then
    . /etc/sandbox-persistent.sh
fi
export BASH_ENV=/etc/sandbox-persistent.sh
if [ -f /etc/profile.d/01-dhi.sh ]; then
    . /etc/profile.d/01-dhi.sh
fi
