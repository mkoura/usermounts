usermounts.sh
=============

Can be used to mount encrypted devices or directories by user.
If multiple devices have the same password, it is necessary to enter the password only once.

Can be used to mount e.g. `encfs` or `luks` (see `luksmount.sh`) encrypted devices.


Configuration:
- see `usermounts.conf.example` - move the modified copy to `~/.config/usermounts/usermounts.conf`
- `luksmount.sh` requires sudo configuration - see comments in the file


Workflow:
- create "startup programs" entry for your desktop environment or window manager to have it started after you log in; or
- add `usermounts.sh` to `~/.xsessionrc` to have it started even _before_ your desktop or window manager (useful if you have some config files encrypted)
- start it manually if you need to mount encrypted device present on removable device that you've just connected
