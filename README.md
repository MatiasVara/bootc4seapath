## Abstract

We present a proof-of-concept (POC) that simplifies the deployment of a SEAPATH cluster by leveraging bootc.

## Introduction

The Bootc4Seapath POC uses podman-bootc and qemu-kvm to build the necessary images and virtual machines (VMs). The process involves generating images from the Containerfile and storing them in an output directory. These images are then tested using three VMs that represent a SEAPATH cluster.

## Limitations
This is a PoC that must not be used in production. For example, in this PoC, the ring is not configured and only the public network is used. Also, the git submodules rely on specific commits.

## Requirements

To use Bootc4Seapath, you will need:

* A host with podman-bootc for building images
* qemu-kvm for creating VMs

The following instructions allow you to build and deploy three VMs that represent the SEAPATH cluster and then create a nested VM that is hosted by the cluster.

## Instructions

1. Clone the repository and navigate to its directory.
```bash
git clone https://github.com/MatiasVara/bootc4seapath && cd ./bootc4seapath
```
2. Pull the Ansible submodule.
```bash
git submodule init && git submodule update
```
3. Build images for each host and store them in the `./output` directory.
```bash
mkdir ./output && ./build.sh
```
4. Build a container for Ansible, run it, and prepare the environment.
```bash
./build_img_for_ansible.sh && ./run_in_container.sh
```
In the container, navigate to `/root/bootc4seapath/ansible` and run `prepare.sh`.

5. Configure VMs using the Ansible playbook for SEAPATH. Set up an inventory first, and ensure that VMs with previously generated disk images are running and accessible.
```bash
./seapath_setup_main.sh
```
6. Create a test VM by uncommenting test VM parameters in the inventory.

7. Create a `test.qcow2` and `test.xml` files in the ansible directory. The former is the disk image and the latter is the xml description of the VM and run `./deploy_vm.sh`. Note that `test.xml` must not contain the disk section.

8. Verify that the nested VM is running in the hypervisor1 host using `sudo vm-mgr status --name test`.

# Deploy on baremetal host
This section explains how to install the bootc image in a baremetal host. We use the image that is pushed in a register together with a kickstart file and a livecd to generate an iso ready to install the image. The steps are:

0. Push image to a quay repository:
```bash
podman login quay.io
podman push centos-test:latest quay.io/myuser/centos-test
```
1. If you use a private repository, you need to setup the credentials. To get the credential for quay, you can go to user settings and then click on `Generate Encrypted Password`, you have to go to the `Docker Configuration` option and get the `json`.

2. Create a kickstart file:
```bash
# Basic setup
# text
network --bootproto=dhcp --device=link --activate
# Basic partitioning
text --non-interactive
ignoredisk --only-use=/dev/sda
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs
%pre
mkdir -p /etc/ostree
# get this from quay.io interface
cat > /etc/ostree/auth.json << 'EOF'
{
  "auths": {
    "quay.io": {
      "auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "email": ""
    }
  }
}
EOF
%end
# Reference the container image to install - The kickstart
# has no %packages section. A container image is being installed.
# TODO: setup the correct image
ostreecontainer --url quay.io/toto/centos-for-seapath:latest
# Only inject a SSH key for root
rootpw --iscrypted locked
sshkey --username root "ssh-key-here"
firewall --disabled
services --enabled=sshd
reboot
```
3. Create an iso by using the kickstart file and a rhel livecd:
```bash
mkksiso --debug --ks kickstartfile rhel-9.5-x86_64-boot.iso seapath.iso
```

Done! you can use the iso to setup your hosts.
