unset OS_AUTH_URL OS_USERNAME OS_PASSWORD OS_PROJECT_NAME OS_REGION
# replace the IP address with your RHOSP 10 keystone server IP
export OS_AUTH_URL=http://*10.x.x.100*:5000/v2.0  # <1>
export OS_USERNAME=*ocp3ops* # <2>
export OS_PASSWORD=*password* # <3>
export OS_TENANT_NAME=*ocp3* # <4>
export OS_REGION=default
