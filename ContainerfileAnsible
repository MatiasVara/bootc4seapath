FROM ubuntu:22.04
# version comes from the version that seapath tools require
ENV ANSIBLE_VERSION 2.10.7
RUN apt-get update; \
    apt-get install -y gcc python3 ssh git rsync; \
    apt-get install -y python3-pip; \
    apt-get clean all
RUN pip3 install --upgrade pip; \
    pip3 install "ansible==${ANSIBLE_VERSION}"; \
    pip3 install netaddr; \
    pip3 install six
