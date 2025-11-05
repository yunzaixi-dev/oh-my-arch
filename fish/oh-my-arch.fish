# fish helper functions for configuring oh-my-arch images

function enable_wheel_passwordless --description 'Allow wheel group to run sudo without password (idempotent)'
    if grep -q '^%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        return 0
    end
    if grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers
        sed -i 's/^%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers; or return $status
    else
        echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers; or return $status
    end
end

function disable_wheel_passwordless --description 'Require sudo password for wheel group (idempotent)'
    if grep -q '^%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers; or return $status
    end
end

function configure_system --description 'Configure hostname, locale, root password, and primary user' -a username password new_hostname
    if test -z "$username"
        echo "Usage: configure_system <username> <password> [hostname]" >&2
        return 1
    end
    if test -z "$password"
        echo "Usage: configure_system <username> <password> [hostname]" >&2
        return 1
    end
    if test -z "$new_hostname"
        set -l config_hostname "$username"
    else
        set -l config_hostname "$new_hostname"
    end
    echo "$config_hostname" > /etc/hostname; or return $status
    if not grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen
        sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; or return $status
    end
    locale-gen; or return $status
    printf "LANG=en_US.UTF-8\n" > /etc/locale.conf; or return $status
    printf "LC_CTYPE=en_US.UTF-8\n" >> /etc/locale.conf; or return $status
    set -l desired_shell "/usr/bin/fish"
    if id -u "$username" >/dev/null 2>&1
        usermod -aG wheel "$username"; or return $status
        set -l passwd_entry (getent passwd "$username")
        if test -n "$passwd_entry"
            set -l current_shell (string split ':' -- $passwd_entry)[7]
            if test "$current_shell" != "$desired_shell"
                chsh -s "$desired_shell" "$username"; or return $status
            end
        end
    else
        useradd -m -G wheel -s "$desired_shell" "$username"; or return $status
    end
    echo "root:$password" | chpasswd; or return $status
    echo "$username:$password" | chpasswd; or return $status
end

function configure_ssh_keys --description 'Install SSH public/private keys for user' -a username public_key_b64 private_key_b64 private_key_filename_b64
    if test -z "$username"
        echo "Usage: configure_ssh_keys <username> <public_key_b64> <private_key_b64> [private_key_filename_b64]" >&2
        return 1
    end
    set -l passwd_entry (getent passwd "$username")
    if test -z "$passwd_entry"
        echo "configure_ssh_keys: user '$username' not found" >&2
        return 1
    end
    set -l home_dir (string split ':' -- $passwd_entry)[6]
    if test -z "$home_dir"
        echo "configure_ssh_keys: unable to determine home directory for '$username'" >&2
        return 1
    end
    set -l ssh_dir "$home_dir/.ssh"
    mkdir -p "$ssh_dir"; or return $status
    chmod 700 "$ssh_dir"; or return $status
    chown "$username":"$username" "$ssh_dir"; or return $status

    if test -n "$public_key_b64"
        printf '%s' "$public_key_b64" | base64 --decode > "$ssh_dir/authorized_keys"; or return $status
        chmod 600 "$ssh_dir/authorized_keys"; or return $status
        chown "$username":"$username" "$ssh_dir/authorized_keys"; or return $status
    end

    if test -n "$private_key_b64"
        set -l key_filename "id_config"
        if test -n "$private_key_filename_b64"
            set key_filename (printf '%s' "$private_key_filename_b64" | base64 --decode | string trim -r --)
            if test -z "$key_filename"
                set key_filename "id_config"
            end
        end
        set -l key_path "$ssh_dir/$key_filename"
        printf '%s' "$private_key_b64" | base64 --decode > "$key_path"; or return $status
        chmod 600 "$key_path"; or return $status
        chown "$username":"$username" "$key_path"; or return $status
    end
end

function apply_config_from_toml --description 'Apply oh-my-arch configuration from TOML' -a config_path default_username
    if test -z "$config_path"
        echo "Usage: apply_config_from_toml <path> [default_username]" >&2
        return 1
    end
    if not test -f "$config_path"
        echo "apply_config_from_toml: config file '$config_path' not found" >&2
        return 1
    end

    set -l parsed (/usr/local/bin/oh-my-arch-parse-config "$config_path")
    if test $status -ne 0
        return $status
    end

    set -l username_b64 ""
    set -l password_b64 ""
    set -l hostname_b64 ""
    set -l public_key_b64 ""
    set -l private_key_b64 ""
    set -l private_key_filename_b64 ""

    for line in $parsed
        set -l pair (string split -m 1 "=" -- $line)
        if test (count $pair) -ne 2
            continue
        end
        set -l key $pair[1]
        set -l value $pair[2]
        switch $key
            case "username_b64"
                set username_b64 $value
            case "password_b64"
                set password_b64 $value
            case "hostname_b64"
                set hostname_b64 $value
            case "public_key_b64"
                set public_key_b64 $value
            case "private_key_b64"
                set private_key_b64 $value
            case "private_key_filename_b64"
                set private_key_filename_b64 $value
            case "toml_parse_error"
                printf '%s\n' (printf '%s' $value | base64 --decode) >&2
                return 1
            case "error"
                printf '%s\n' $value >&2
                return 1
        end
    end

    set -l username (printf '%s' $username_b64 | base64 --decode)
    set -l password (printf '%s' $password_b64 | base64 --decode)
    set -l config_hostname ""
    if test -n "$hostname_b64"
        set config_hostname (printf '%s' $hostname_b64 | base64 --decode)
    end
    if test -z "$config_hostname"
        set config_hostname "$username"
    end

    configure_system "$username" "$password" "$config_hostname"; or return $status
    configure_ssh_keys "$username" "$public_key_b64" "$private_key_b64" "$private_key_filename_b64"; or return $status

    if test -n "$default_username" -a "$default_username" != "$username"
        if id -u "$default_username" >/dev/null 2>&1
            passwd -l "$default_username" >/dev/null; or return $status
        end
    end
end
