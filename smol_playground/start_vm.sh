#!/usr/bin/env bash

kernel_file="vmlinuz-linux"
boot_file="boot.img"
initrd_file="init.cpio"

if [ -z ${shared_dir+x} ]; then
	shared_dir="./initramfs/portable"
fi

if [ ! -f "./$kernel_file" ]; then
	rpath=`dirname $0`
	echo "[-] Missing $(realpath $rpath)/$kernel_file file"
	exit
fi

if [ ! -d "./initramfs/bin/" ]; then
	echo "[-] Please install busybox first"
	exit
fi

if [ ! -f "./$boot_file" ]; then
	dd if=/dev/zero of="./$boot_file" bs=200K count=1 status=progress
	mkfs -t fat "./$boot_file"
	syslinux -i "./$boot_file"
fi

dirs=(dev portable proc root sys)
for dir in "${dirs[@]}"; do
    mkdir -pv "./initramfs/$dir"
done

kernel_ver=`file -bL ./$kernel_file | sed 's/.*version //;s/ .*//'`
mkdir -pv "./initramfs/lib/modules/$kernel_ver"
mkdir -pv ./initramfs/usr/{share/empty.sshd,lib/ssh}

if [ ! -f "./$initrd_file" ]; then
	echo "[+] generating $initrd_file"
	(cd ./initramfs && find . | cpio -o -H newc -F "../$initrd_file")
fi

qemu-system-x86_64 \
	-drive format=raw,file="./$boot_file" \
	-initrd "./$initrd_file" \
	-kernel "./$kernel_file" -append "root=/ console=ttyS0" \
	-m 2G -nographic -enable-kvm \
	-virtfs local,path="$shared_dir",mount_tag=host0,security_model=passthrough,id=host0

