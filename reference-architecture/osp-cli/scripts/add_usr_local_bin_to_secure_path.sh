#!/bin/sh
sudo sed -i \
  '/secure_path = /s|=.*|= /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin|' \
  /etc/sudoers
