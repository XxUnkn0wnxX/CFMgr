# 🚀 Using CFMgr

[← README](../README.md) · [Compatibility](compatibility.md) · [Development guide](development.md)

![Guide](https://img.shields.io/badge/guide-user_setup-0051c3)

CFMgr's current entry is a read-only development diagnostic. It is not an
installer or feature setup wizard and should not be run on a live router.

From the repository checkout, use:

```sh
./cfmgr.sh --help
./cfmgr.sh --version
./cfmgr.sh --doctor
```

`--diagnostic` is an alias for `--doctor`. These commands require a POSIX shell
and the native tools available on the host. The diagnostic uses a private
temporary scratch directory; it does not install packages, start services, read
saved configuration or contact Cloudflare. See the
[development guide](development.md#native-health-report) for the reported checks
and exit statuses.
