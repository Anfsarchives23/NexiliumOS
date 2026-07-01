#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "nexiliumos" > /etc/hostname

cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   nexiliumos
HOSTS

apt-get update

echo "==> Carregando lista de pacotes..."
# shellcheck source=packages.sh
source /tmp/packages.sh

echo "==> Instalando todos os pacotes do NexiliumOS (${#PACKAGES[@]} pacotes)..."
apt-get install -y "${PACKAGES[@]}"

echo "==> Removendo o SDDM que veio junto do KDE (usamos GDM como display manager)..."
systemctl disable sddm 2>/dev/null || true
apt-get purge -y sddm 2>/dev/null || true

echo "gdm3 shared/default-x-display-manager select gdm3" | debconf-set-selections
dpkg-reconfigure gdm3

echo "==> Gerando locales (sem isso o KDE/GDM podem crashar ao subir a sessão)..."
sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^# *\(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen
if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
fi
if ! grep -q "^pt_BR.UTF-8 UTF-8" /etc/locale.gen; then
    echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
fi
locale-gen
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en

echo "==> Criando atalho do instalador na área de trabalho..."
mkdir -p /etc/skel/Desktop
if [ -f /usr/share/applications/calamares.desktop ]; then
    cp /usr/share/applications/calamares.desktop /etc/skel/Desktop/calamares.desktop
    chmod +x /etc/skel/Desktop/calamares.desktop
fi

echo "==> Liberando o Calamares sem pedir senha (usuários do grupo sudo)..."
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/45-nexilium-calamares.rules << 'POLKIT'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program").indexOf("calamares") !== -1 &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
POLKIT

echo "==> Criando usuário liveuser..."
useradd -m -s /bin/bash liveuser
echo "liveuser:live" | chpasswd
passwd -u liveuser
usermod -aG sudo,audio,video,plugdev liveuser

echo "==> Habilitando login sem senha para liveuser (o PAM do GDM já reconhece esse grupo nativamente)..."
groupadd -f nopasswdlogin
usermod -aG nopasswdlogin liveuser

echo "==> Configurando autologin no GDM..."
mkdir -p /etc/gdm3
cat > /etc/gdm3/daemon.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=liveuser
WaylandEnable=true

[security]

[xdmcp]

[chooser]

[debug]
GDMCONF

echo "==> Definindo sessão padrão do liveuser (Plasma Wayland, com fallback X11)..."
mkdir -p /var/lib/AccountsService/users
cat > /var/lib/AccountsService/users/liveuser << 'ACCOUNTS'
[User]
Session=plasma
XSession=plasmax11
SystemAccount=false
ACCOUNTS

systemctl enable gdm3
systemctl enable NetworkManager
systemctl enable accounts-daemon
systemctl enable dbus

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

echo "==> Instalando VirtualBox Guest Additions (aceleração gráfica em VM)..."
apt-get install -y \
    virtualbox-guest-utils \
    virtualbox-guest-x11 \
    virtualbox-guest-dkms
# O virtualbox-guest-dkms compila o módulo do kernel usando linux-headers-amd64
# (já incluso em packages.sh). Isso dá aceleração 3D de verdade via VMSVGA,
# em vez de forçar renderização por software - que é o que travava o Plasma.
# Em hardware real esses pacotes simplesmente não fazem nada (o serviço só
# ativa se detectar que está rodando dentro do VirtualBox).

systemctl enable vboxadd 2>/dev/null || true
systemctl enable vboxadd-service 2>/dev/null || true
systemctl enable vboxadd-x11 2>/dev/null || true

echo "==> Forçando target gráfico..."
systemctl set-default graphical.target

echo "==> Corrigindo machine-id (essencial para dbus/logind funcionarem no live-boot)..."
rm -f /etc/machine-id
touch /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id
# Deixa vazio de propósito: o live-boot/systemd gera um novo machine-id
# a cada boot da ISO. Se o arquivo não existisse (ou viesse copiado do
# host de build), dbus e systemd-logind falham silenciosamente e a
# sessão gráfica cai numa tela de erro logo após o login.

echo "==> Guardando cópia permanente da lista de pacotes no sistema..."
mkdir -p /etc/nexiliumos
cp /tmp/packages.sh /etc/nexiliumos/packages.sh
chmod 644 /etc/nexiliumos/packages.sh

echo "==> Limpando..."
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -f /tmp/chroot-setup.sh /tmp/packages.sh
