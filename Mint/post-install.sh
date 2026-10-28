#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# 1. Automatically Configure Guest Wi-Fi Connection
mkdir -p /etc/NetworkManager/system-connections
cat <<EOF > /etc/NetworkManager/system-connections/GuestWiFi.nmconnection
[connection]
id=Guest
type=wifi

[wifi]
mode=infrastructure
ssid=Guest

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=character

[ipv4]
method=auto

[ipv6]
method=auto
EOF
chmod 600 /etc/NetworkManager/system-connections/GuestWiFi.nmconnection

# 2. Turn Off Welcome Screen Globally (Verified Working)
mkdir -p /etc/dconf/db/local.d
cat <<EOF > /etc/dconf/db/local.d/00-welcome-screen
[org/x/apps/favorites]
show-welcome-screen=false
EOF
dconf update 2>/dev/null || true

# 3. Stage the Target Runtime Directory
mkdir -p /target_payload

# 4. Create the NEW Online First-Boot Script
cat <<'EOF' > /target_payload/first-boot.sh
#!/bin/bash
clear
echo "============================================="
echo "       RUNNING ONLINE LAB DEPLOYMENT        "
echo "============================================="
echo ""

# A. Set Hostname
printf "Enter the unique computer name for this laptop: "
read NEW_HOSTNAME
if [ -n "$NEW_HOSTNAME" ]; then
    echo "$NEW_HOSTNAME" | sudo tee /etc/hostname
    sudo sed -i "s/unassigned-hostname/$NEW_HOSTNAME/g" /etc/hosts
    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "✔ Hostname updated to: $NEW_HOSTNAME"
fi
echo ""

# B. Wait for Wi-Fi Connectivity
echo "Verifying network connectivity via Guest Wi-Fi..."
until ping -c 1 8.8.8.8 &>/dev/null; do
    echo "Waiting for internet access... (Checking connection)"
    sleep 3
done
echo "✔ Network connected!"
echo ""

# C. Install Software via Online Repositories
echo "Updating system package repositories..."
sudo apt update -y
echo "Installing git, ansible, and openssh-server..."
sudo apt install -y git ansible openssh-server
sudo systemctl enable --now ssh
echo "✔ Software installation complete."
echo ""

# D. Create Student User Account
echo "Creating student account..."
sudo useradd -m -s /bin/bash student
echo "student:girlsrule" | sudo chpasswd
sudo mkdir -p /home/student/.config/autostart
cat <<EON > /tmp/mintwelcome.desktop
[Desktop Entry]
Type=Application
Exec=mintwelcome
X-GNOME-Autostart-enabled=false
EON
sudo cp /tmp/mintwelcome.desktop /home/student/.config/autostart/
sudo chown -R student:student /home/student/.config
echo "✔ Student user generated."
echo ""

# E. Cleanup Autostart Entry so this script only runs ONCE
rm -f ~/.config/autostart/first-boot.desktop
echo "Setup complete! Press Enter to reboot..."
read
sudo reboot
EOF
chmod +x /target_payload/first-boot.sh

# 5. Create the Autostart trigger for the 'girlboss' profile
mkdir -p /home/girlboss/.config/autostart
cat <<EOF > /home/girlboss/.config/autostart/first-boot.desktop
[Desktop Entry]
Type=Application
Name=First Boot Deployment
Exec=gnome-terminal --full-screen -- /target_payload/first-boot.sh
X-GNOME-Autostart-enabled=true
EOF
chown -R 1000:1000 /home/girlboss/.config

exit 0
