Role Name
=========

This role stores /var/lib/etcd data on given device (eg. /dev/sdd) creating a specific vg and lv. 

Requirements
------------

none

Role Variables
--------------

Variable naming mimic the docker-storage ones.

`etcd_vol`: the device to use for creating the vg_etcd. Defaults to /dev/sdd.


Dependencies
------------

none

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

        - hosts: localhost
          remote_user: root
          roles:
            - role: etcd-storage
              etcd_dev: /dev/sdd

License
-------

BSD

