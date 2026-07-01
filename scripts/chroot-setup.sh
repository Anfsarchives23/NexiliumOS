#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "nexiliumos" > /etc/hostname

cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   nexiliumos
HOSTS

apt-get update

echo "==> Instalando base + live system..."
apt-get install -y \
    sudo curl wget git nano \
    network-manager \
    linux-image-amd64 \
    live-boot \
    live-boot-initramfs-tools \
    live-config \
    live-config-systemd \
    systemd-sysv \
    dbus

echo "==> Instalando MATE Desktop..."
apt-get install -y \
    mate-desktop-environment \
    lightdm \
    lightdm-gtk-greeter \
    slick-greeter \
    mate-terminal \
    caja \
    marco \
    firefox-esr

echo "==> Configurando LightDM..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-nexilium-greeter.conf << 'GREETER'
[Seat:*]
greeter-session=slick-greeter
GREETER

cat > /etc/lightdm/slick-greeter.conf << 'SLICK'
[Greeter]
background=#1a1a1a
theme-name=Adwaita-dark
icon-theme-name=Adwaita
font-name=Sans 10
draw-user-backgrounds=false
show-hostname=true
SLICK

systemctl enable lightdm
systemctl enable NetworkManager

echo "==> Criando usuário matheus..."
useradd -m -s /bin/bash matheus
echo "matheus:matheus" | chpasswd
passwd -u matheus
usermod -aG sudo,audio,video,plugdev matheus

echo "==> Identidade do sistema..."
cat > /etc/os-release << 'OSRELEASE'
NAME="NexiliumOS"
VERSION="1.0"
ID=nexiliumos
ID_LIKE=debian
PRETTY_NAME="NexiliumOS 1.0"
HOME_URL="https://github.com/Anfsarchives23/NexiliumOS"
OSRELEASE

echo "==> Configurando autologin LightDM..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/autologin.conf << 'LIGHTDM'
[Seat:*]
autologin-user=matheus
autologin-user-timeout=0
user-session=mate
LIGHTDM

echo "==> Garantindo sources.list correto no live..."
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main
deb http://deb.debian.org/debian trixie-updates main
SOURCES

echo "==> Forçando target gráfico..."
systemctl set-default graphical.target

echo "==> Limpando..."
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -f /tmp/chroot-setup.sh
