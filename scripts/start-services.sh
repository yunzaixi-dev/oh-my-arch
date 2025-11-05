#!/usr/bin/env bash
set -euo pipefail

# Start OpenSSH server in the background (it daemonizes by default without -D)
/usr/sbin/sshd

PASSWORD_DEFAULT="${CODE_SERVER_PASSWORD:-yun}"

exec runuser -u yun -- env PASSWORD="$PASSWORD_DEFAULT" \
    code-server --bind-addr 0.0.0.0:8080 --auth password
