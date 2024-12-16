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
