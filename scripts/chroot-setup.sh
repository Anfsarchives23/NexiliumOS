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
    dbus \
    polkitd \
    pkexec \
    accountsservice

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

echo "==> Criando usuário liveuser..."
useradd -m -s /bin/bash liveuser
echo "liveuser:live" | chpasswd
passwd -u liveuser
usermod -aG sudo,audio,video,plugdev liveuser

echo "==> Habilitando login sem senha para liveuser (PAM)..."
# Cria o grupo usado pelo PAM do LightDM para permitir autologin sem senha
groupadd -f nopasswdlogin
usermod -aG nopasswdlogin liveuser

# Garante que o pam_succeed_if do lightdm-autologin aceite o grupo acima
if [ -f /etc/pam.d/lightdm-autologin ]; then
    if ! grep -q "nopasswdlogin" /etc/pam.d/lightdm-autologin; then
        sed -i '1i auth   required   pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/lightdm-autologin
    fi
fi

echo "==> Configurando LightDM (greeter + autologin em um único arquivo)..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-nexilium.conf << 'LIGHTDM'
[Seat:*]
greeter-session=slick-greeter
autologin-user=liveuser
autologin-user-timeout=0
autologin-session=mate
user-session=mate
LIGHTDM

# Garante o greeter também no bloco [LightDM] global, como fallback
cat > /etc/lightdm/lightdm.conf << 'LIGHTDMGLOBAL'
[LightDM]
greeter-session=slick-greeter
LIGHTDMGLOBAL

cat > /etc/lightdm/slick-greeter.conf << 'SLICK'
[Greeter]
background=#1a1a1a
theme-name=Adwaita-dark
icon-theme-name=Adwaita
font-name=Sans 10
draw-user-backgrounds=false
show-hostname=true
SLICK

echo "==> Definindo slick-greeter como greeter padrão via debconf..."
echo "slick-greeter shared/default-x-display-manager select lightdm" | debconf-set-selections
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections

systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable accounts-daemon

echo "==> Identidade do sistema..."
cat > /etc/os-release << 'OSRELEASE'
NAME="NexiliumOS"
VERSION="1.0"
ID=nexiliumos
ID_LIKE=debian
PRETTY_NAME="NexiliumOS 1.0"
HOME_URL="https://github.com/Anfsarchives23/NexiliumOS"
OSRELEASE

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
