ansible masters,nodes -i inventory -m script -a \
        "/usr/sbin/subscription-manager repos --disable '*'"

ansible masters,nodes -i inventory -m script -a \
        "/usr/sbin/subscription-manager repos
              --enable=rhel-7-server-rpms \
              --enable=rhel-7-server-extras-rpms \
              --enable=rhel-7-server-optional-rpms
"
