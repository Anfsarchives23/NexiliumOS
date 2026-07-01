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

echo "==> Instalando Budgie Desktop..."
apt-get install -y \
    budgie-desktop \
    budgie-desktop-settings \
    lightdm \
    lightdm-gtk-greeter \
    slick-greeter \
    gnome-terminal \
    nautilus \
    firefox-esr

echo "==> Instalando tema, ícones e fontes..."
apt-get install -y \
    arc-theme \
    papirus-icon-theme \
    fonts-noto \
    dconf-cli

echo "==> Instalando Calamares (instalador)..."
apt-get install -y \
    calamares \
    calamares-settings-debian \
    parted \
    dosfstools \
    rsync \
    squashfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-common \
    os-prober \
    efibootmgr

echo "==> Criando atalho do instalador na área de trabalho..."
mkdir -p /etc/skel/Desktop
if [ -f /usr/share/applications/calamares.desktop ]; then
    cp /usr/share/applications/calamares.desktop /etc/skel/Desktop/calamares.desktop
    chmod +x /etc/skel/Desktop/calamares.desktop
fi

echo "==> Criando usuário liveuser..."
useradd -m -s /bin/bash liveuser
echo "liveuser:live" | chpasswd
passwd -u liveuser
usermod -aG sudo,audio,video,plugdev liveuser

echo "==> Habilitando login sem senha para liveuser (PAM)..."
groupadd -f nopasswdlogin
usermod -aG nopasswdlogin liveuser

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
autologin-session=budgie-desktop
user-session=budgie-desktop
LIGHTDM

cat > /etc/lightdm/lightdm.conf << 'LIGHTDMGLOBAL'
[LightDM]
greeter-session=slick-greeter
LIGHTDMGLOBAL

cat > /etc/lightdm/slick-greeter.conf << 'SLICK'
[Greeter]
background=#1a1a1a
theme-name=Arc-Dark
icon-theme-name=Papirus-Dark
font-name=Noto Sans 10
draw-user-backgrounds=false
show-hostname=true
SLICK

echo "==> Definindo slick-greeter como greeter padrão via debconf..."
echo "slick-greeter shared/default-x-display-manager select lightdm" | debconf-set-selections
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections

systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable accounts-daemon

echo "==> Aplicando tema/ícones/fontes padrão para todos os usuários (via dconf)..."
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-nexilium-appearance << 'DCONF'
[org/gnome/desktop/interface]
gtk-theme='Arc-Dark'
icon-theme='Papirus-Dark'
font-name='Noto Sans 10'
document-font-name='Noto Sans 10'
monospace-font-name='Noto Sans Mono 10'
cursor-theme='Adwaita'
cursor-size=24

[org/gnome/desktop/wm/preferences]
theme='Arc-Dark'

[org/gnome/desktop/background]
picture-uri=''
primary-color='#1a1a1a'
color-shading-type='solid'
DCONF

mkdir -p /etc/dconf/db/local.d/locks
cat > /etc/dconf/db/local.d/locks/00-nexilium-appearance << 'LOCKS'
# Deixa o tema e ícones como padrão, mas destravado -
# o usuário pode alterar depois se quiser.
LOCKS

dconf update

echo "==> Identidade do sistema..."
cat > /etc/os-release << 'OSRELEASE'
NAME="NexiliumOS"
VERSION="1.0"
ID=nexiliumos
ID_LIKE=debian
PRETTY_NAME="NexiliumOS 1.0"
HOME_URL="https://github.com/zanfss0/NexiliumOS"
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
