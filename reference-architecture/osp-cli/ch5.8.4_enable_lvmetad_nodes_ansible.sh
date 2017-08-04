ansible nodes -i inventory -m yum -a "name=lvm2 state=present"
ansible nodes -i inventory -m service -a \
        "name=lvm2-lvmetad enabled=yes state=started"
