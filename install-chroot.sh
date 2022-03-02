mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
echo "hostname" > /etc/hostname
echo -------------------
echo "Change disk apt source"
echo -------------------
cat <<EOF > /etc/apt/sources.list
deb https://mirrors.xtom.com/debian/ stable main contrib non-free
deb-src https://mirrors.xtom.com/debian/ stable main contrib non-free
deb-src https://mirrors.xtom.com/debian/ stable-proposed-updates main contrib non-free
EOF
echo -------------------
echo "Configure fstab"
echo -------------------
cat <<EOF > /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system>         <mount point>   <type>  <options>                       <dump>  <pass>
  /dev/sda2               /               ext4    errors=remount-ro               0       1
  /dev/sda1               /boot           ext4    defaults                        0       2
EOF
echo -------------------
echo "Install systemd"
echo -------------------
apt update
apt-get install -y systemd-sysv
echo -------------------
echo "Configure machine-id"
echo -------------------
dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
echo -------------------
echo "Configure divert"
echo -------------------
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
echo -------------------
echo "Configure cloud-init"
echo -------------------
apt-get install -y \
  os-prober \
  ifupdown \
  network-manager \
  resolvconf \
  locales \
  build-essential \
  module-assistant \
  cloud-init \
  grub-pc \
  grub2 \
  console-setup \
  linux-image-amd64
echo -------------------
echo "Configure network"
echo -------------------
cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
      
source /etc/network/interfaces.d/*
      
# The loopback network interface
auto lo
iface lo inet loopback
EOF
echo -------------------
echo "Configure timezone"
echo -------------------
echo "Asia/Hong_Kong" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo -------------------
echo "Configure locale"
echo -------------------
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo -------------------
echo "Configure resolv.conf"
echo -------------------
echo "resolvconf    resolvconf/linkify-resolvconf   boolean true" > /tmp/config.dat
$(DEBCONF_DB_OVERRIDE='File {/tmp/config.dat}' dpkg-reconfigure -fnoninteractive resolvconf)
echo -------------------
echo "Configure networkmanager"
echo -------------------
cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=false
EOF
echo -------------------
echo "Configure grub"
echo -------------------
# shellcheck disable=SC2091
# shellcheck disable=SC2046
$(grub-install --recheck $(cat ./.loopnum))
$(update-grub)
      
echo -------------------
echo "Configure done! Installing custom files"
echo -------------------
exit
echo -------------------
echo "Install custom packages"
echo -------------------
# shellcheck disable=SC2046
apt-get install -y -f -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $(cat ./package.list)
rm ./packages.list
echo -------------------
echo "Installation complete!"
echo -------------------
      
echo -------------------
echo "Cleanup"
echo -------------------
apt-get -y autoremove
truncate -s 0 /etc/machine-id
dpkg-divert --rename --remove /sbin/initctl
apt-get clean
rm -rf /tmp/* ~/.bash_history
umount -l /proc /sys /dev/pts
export HISTSIZE=0
exit 0
