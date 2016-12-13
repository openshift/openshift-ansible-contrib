#!/bin/bash

RESOURCEGROUP=${1}
USERNAME=${2}
SSHPRIVATEDATA=${3}
SSHPUBLICDATA=${4}
SSHPUBLICDATA2=${5}
SSHPUBLICDATA3=${6}

export OSEUSERNAME=$2

ps -ef | grep store.sh > cmdline.out

mkdir -p /home/$USERNAME/.ssh
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3 >  /home/$USERNAME/.ssh/id_rsa.pub
echo $SSHPRIVATEDATA | base64 --d > /home/$USERNAME/.ssh/id_rsa
chown $USERNAME /home/$USERNAME/.ssh/id_rsa.pub
chmod 600 /home/$USERNAME/.ssh/id_rsa.pub
chown $USERNAME /home/$USERNAME/.ssh/id_rsa
chmod 600 /home/$USERNAME/.ssh/id_rsa

mkdir -p /root/.ssh
echo $SSHPRIVATEDATA | base64 --d > /root/.ssh/id_rsa
echo $SSHPUBLICDATA $SSHPUBLICDATA2 $SSHPUBLICDATA3   >  /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa.pub
chown root /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa


yum -y update
yum -y install targetcli
yum -y install lvm2
systemctl start target
systemctl enable target
systemctl restart target.service
firewall-cmd --permanent --add-port=3260/tcp
firewall-cmd --reload
touch /root/.updateok
pvcreate /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj
parted --script -a optimal /dev/sdc mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdd mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sde mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdf mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdg mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdh mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdi mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdj mklabel gpt mkpart primary ext2 1M 100% set 1 lvm on
pvcreate /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1 /dev/sdh1 /dev/sdi1 /dev/sdj1
vgcreate vg1 /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1 /dev/sdh1 /dev/sdi1 /dev/sdj1
cat <<EOF | base64 --decode >  /root/ose_pvcreate_lun
IyEvYmluL2Jhc2gKCiMgJDEgPSB2b2x1bWVncm91cAojICQyID0gc2l6ZQojICMzID0gY291bnQKCmlmIFtbIC16ICR7c3RyaXBzaXplK3h9IF1dOyB0aGVuCiAgIHN0cmlwc2l6ZT04CiAgIGZpCgppZiBbICQjIC1lcSAwIF07IHRoZW4KICAgZWNobyAicHZjcmVhdGVsdW4gdm9sZ3JvdXAgc2l6ZSBjb3VudCIKICAgZWNobyAiICAgIHZvbGdyb3VwIGlzIHRoZSB2b2xncm91cCBhcyBjcmVhdGVkIGJ5IHZnY3JlYXRlIgogICBlY2hvICIgICAgc2l6ZSAtIGV4YW1wbGUgMUciCiAgIGVjaG8gIiAgICBjb3VudCAtIE9wdGlvbmFsIC0gTnVtYmVyIG9mIGx1bnMgdG8gY3JlYXRlIgogICBlY2hvICIgJE9TRVVTRVJOQU1FIHNob3VsZCBiZSBzZXQgdG8gdGhlIE9wZW5zaGlmdCBVc2VyIE5hbWUiCiAgIGV4aXQgMAogICBmaQojIENhbGwgb3Vyc2VsdmVzIHJlY3Vyc2l2ZWx5IHRvIGRvIHJlcGVhdHMKaWYgWyAkIyAtZXEgMyBdOyB0aGVuCiAgIGZvciAoKGk9MDtpIDwgJDM7aSsrKSkKICAgICAgIGRvCiAgICAgIC4vb3NlX3B2Y3JlYXRlX2x1biAkMSAkMgogICAgICBkb25lCiAgICBleGl0IDAKICAgZmkKClNUT1JFSVA9JChob3N0bmFtZSAtLWlwLWFkZHJlc3MpCkxVTkZJTEU9fi8ub3NlbHVuY291bnQuY250CkRFVkZJTEU9fi8ub3NlZGV2Y291bnQuY250ClRBRz0kMAoKaWYgWyAtZSAke0xVTkZJTEV9IF07IHRoZW4KICAgIGNvdW50PSQoY2F0ICR7TFVORklMRX0pCmVsc2UKICAgIHRvdWNoICIkTFVORklMRSIKICAgIGNvdW50PTAKZmkKCmlmIFsgLWUgJHtERVZGSUxFfSBdOyB0aGVuCiAgICBkY291bnQ9JChjYXQgJHtERVZGSUxFfSkKZWxzZQogICAgdG91Y2ggIiRERVZGSUxFIgogICAgZGNvdW50PTEKICAgZWNobyAke2Rjb3VudH0gPiAke0RFVkZJTEV9CmZpCgpsdW5pZD0ke2NvdW50fQooKGNvdW50KyspKQoKZWNobyAke2NvdW50fSA+ICR7TFVORklMRX0KCnByaW50ZiAtdiBwYWRjbnQgIiUwM2QiICRjb3VudApleHBvcnQgcGFkY250CmV4cG9ydCB2b2xuYW1lPSJvc2Uke2Rjb3VudH1uJHtwYWRjbnR9eCQyIgoKbHZjcmVhdGUgLUwgJDJHIC1pJHN0cmlwc2l6ZSAtSTY0IC1uICR2b2xuYW1lICQxIHwgbG9nZ2VyIC0tdGFnICRUQUcKbWtmcy5leHQ0IC1xIC1GIC9kZXYvdmcxLyR2b2xuYW1lIDI+JjEgfCBsb2dnZXIgLS10YWcgJFRBRwppZiBbICR7Y291bnR9IC1lcSAxIF07IHRoZW4KICAgICBlY2hvICJTZXR1cCBkZXZpY2UiCiAgICAgdGFyZ2V0Y2xpIC9pc2NzaSBjcmVhdGUgaXFuLjIwMTYtMDIubG9jYWwuc3RvcmUke2Rjb3VudH06dDEgfCAgbG9nZ2VyIC0tdGFnICRUQUcKICAgICB0YXJnZXRjbGkgL2lzY3NpL2lxbi4yMDE2LTAyLmxvY2FsLnN0b3JlJHtkY291bnR9OnQxL3RwZzEvYWNscyBjcmVhdGUgaXFuLjIwMTYtMDIubG9jYWwuYXp1cmUubm9kZXMgfCBsb2dnZXIgLS10YWcgJFRBRwogICAgIHRhcmdldGNsaSAvaXNjc2kvaXFuLjIwMTYtMDIubG9jYWwuc3RvcmUke2Rjb3VudH06dDEvdHBnMS8gc2V0IGF0dHJpYnV0ZSBhdXRoZW50aWNhdGlvbj0wIHwgbG9nZ2VyIC0tdGFnICRUQUcKICAgICB0YXJnZXRjbGkgL2lzY3NpL2lxbi4yMDE2LTAyLmxvY2FsLnN0b3JlJHtkY291bnR9OnQxL3RwZzEvIHNldCBwYXJhbWV0ZXIgRGVmYXVsdFRpbWUyUmV0YWluPTYwIHwgbG9nZ2VyIC0tdGFnICRUQUcKICAgICB0YXJnZXRjbGkgL2lzY3NpL2lxbi4yMDE2LTAyLmxvY2FsLnN0b3JlJHtkY291bnR9OnQxL3RwZzEvIHNldCBwYXJhbWV0ZXIgRGVmYXVsdFRpbWUyV2FpdD0xMiB8IGxvZ2dlciAtLXRhZyAkVEFHCiAgICAgdGFyZ2V0Y2xpIC9pc2NzaS9pcW4uMjAxNi0wMi5sb2NhbC5zdG9yZSR7ZGNvdW50fTp0MS90cGcxLyBzZXQgcGFyYW1ldGVyIE1heENvbm5lY3Rpb25zPTEwMDAwIHwgbG9nZ2VyIC0tdGFnICRUQUcKICAgICB0YXJnZXRjbGkgL2lzY3NpL2lxbi4yMDE2LTAyLmxvY2FsLnN0b3JlJHtkY291bnR9OnQxL3RwZzEvIHNldCBhdHRyaWJ1dGUgcHJvZF9tb2RlX3dyaXRlX3Byb3RlY3Q9MCB8IGxvZ2dlciAtLXRhZyAkVEFHCiAgICAgdGFyZ2V0Y2xpIHNhdmVjb25maWcKZmkKCnRhcmdldGNsaSBiYWNrc3RvcmVzL2Jsb2NrLyBjcmVhdGUgIiR2b2xuYW1lIiAvZGV2L3ZnMS8iJHZvbG5hbWUiIHwgIGxvZ2dlciAtLXRhZyAkVEFHCnRhcmdldGNsaSAvaXNjc2kvaXFuLjIwMTYtMDIubG9jYWwuc3RvcmUke2Rjb3VudH06dDEvdHBnMS9sdW5zIGNyZWF0ZSAvYmFja3N0b3Jlcy9ibG9jay8iJHZvbG5hbWUiIHwgbG9nZ2VyIC0tdGFnICRUQUcKCnRhcmdldGNsaSBzYXZlY29uZmlnIHwgbG9nZ2VyIC0tdGFnICRUQUcKCmNhdCA8PEVPRiA+ICR2b2xuYW1lLnltbAphcGlWZXJzaW9uOiB2MQpraW5kOiBQZXJzaXN0ZW50Vm9sdW1lCm1ldGFkYXRhOgogIG5hbWU6IGlzY3NpcHYke2Rjb3VudH14JHtwYWRjbnR9CnNwZWM6CiAgY2FwYWNpdHk6CiAgICBzdG9yYWdlOiAkezJ9R2kKICBhY2Nlc3NNb2RlczoKICAgIC0gUmVhZFdyaXRlT25jZQogIGlzY3NpOgogICAgIHRhcmdldFBvcnRhbDogJFNUT1JFSVAKICAgICBpcW46IGlxbi4yMDE2LTAyLmxvY2FsLnN0b3JlJHtkY291bnR9OnQxCiAgICAgbHVuOiAke2x1bmlkfQogICAgIGZzVHlwZTogJ2V4dDQnCiAgICAgcmVhZE9ubHk6IGZhbHNlCgpFT0YKb2MgY3JlYXRlIC1mICR2b2xuYW1lLnltbApybSAtZiAkdm9sbmFtZS55bWwKaWYgWyAke2NvdW50fSAtZXEgMTAwIF07IHRoZW4KICAgKChkY291bnQrKykpCiAgIGNvdW50PTAKICAgZWNobyAke2NvdW50fSA+ICR7TFVORklMRX0KICAgZWNobyAke2Rjb3VudH0gPiAke0RFVkZJTEV9CmZpCgo=
EOF
firewall-cmd --permanent --add-port=3260/tcp
firewall-cmd --reload
chmod +x /root/ose_pvcreate_lun
cd ~
while true
do
  STATUS=$(curl -k -s -o /dev/null -w '%{http_code}' https://master1:8443/api)
  if [ $STATUS -eq 200 ]; then
    echo "Got 200! All done!"
    break
  else
    echo "."
  fi
  sleep 10
done

cd /root
mkdir .kube
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${USERNAME}@master1:~/.kube/config /tmp/kube-config
cp /tmp/kube-config /root/.kube/config
mkdir /home/${USERNAME}/.kube
cp /tmp/kube-config /home/${USERNAME}/.kube/config
chown --recursive ${USERNAME} /home/${USERNAME}/.kube
rm -f /tmp/kube-config
./ose_pvcreate_lun vg1 10 20 
./ose_pvcreate_lun vg1 50 4 
./ose_pvcreate_lun vg1 1 400 
systemctl restart target.service
