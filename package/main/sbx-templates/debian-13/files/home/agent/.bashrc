if [ -f /etc/sandbox-persistent.sh ]; then
    . /etc/sandbox-persistent.sh
fi
export BASH_ENV=/etc/sandbox-persistent.sh
case "$TERM" in
    ""|dumb)
        __dhi_set_prompt() {
            local rc=$?
            local mark='+'
            [ "$rc" -eq 0 ] || mark="-:$rc"
            PS1="$mark \u@\h:\w\$ "
        }
        ;;
    *)
        __dhi_set_prompt() {
            local rc=$?
            local mark
            if [ "$rc" -eq 0 ]; then
                mark='\[\e[1;32m\]✓\[\e[0m\]'
            else
                mark="\[\e[1;31m\]✗ $rc\[\e[0m\]"
            fi
            PS1="$mark \[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "
        }
        ;;
esac
PROMPT_COMMAND=__dhi_set_prompt
