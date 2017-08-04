PACKAGES="os-collect-config,python-zaqarclient,os-refresh-config,os-apply-config"

ansible masters,nodes -i inventory -m yum -a "name='$PACKAGES' state=present"
ansible masters,nodes -i inventory -m service -a \
        "name=os-collect-config enabled=yes state=started"
