## Synopsis

*wifind* is a simple script for OpenBSD.  It is designed to run from /etc/netstart command.  The script reads the /etc/wifind.conf
file and looks for available SSID's in order of preference.  When one is found it will run the appropiate ifconfig(8) commands
to configure the wireless interface.

## Example

/etc/hostname.wireless
```
! /usr/bin/wifind \$if
```

## License

All sources use the 2 clause BSD license.
See the [LICENSE.md](LICENSE.md) file for details.
