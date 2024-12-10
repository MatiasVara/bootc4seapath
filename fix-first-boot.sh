#!/bin/bash
# https://access.redhat.com/solutions/3550072
cd /var
mv run run.old
ln -s ../run
rm -fr /var/run.old
