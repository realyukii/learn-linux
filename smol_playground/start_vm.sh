#!/usr/bin/env bash

kernel_file="vmlinuz-linux"
rootdisk_file="linux.img"
initrd_file="init.cpio"
opt="$1"

if [ -z ${shared_dir+x} ]; then
	shared_dir="./initramfs/portable"
fi

if [ ! -f "./$kernel_file" ]; then
	rpath=`dirname $0`
	echo "[-] Missing $(realpath $rpath)/$kernel_file file"
	exit
fi

if [ ! -x "./initramfs/bin/busybox" ]; then
	echo "[-] Please install busybox first"
	exit
fi

dirs=(dev portable proc root sys)
for dir in "${dirs[@]}"; do
	mkdir -pv "./initramfs/$dir"
done

kernel_ver=`file -bL ./$kernel_file | sed 's/.*version //;s/ .*//'`
mkdir -pv "./initramfs/lib/modules/$kernel_ver"

if [ "$opt" = "persistent" ]; then
	echo "[+] Running in persistent mode"

	if [ ! -f "./$rootdisk_file" ]; then
		if [ $(id -u) -ne 0 ]; then
			echo "[-] Please run as root to generate and bootstrap the VDI file"
			exit
		fi

		dd if=/dev/zero of="./$rootdisk_file" bs=200M count=1 status=progress
		mkfs.ext4 "./$rootdisk_file"
		tmpdir=$(mktemp -d)
		mount "./$rootdisk_file" "$tmpdir"
		cp -r ./initramfs/* "$tmpdir"
		umount "$tmpdir"
		rm -rf "$tmpdir"
	fi

	qemu-system-x86_64 \
	-drive file="./$rootdisk_file",format=raw,if=virtio \
	-kernel "./$kernel_file" -append "root=/dev/vda init=/init console=ttyS0 rw" \
	-m 2G -nographic -enable-kvm \
	-virtfs local,path="$shared_dir",mount_tag=host0,security_model=passthrough,id=host0
else
	echo "[+] Running in non-persistent mode"

	if [ ! -f "./$initrd_file" ]; then
		echo "[+] generating $initrd_file"
		(cd ./initramfs && find . | cpio -o -H newc -F "../$initrd_file")
	fi

	qemu-system-x86_64 \
	-initrd "./$initrd_file" \
	-kernel "./$kernel_file" -append "root=/ console=ttyS0" \
	-m 2G -nographic -enable-kvm \
	-virtfs local,path="$shared_dir",mount_tag=host0,security_model=passthrough,id=host0
fi
