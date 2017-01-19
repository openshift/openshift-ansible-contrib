#!/bin/bash

RESOURCEGROUP=${1}
USERNAME=${2}
SSHPRIVATEDATA=${3}
SSHPUBLICDATA=${4}
SSHPUBLICDATA2=${5}
SSHPUBLICDATA3=${6}

export OSEUSERNAME=$2

ps -ef | grep store.sh > cmdline.out

domain=$(grep search /etc/resolv.conf | awk '{print $2}')

systemctl enable dnsmasq.service
systemctl start dnsmasq.service

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

yum -y update --exclude=WALinuxAgent*
yum -y install targetcli
yum -y install lvm2
systemctl start target
systemctl enable target
systemctl restart target.service
firewall-cmd --permanent --add-port=3260/tcp
firewall-cmd --reload
touch /root/.updateok
pvcreate /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj
parted --script -a optimal /dev/sdc mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdd mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sde mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdf mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdg mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdh mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdi mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
parted --script -a optimal /dev/sdj mklabel gpt mkpart primary xfs 1M 100% set 1 lvm on
pvcreate /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1 /dev/sdh1 /dev/sdi1 /dev/sdj1
vgcreate vg1 /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1 /dev/sdh1 /dev/sdi1 /dev/sdj1
cat << 'EOFZ'  >  /root/ose_pvcreate_lun
#!/bin/bash

# $1 = volumegroup
# $2 = size
# #3 = count

if [[ -z ${stripsize+x} ]]; then
   stripsize=8
   fi

if [ $# -eq 0 ]; then
   echo "pvcreatelun volgroup size count"
   echo "    volgroup is the volgroup as created by vgcreate"
   echo "    size - example 1G"
   echo "    count - Optional - Number of luns to create"
   echo " $OSEUSERNAME should be set to the OpenShift User Name"
   exit 0
   fi
# Call ourselves recursively to do repeats
if [ $# -eq 3 ]; then
   for ((i=0;i < $3;i++))
       do
      ./ose_pvcreate_lun $1 $2
      done
    exit 0
   fi

STOREIP=$(hostname --ip-address)
LUNFILE=~/.oseluncount.cnt
DEVFILE=~/.osedevcount.cnt
TAG=$0

if [ -e ${LUNFILE} ]; then
    count=$(cat ${LUNFILE})
else
    touch "$LUNFILE"
    count=0
fi

if [ -e ${DEVFILE} ]; then
    dcount=$(cat ${DEVFILE})
else
    touch "$DEVFILE"
    dcount=1
   echo ${dcount} > ${DEVFILE}
fi

lunid=${count}
((count++))

echo ${count} > ${LUNFILE}

printf -v padcnt "%03d" $count
export padcnt
export volname="ose${dcount}n${padcnt}x$2"

lvcreate -L $2G -i$stripsize -I64 -n $volname $1 | logger --tag $TAG
mkfs.ext4 -q -F /dev/vg1/$volname 2>&1 | logger --tag $TAG
if [ ${count} -eq 1 ]; then
     echo "Setup device"
     targetcli /iscsi create iqn.2016-02.local.store${dcount}:t1 |  logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/acls create iqn.2016-02.local.azure.nodes | logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/ set attribute authentication=0 | logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/ set parameter DefaultTime2Retain=60 | logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/ set parameter DefaultTime2Wait=12 | logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/ set parameter MaxConnections=10000 | logger --tag $TAG
     targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/ set attribute prod_mode_write_protect=0 | logger --tag $TAG
     targetcli saveconfig
fi

targetcli backstores/block/ create "$volname" /dev/vg1/"$volname" |  logger --tag $TAG
targetcli /iscsi/iqn.2016-02.local.store${dcount}:t1/tpg1/luns create /backstores/block/"$volname" | logger --tag $TAG

targetcli saveconfig | logger --tag $TAG

cat <<EOF > $volname.yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: iscsipv${dcount}x${padcnt}
spec:
  capacity:
    storage: ${2}Gi
  accessModes:
    - ReadWriteOnce
  iscsi:
     targetPortal: $STOREIP
     iqn: iqn.2016-02.local.store${dcount}:t1
     lun: ${lunid}
     fsType: 'ext4'
     readOnly: false

EOF
oc create -f $volname.yml
rm -f $volname.yml
if [ ${count} -eq 100 ]; then
   ((dcount++))
   count=0
   echo ${count} > ${LUNFILE}
   echo ${dcount} > ${DEVFILE}
fi

EOFZ
firewall-cmd --permanent --add-port=3260/tcp
firewall-cmd --reload
chmod +x /root/ose_pvcreate_lun
cd ~

cat << 'EOF' > create_volumes.sh
USERNAME=${1}
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
EOF
chmod +x create_volumes.sh
nohup ./create_volumes.sh ${USERNAME} &> create_volumes.out  &
exit 0
