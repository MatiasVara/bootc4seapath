#!/bin/bash
# Use $1: nameoftheserver
# $2: ip
# the -r add the image to the podman machine repo
echo "$1" > hostname
sudo podman build --build-arg "sshpubkey=$(cat ~/.ssh/id_rsa.pub)" --build-arg "nameserver=$1" --build-arg "dnsaddr=192.168.124.1" --build-arg "ipaddr=$2" --build-arg "gateaddr=192.168.124.1" --build-arg "adminuser=$3" --build-arg "chrony_wait_timeout_sec=$4" --build-arg "RTCPU_LIST=$5" -t centos-9-for-seapath:latest .
# Check the return value of the previous command
if [ $? -eq 0 ]; then
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--pull=newer \
		--security-opt label=type:unconfined_t \
		-v $(pwd)/config.toml:/config.toml:ro \
		-v $(pwd)/output:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--rootfs ext4 \
		--local \
		localhost/centos-9-for-seapath:latest
	sudo mv ./output/qcow2/disk.qcow2 ./output/qcow2/disk-"$1".qcow2
else
    echo "Command failed with exit status $?."
    exit 1
fi
rm hostname
