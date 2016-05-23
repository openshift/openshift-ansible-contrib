# To use run the following from your system replacing the access and secret with your own
export AWS_ACCESS_KEY=AKIAHFHAS3FSJ
export AWS_SECRET_KEY=5NOPENOPENOPEI6wF

To install using ose-on-aws.py
./ose-on-aws.py --keypair=OSE-key --rhn-user=rhit_rcook --rhn-password=password --public-hosted-zone=rcook-aws.sysdeseng.com

To manually run the install:
ansible-playbook -i inventory/aws/hosts -e 'public_hosted_zone=rcook-aws.sysdeseng.com wildcard_zone=apps.rcook-aws.sysdeseng.com console_port=8443 deployment_type=openshift-enterprise rhn_user=rhit_rcook rhn_password=password registry_volume_size=50 region=us-east-1' playbooks/openshift-install.yaml
