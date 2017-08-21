oc new-project demo
oc new-app https://github.com/openshift/ruby-hello-world
oc expose service ruby-hello-world
oc process -n openshift mysql-persistent -v DATABASE_SERVICE_NAME=database | oc create -f -
oc env dc database --list | oc env dc ruby-hello-world -e -
oc get pods
oc get pv

