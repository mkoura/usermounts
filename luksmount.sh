#!/bin/sh

## sudo configuration needed ##
# create new configuration (e.g. 'visudo -f /etc/sudoers.d/luksmount') vith e.g.:
# Cmnd_Alias  CRYPT = /sbin/cryptsetup luksOpen --allow-discards /home/martink/.loop/* _home_martink_.loop_*, /bin/mount -o nodev\,nosuid* /dev/mapper/_home_martink_.loop_* /home/martink/*
# martink   ALL = (root) NOPASSWD: CRYPT

[ "$#" -lt 2 ] && { echo "${0##*/} [crypt_image] [mount_point] <mount_options>" >&2; exit 1; }

# convert '/' to '_'
# e.g. '/home/martink/.loop/config' becomes '_home_martink_.loop_config'
mapper_dev="$(echo $1 | tr '/' '_')"
# the '--allow-discards' option makes sense for SSD and can have
# negative security impact -- see 'man cryptsetup'
sudo -- /sbin/cryptsetup luksOpen --allow-discards $1 $mapper_dev && \
sudo -- /bin/mount -o ${3:-"nodev,nosuid,noatime"} /dev/mapper/${mapper_dev} $2

