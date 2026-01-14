#!/usr/bin/env nix-shell
#! nix-shell -i bash -p git parted btrfs-progs

set -e # Arrête le script en cas d'erreur

echo "=== 🚀 Installation Directe NixOS Maousse (Unstable) ==="

# --- CONFIGURATION DES DISQUES ---
# Remplace nvme0n1 par ton disque si nécessaire (vérifie avec lsblk)
DISK="/dev/nvme0n1"

# 1. Montage des partitions
# On part du principe que p1 = EFI et p2 = Root (Btrfs)
echo "Montage des partitions sur /mnt..."
sudo mount "${DISK}p2" /mnt
sudo mkdir -p /mnt/boot
sudo mount "${DISK}p1" /mnt/boot

# 2. Renommage et Labels
echo "Configuration des labels (NixOS)..."
sudo parted /dev/nvme0n1 name 2 NixOS || true
sudo btrfs filesystem label /mnt NixOS

# 3. Génération du Hardware local
echo "Génération du hardware-configuration.nix..."
sudo mkdir -p /mnt/etc/nixos/asset/maousse
# On génère le hardware spécifique à la machine actuelle
sudo nixos-generate-config --root /mnt

# 4. Récupération de ta config GitHub
echo "Clonage de la configuration depuis GitHub..."
rm -rf /tmp/nixos-maousse
git clone https://github.com/Sinsry/nixos-maousse /tmp/nixos-maousse

# 5. Fusion de la configuration (Méthode propre)
echo "Installation des fichiers de configuration..."

# Copie des fichiers racines du repo
cp /tmp/nixos-maousse/flake.nix /mnt/etc/nixos/
cp /tmp/nixos-maousse/flake.lock /mnt/etc/nixos/
cp /tmp/nixos-maousse/configuration.nix /mnt/etc/nixos/
cp /tmp/nixos-maousse/disks-mounts.nix /mnt/etc/nixos/
cp /tmp/nixos-maousse/network-mounts.nix /mnt/etc/nixos/

# Copie récursive du dossier d'assets (s'il y a des images/clés/scripts dedans)
if [ -d "/tmp/nixos-maousse/asset/maousse" ]; then
    cp -r /tmp/nixos-maousse/asset/naousse/* /mnt/etc/nixos/asset/maousse/
fi

# 6. Forcer l'Unstable (Mise à jour du lock)
echo "Mise à jour du lockfile vers les derniers commits Unstable..."
cd /mnt/etc/nixos
# Cette étape garantit que tu télécharges les versions les plus récentes d'aujourd'hui
sudo nix flake update

# 7. Installation finale
echo "Lancement de nixos-install (Cible : maousse)..."
# --no-channel-copy : on ne veut que du Flake, pas de vieux channels
sudo nixos-install --flake .#maousse --no-channel-copy

echo ""
echo "===================================================="
echo "✅ Installation terminée avec succès !"
echo "⚠️  N'oublie pas d'enlever la clé USB après le reboot."
echo "===================================================="
echo "Tu peux maintenant taper : reboot"
