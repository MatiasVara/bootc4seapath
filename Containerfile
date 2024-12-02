FROM quay.io/centos-bootc/centos-bootc:stream9

# this is a workaround for checksum not maching
# RUN rm -rf /var/cache/yum/*

RUN dnf config-manager --set-enabled crb highavailability nfv rt

RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
RUN dnf install -y epel-release centos-release-nfv-openvswitch centos-release-ceph-pacific
RUN dnf install -y linux-firmware microcode_ctl at audispd-plugins audit bridge-utils ca-certificates chrony curl docker-ce docker-ce-cli containerd.io pcp-system-tools gnupg hddtemp irqbalance jq git autoconf automake make figlet firewalld openvswitch2.15

RUN dnf install -y lbzip2 linuxptp net-tools openssh-server edk2-ovmf python3-dnf python3-cffi python3-setuptools 

RUN dnf install -y sudo sysfsutils syslog-ng sysstat 

RUN dnf install -y vim wget rsync pciutils conntrack-tools busybox python-gunicorn ipmitool nginx ntfs-3g python3-flask-wtf corosync pacemaker

RUN dnf install -y qemu-kvm 
RUN ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64

RUN rpm-ostree override remove kernel kernel-{core,modules,modules-core} \
      --install kernel-rt-core --install kernel-rt-modules \
      --install kernel-rt-modules-extra --install kernel-rt-kvm 

RUN dnf install -y ceph ceph-base ceph-common ceph-mgr ceph-mgr-diskprediction-local ceph-mon ceph-osd 

RUN dnf install -y libcephfs2 libvirt libvirt-daemon 

RUN dnf install -y libvirt-daemon-driver-storage-rbd python3-ceph-argparse python3-cephfs tuna

RUN dnf install -y tuned tuned-profiles-nfv tuned-profiles-realtime

RUN dnf install -y virt-install 

# TODO: this may break the installation or not find the rootfs
RUN dnf install -y pcs pcs-snmp

RUN dnf install -y systemd-networkd systemd-resolved systemd-timesyncd
RUN systemctl disable NetworkManager
RUN systemctl enable systemd-networkd
RUN systemctl enable systemd-resolved

# TODO: this may break the installation or not find the rootfs
# RUN dnf install -y net-snmp net-snmp-utils 

RUN systemctl disable corosync 
RUN systemctl disable pacemaker

RUN systemctl enable openvswitch

ADD wheel-passwordless-sudo /etc/sudoers.d/wheel-passwordless-sudo
ARG sshpubkey
ARG adminuser

# create the adminuser, which is used in the inventory too
RUN if test -z "$sshpubkey"; then echo "must provide sshpubkey"; exit 1; fi; \
    useradd -G wheel "$adminuser" && \
    mkdir -m 0700 -p /home/"$adminuser"/.ssh && \
    echo $sshpubkey > /home/"$adminuser"/.ssh/authorized_keys && \
    chmod 0600 /home/"$adminuser"/.ssh/authorized_keys && \
    chown -R "$adminuser": /home/"$adminuser"

# create ansible user
RUN if test -z "$sshpubkey"; then echo "must provide sshpubkey"; exit 1; fi; \
    useradd -G wheel,haclient ansible && \
    mkdir -m 0700 -p /home/ansible/.ssh && \
    echo $sshpubkey > /home/ansible/.ssh/authorized_keys && \
    chmod 0600 /home/ansible/.ssh/authorized_keys && \
    chown -R ansible: /home/ansible

# create Centos-snmp user
RUN if test -z "$sshpubkey"; then echo "must provide sshpubkey"; exit 1; fi; \
    useradd -G wheel Centos-snmp && \
    mkdir -m 0700 -p /home/Centos-snmp/.ssh && \
    echo $sshpubkey > /home/Centos-snmp/.ssh/authorized_keys && \
    chmod 0600 /home/Centos-snmp/.ssh/authorized_keys && \
    chown -R Centos-snmp: /home/Centos-snmp

ARG ipaddr gateaddr dnsaddr chrony_wait_timeout_sec=180 pacemaker_shutdown_timeout=2min

RUN echo -e "\
[Match] \n\
Name=enp1s0 \n\
\n\
[Network] \n\
Address="$ipaddr"/24 \n\
Gateway="$gateaddr" \n\
DNS="$dnsaddr" \
" > /etc/systemd/network/10-enp1s0.network

COPY resolv.conf /etc/resolv.conf
COPY hostname /etc/hostname

# use this instead of using config.toml for kernel parameters
COPY rt.toml /usr/lib/bootc/kargs.d/rt.toml

# generate seapath logo
COPY motd.sh /etc/profile.d/motd.sh

COPY ./ansibleforbootc/roles/debian_physical_machine/templates/consolevm.sh.j2 /usr/local/bin/consolevm
RUN sed -i "s/{{ admin_user }}/"$adminuser"/g" /usr/local/bin/consolevm

