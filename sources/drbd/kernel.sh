#!/usr/bin

# configure kernel
sudo grubby --set-default /boot/vmlinuz-5.14.0-611.13.1.el9_7.x86_64
sudo reboot
sudo modprobe drbd
lsmod | grep drbd

# tune kernel for performance
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

