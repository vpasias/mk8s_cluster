#!/bin/bash
#
HOME=/mnt/extra/

cat > /mnt/extra/management.xml <<EOF
<network>
  <name>management</name>
  <forward mode='nat'/>
  <bridge name='virbr100' stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:8a:8b:8c'/>
  <ip address='172.16.0.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='172.16.0.199' end='172.16.0.254'/>
      <host mac='52:54:00:8a:8b:c0' name='n0' ip='172.16.0.100'/>
      <host mac='52:54:00:8a:8b:c1' name='n1' ip='172.16.0.101'/>
      <host mac='52:54:00:8a:8b:c2' name='n2' ip='172.16.0.102'/>
      <host mac='52:54:00:8a:8b:c3' name='n3' ip='172.16.0.103'/>
      <host mac='52:54:00:8a:8b:c4' name='n4' ip='172.16.0.104'/>
      <host mac='52:54:00:8a:8b:c5' name='n5' ip='172.16.0.105'/>
      <host mac='52:54:00:8a:8b:c6' name='n6' ip='172.16.0.106'/>
      <host mac='52:54:00:8a:8b:c7' name='n7' ip='172.16.0.107'/>
      <host mac='52:54:00:8a:8b:c8' name='n8' ip='172.16.0.108'/>
      <host mac='52:54:00:8a:8b:c9' name='n9' ip='172.16.0.109'/>
    </dhcp>
  </ip>
</network>
EOF

cat > /mnt/extra/cluster.xml <<EOF
<network>
  <name>cluster</name>
  <bridge name="virbr101" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:97:98:99'/>
  <ip address='172.16.1.1' netmask='255.255.255.0'/>
</network>
EOF

cat > /mnt/extra/service.xml <<EOF
<network>
  <name>service</name>
  <bridge name="virbr102" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:9a:9b:9c'/>
  <ip address='172.16.2.1' netmask='255.255.255.0'/>
</network>
EOF

virsh net-define /mnt/extra/management.xml && virsh net-autostart management && virsh net-start management
virsh net-define /mnt/extra/cluster.xml && virsh net-autostart cluster && virsh net-start cluster
virsh net-define /mnt/extra/service.xml && virsh net-autostart service && virsh net-start service

ip a && sudo virsh net-list --all

sleep 20

# Node 1
./kvm-install-vm create -c 8 -m 32768 -d 200 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c1 n1

# Node 2
./kvm-install-vm create -c 8 -m 32768 -d 200 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c2 n2

# Node 3
./kvm-install-vm create -c 8 -m 32768 -d 200 -t ubuntu2204 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c3 n3

sleep 60

virsh list --all && brctl show && virsh net-list --all

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "root:gprm8350" | sudo chpasswd'; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "ubuntu:kyax7344" | sudo chpasswd'; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo systemctl restart sshd"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo rm -rf /root/.ssh/authorized_keys"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo hostnamectl set-hostname n$i.example.com --static"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y && sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod -x /etc/update-motd.d/*"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'cat << EOF | sudo tee /etc/update-motd.d/01-custom
#!/bin/sh
echo "****************************WARNING****************************************
UNAUTHORISED ACCESS IS PROHIBITED. VIOLATORS WILL BE PROSECUTED.
*********************************************************************************"
EOF'; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod +x /etc/update-motd.d/01-custom"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/modprobe.d/qemu-system-x86.conf
options kvm_intel nested=1
EOF"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo mkdir -p /etc/systemd/system/networking.service.d"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/systemd/system/networking.service.d/reduce-timeout.conf
[Service]
TimeoutStartSec=15
EOF"; done

for i in {1..3}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..3}; do virsh start n$i; done && sleep 10 && virsh list --all

sleep 30

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y"; done

for i in {1..3}; do qemu-img create -f qcow2 vbdnode1$i 200G; done
#for i in {1..3}; do qemu-img create -f qcow2 vbdnode2$i 200G; done
#for i in {1..3}; do qemu-img create -f qcow2 vbdnode3$i 200G; done

for i in {1..3}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode1$i.qcow2 -t vdb n$i; done
#for i in {1..3}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode2$i.qcow2 -t vdc n$i; done
#for i in {1..3}; do ./kvm-install-vm attach-disk -d 200 -s /mnt/extra/kvm-install-vm/vbdnode3$i.qcow2 -t vdd n$i; done

for i in {1..3}; do virsh attach-interface --domain n$i --type network --source cluster --model virtio --mac 02:00:aa:0a:01:1$i --config --live; done
for i in {1..3}; do virsh attach-interface --domain n$i --type network --source service --model virtio --mac 02:00:aa:0a:02:1$i --config --live; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/hosts
127.0.0.1 localhost
172.16.0.100  n0.example.com
172.16.0.101  n1.example.com
172.16.0.102  n2.example.com
172.16.0.103  n3.example.com
172.16.0.104  n4.example.com
172.16.0.105  n5.example.com
172.16.0.106  n6.example.com
172.16.0.107  n7.example.com
172.16.0.108  n8.example.com
172.16.0.109  n9.example.com
# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF"; done

ssh -o "StrictHostKeyChecking=no" ubuntu@n1 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.0.101/24
      routes:
        - to: default
          via: 172.16.0.1
          metric: 100
          on-link: true
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.101/24
    enp9s0:
      dhcp4: false
      dhcp6: false
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n2 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.0.102/24
      routes:
        - to: default
          via: 172.16.0.1
          metric: 100
          on-link: true
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.102/24
    enp9s0:
      dhcp4: false
      dhcp6: false
EOF"

ssh -o "StrictHostKeyChecking=no" ubuntu@n3 "cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.0.103/24
      routes:
        - to: default
          via: 172.16.0.1
          metric: 100
          on-link: true
    enp8s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 172.16.1.103/24
    enp9s0:
      dhcp4: false
      dhcp6: false
EOF"

for i in {1..3}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..3}; do virsh start n$i; done && sleep 10 && virsh list --all