COPY ./ansibleforbootc/roles/centos_physical_machine/templates/chrony-wait.service.j2 /etc/systemd/system/chrony-wait.service
RUN sed -i "/^TimeoutStartSec/c\TimeoutStartSec=$chrony_wait_timeout_sec" /etc/systemd/system/chrony-wait.service
RUN systemctl enable chrony-wait

COPY ./ansibleforbootc/roles/centos_physical_machine/templates/pacemaker_override.conf.j2 /etc/systemd/system/pacemaker.service.d/override.conf
RUN sed -i "/^TimeoutStopSec/c\TimeoutStopSec=$pacemaker_shutdown_timeout" /etc/systemd/system/pacemaker.service.d/override.conf
RUN systemctl enable pacemaker.service

RUN mkdir -p /usr/lib/ocf/resource.d/seapath
ADD ./ansibleforbootc/roles/centos_physical_machine/files/pacemaker_ra/ /usr/lib/ocf/resource.d/seapath/

# this is a parameter in the inventary with extra_kernel_modules
COPY extra_modules.conf /etc/modules-load.d/extra_modules.conf

# Add br_netfilter to /etc/modules-load.d
COPY ./ansibleforbootc/roles/centos_physical_machine/files/modules/netfilter.conf /etc/modules-load.d/netfilter.conf

COPY ./ansibleforbootc/roles/centos_physical_machine/initramfs-tools/conf.d/rebooter.conf.j2 /etc/dracut.conf.d/rebooter.conf
#RUN dev="$(findmnt -n -o SOURCE --target /var/log)" \
#    && rel="$(findmnt -n -o TARGET --target /var/log)" \
#    && path="$(realpath --relative-to=$rel /var/log)" \   
# TODO: these values have been hardcoded by using the commands above in a VM
RUN sed -i "s/{{ lvm_rebooter_log_device }}/\/dev\/sdb4[\/ostree\/deploy\/default\/var]/g" /etc/dracut.conf.d/rebooter.conf
RUN sed -i "s/{{ lvm_rebooter_log_path }}/log/g" /etc/dracut.conf.d/rebooter.conf
RUN echo "BUSYBOX=y" >> /etc/dracut.conf
ADD ./ansibleforbootc/roles/centos_physical_machine/initramfs-tools/scripts /etc/initramfs-tools/scripts/

# TODO: this is not working in the bootc container!
# RUN /usr/bin/dracut --regenerate-all --force

# install a custom script that run during first boot and fix issue with firewall-cmd
COPY custom-first-boot.sh /usr/local/sbin/custom-first-boot.sh 
RUN chmod +x /usr/local/sbin/custom-first-boot.sh
COPY post-install.service /usr/lib/systemd/system/post-install.service
RUN systemctl enable post-install

# Synchronization of snmp_scripts
COPY ./ansibleforbootc/src/debian/snmp/virt-df.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/virt-df.sh

# TODO: add chmod +x
# SNMP PASS AGENT script run by net-snmp for seapath tree
COPY ./ansibleforbootc/src/debian/snmp/exposeseapathsnmp.pl /usr/local/bin/exposeseapathsnmp.pl
# name: script run by cron job to generate snmp data
COPY ../ansibleforbootc/src/debian/snmp/snmp_getdata.py /usr/local/sbin/snmp_getdata.py

RUN dnf -y install cronie

# Wait for DHCP for SNMP
RUN sed -i "/^After/c\After=network-online.target" /lib/systemd/system/snmpd.service

# use crmsh 4.6.0
RUN git clone https://github.com/ClusterLabs/crmsh.git /tmp/crmsh && cd /tmp/crmsh && git checkout tags/4.6.0 && ./autogen.sh && ./configure && make && make install && mkdir -p /var/log/crmsh/

# install vm_manager
# this should base on 65c61c2cdf513e4551ab41c436ebfa532a1b8c92
RUN git clone https://github.com/seapath/vm_manager.git /tmp/src/vm_manager && cd /tmp/src/vm_manager && git checkout 65c61c2 && /usr/bin/python3 setup.py install && ln -s /usr/local/bin/vm_manager_cmd.py /usr/local/bin/vm-mgr

# install python-ovs
RUN git clone https://github.com/seapath/python3-setup-ovs.git /tmp/src/python3-setup-ovs && cd /tmp/src/python3-setup-ovs && /usr/bin/python3 setup.py install

RUN systemctl enable docker.service
RUN systemctl enable docker.socket

RUN sed -i -e '/secure_path/ s[=.*[&:/usr/local/bin[' /etc/sudoers
RUN echo "EDITOR=vim" >> /etc/environment && echo "SYSTEMD_EDITOR=vim" >> /etc/environment && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "Defaults:ansible !requiretty" >> /etc/sudoers
RUN echo "ansible    ALL=NOPASSWD:EXEC:SETENV: /bin/sh" >> /etc/sudoers
RUN echo "ansible    ALL=NOPASSWD: /usr/local/bin/crm" >> /etc/sudoers
RUN echo "ansible    ALL=NOPASSWD: /usr/bin/ceph" >> /etc/sudoers

# TODO: to add GRUB_DISABLE_OS_PROBER=true
