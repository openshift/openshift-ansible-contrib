ansible nodes -i inventory -m yum -a "name=docker state=present"
cat <<EOF >docker-storage-setup
DEVS=/dev/vdb
VG=docker-vg
EOF
ansible app-nodes,infra-nodes -i inventory -m copy -a "src=docker-storage-setup dest=/etc/sysconfig/docker-storage-setup force=yes"
ansible nodes -i inventory -a "/usr/bin/docker-storage-setup"
ansible nodes -i inventory -m service -a "name=docker enabled=yes state=started"
