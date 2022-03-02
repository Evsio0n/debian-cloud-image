# auto generated cloud-image for debian 

![](https://git.host.nexet.hk/evsio0n/debian-cloudinit-image/badges/main/pipeline.svg)

## Description

1. Install the base system

```shell
   sudo apt-get install \
   debootstrap \
   qemu-utils \
   qemu-system \
   genisoimage
```

```shell
mkdir $HOME/debian-image
```

2. Create the image

```shell
cd $HOME/debian-image
```

```shell
# Create a loop image at 10G size 
dd if=/dev/zero of=debian-image.img bs=1M count=0 seek=10240 status=progress
```

```shell
# Create a loop device
sudo losetup -f debian-image.img
# Create Partition
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk cloud-ubuntu-image.raw
o # clear the in memory partition table
n # new partition
p # primary partition
1 # partition number 1 
# default - start at beginning of disk
+512M # 512 MB boot parttion
n # new partition
p # primary partition
2 # partion number 2
# default, start immediately after preceding partition
# default, extend partition to end of disk
a # make a partition bootable
1 # bootable partition is partition 1 -- /dev/loop0p1
p # print the in-memory partition table
w # write the partition table
q # and we're done
EOF
```

3. Create the filesystem

```shell
losetup -fP ./debian-image.img
losetup -a
# Format the partition
# Boot
mkfs.ext4 /dev/loop0p1
# Root
mkfs.ext4 /dev/loop0p2
# Make filesystem
mkdir ./chroot
mount /dev/loop0p1 ./chroot
mkdir ./chroot/boot
mount /dev/loop0p2 ./chroot/boot
# Create the chroot
# Get debian release key
wget https://ftp-master.debian.org/keys/release-11.asc -qO- | gpg --import --no-default-keyring --keyring ./debian-release-11.gpg
# Add debian repo
sudo debootstrap  \
    --keyring=./debian-release-11.gpg \
    --arch=amd64  \
    --variant=minbase  \
    --include "ca-certificates,cron,iptables,isc-dhcp-client,libnss-myhostname,ntp,ntpdate,rsyslog,ssh,sudo,dialog,whiptail,man-db,curl,dosfstools,e2fsck-static"
    bullseye  \
    ./chroot  \
    https://mirror.xtom.com.hk/debian/
#mount nodes
sudo mount --bind /dev ./chroot/dev
sudo mount --bind /run ./chroot/run
```

```shell
#enter chroot
sudo chroot ./chroot
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
echo "hostname" > /etc/hostname
```

```shell
#change apt source
cat <<EOF > /etc/apt/sources.list
deb https://mirrors.xtom.com/debian/ stable main contrib non-free
deb-src https://mirrors.xtom.com/debian/ stable main contrib non-free
deb-src https://mirrors.xtom.com/debian/ stable-proposed-updates main contrib non-free
EOF
```

```shell
#configure fstab
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
```

```shell
#install systemd
apt-get install -y systemd-sysv
#create machine-id
dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
#configure divert
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
#configure apt
DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
```

```shell
#configure network
cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF
```

```shell
# Set time zone
echo "Asia/Hong_Kong" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
# Set up locales
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
# Set up resolv.conf using dynamic updates
echo "resolvconf    resolvconf/linkify-resolvconf   boolean true" > /tmp/config.dat
DEBCONF_DB_OVERRIDE='File {/tmp/config.dat}' dpkg-reconfigure -fnoninteractive resolvconf
```

```shell
cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=false
EOF
```

```shell
#setup grub
grub-install --recheck /dev/loop0
update-grub
```

```shell
#clean up
truncate -s 0 /etc/machine-id
dpkg-divert --rename --remove /sbin/initctl
apt-get clean
rm -rf /tmp/* ~/.bash_history
umount -l /proc /sys /dev/pts
export HISTSIZE=0
exit
```

```shell
#umounnt all
umount ./chroot/dev
umount ./chroot/run
umount ./chroot/boot
umount ./chroot
losetup -D
```

3. Create qcow2 image

```shell
qemu-img convert -p -f raw  ./debian-image.img -O qcow2 debian.qcow2

```