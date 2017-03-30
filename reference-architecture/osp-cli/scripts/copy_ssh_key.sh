#!/bin/sh
scp -i ./ocp3_rsa  ./ocp3_rsa cloud-user@bastion.ocp3.example.com:.ssh/id_rsa
