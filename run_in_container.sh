# share local keys
podman run --privileged --rm --mount type=bind,source="$(pwd)",target=/root/ansible/ --mount type=bind,source=/home/mvaralar/.ssh/,target=/root/.ssh/ -it ubuntu4seapath
