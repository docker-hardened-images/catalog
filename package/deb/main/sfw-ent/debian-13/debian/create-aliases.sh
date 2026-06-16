#!/bin/bash
set -euo pipefail

bindir="$1"

create_wrapper() {
  local name="$1"
  local target="$2"
  cat > "${bindir}/${name}" <<EOF
#!/bin/bash

# if DHI_NO_SFW is set to true, run the command without sfw, otherwise run with sfw
if [ "\${DHI_NO_SFW}" = "true" ]; then
  ${target} "\$@"
else
  sfw ${target} "\$@"
fi
EOF
  chmod 0755 "${bindir}/${name}"
}

create_wrapper npm /usr/bin/npm
create_wrapper yarn /usr/bin/yarn
create_wrapper pip /usr/bin/pip3
ln -sf pip "${bindir}/pip3"
create_wrapper cargo /usr/bin/cargo
create_wrapper go /usr/bin/go
