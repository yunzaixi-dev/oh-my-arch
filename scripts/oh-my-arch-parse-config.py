#!/usr/bin/env python3

import base64
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("error=Usage: oh-my-arch-parse-config.py <config_path>")
        return 1

    config_path = sys.argv[1]

    try:
        import tomllib  # type: ignore[attr-defined]
    except ModuleNotFoundError as exc:  # pragma: no cover
        msg = base64.b64encode(str(exc).encode()).decode()
        print(f"toml_parse_error={msg}")
        return 1

    try:
        with open(config_path, "rb") as fh:
            data = tomllib.load(fh)
    except Exception as exc:  # noqa: BLE001
        msg = base64.b64encode(str(exc).encode()).decode()
        print(f"toml_parse_error={msg}")
        return 1

    user = data.get("user") or {}
    ssh = data.get("ssh") or {}

    username = user.get("name")
    password = user.get("password")
    hostname = user.get("hostname", "")

    if not username:
        print("error=user.name is required")
        return 1
    if not password:
        print("error=user.password is required")
        return 1

    def encode(value: str | None) -> str:
        if not value:
            return ""
        return base64.b64encode(value.encode("utf-8")).decode("ascii")

    print(f"username_b64={encode(username)}")
    print(f"password_b64={encode(password)}")
    print(f"hostname_b64={encode(hostname)}")
    print(f"public_key_b64={encode(ssh.get('public_key'))}")
    print(f"private_key_b64={encode(ssh.get('private_key'))}")
    print(f"private_key_filename_b64={encode(ssh.get('private_key_filename'))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
