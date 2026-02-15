#!/usr/bin/env nix-shell
#! nix-shell -i bash -p git parted btrfs-progs openssl

echo "=== Configuration post-installation NixOS ==="
echo ""
echo "⚠️  Lance ce script APRÈS l'installation graphique ET APRÈS le redémarrage !"
echo ""
read -p "L'installation graphique est terminée (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Lance d'abord l'installeur graphique !"
    exit 1
fi

echo "1. Sauvegarde le hardware-configuration.nix généré par l'installeur"
echo ""
sudo cp /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix.backup

echo "2. Sauvegarde complète (au cas où)"
echo ""
sudo cp -r /etc/nixos /etc/nixos.backup

echo "3. Vide le contenu de /etc/nixos"
echo ""
sudo rm -rf /etc/nixos/*
sudo rm -rf /etc/nixos/.git* 2>/dev/null || true

echo "4. Clone ta vraie config"
echo ""
sudo cp -Rf . /etc/nixos
#sudo git clone https://github.com/Sinsry/nixos-maousse /etc/nixos

echo "5. Restaure le hardware-configuration.nix de cette machine"
echo ""
sudo cp /tmp/hardware-configuration.nix.backup /etc/nixos/hardware-configuration.nix

echo "6. Configure SSH"
echo ""
openssl enc -aes-256-cbc -pbkdf2 -d -in /etc/nixos/asset/ssh-keys.enc -out /home/$USER/ssh-backup.tar.gz
sudo chown $USER:users /home/$USER/ssh-backup.tar.gz
mkdir -p /home/$USER/.ssh
tar xzf /home/$USER/ssh-backup.tar.gz -C /home/$USER/
sudo chown -R $USER:users /home/$USER/.ssh
sudo chmod 600 /home/$USER/.ssh/id_ed25519
sudo chmod 644 /home/$USER/.ssh/id_ed25519.pub

echo "7. Copie SSH pour root"
echo ""
echo "Configuration SSH pour root..."
sudo mkdir -p /root/.ssh
sudo cp /home/$USER/.ssh/id_ed25519* /root/.ssh/
sudo chmod 600 /root/.ssh/id_ed25519
sudo chmod 644 /root/.ssh/id_ed25519.pub

echo "8. Change vers SSH"
echo ""
cd /etc/nixos
sudo git remote set-url origin git@github.com:Sinsry/nixos-maousse.git

echo "9. Rebuild avec ta vraie config"
echo ""
sudo nixos-rebuild switch --flake path:/etc/nixos#maousse

echo "10. Finalisation des droits et sécurité Git"
echo ""
# On donne la propriété du dossier à ton utilisateur (groupe 'users' par défaut sur NixOS)
sudo chown -R $USER:users /etc/nixos
# On autorise Git à travailler dans ce dossier pour éviter l'erreur 'dubious ownership'
# On utilise sudo -u sinsry pour que la config git soit écrite pour ton utilisateur, pas pour root
sudo -u $USER git config --global --add safe.directory /etc/nixos

echo ""
echo "✅ Configuration terminée !"
echo ""
echo "Tu peux maintenant redémarrer pour profiter de ton système complet ! 🎉"
