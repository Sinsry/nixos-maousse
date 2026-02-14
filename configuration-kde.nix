# Configuration NixOS pour KDE Plasma 6
# Système: NixOS 25.11 stable
# Desktop Environment: KDE Plasma 6
# Hardware: AMD GPU (amdgpu), virtualisation KVM/QEMU

{
  pkgs,
  lib,
  ...
}:
{
  # Import des configurations matérielles et réseau
  imports = [
    ./hardware-configuration.nix # Configuration matérielle auto-générée
    ./network-mounts.nix # Points de montage réseau (NFS/CIFS)
    ./disks-mounts.nix # Configuration des disques et partitions
  ];

  #==== Overlay Mesa (temporaire) ====
  # Exemple d'overlay pour utiliser une version spécifique de Mesa
  # Utile pour tester de nouvelles versions ou corriger des bugs graphiques
  # nixpkgs.overlays = [
  #   (self: super: {
  #     mesa = super.mesa.overrideAttrs (oldAttrs: rec {
  #       version = "26.0.0";
  #       src = super.fetchurl {
  #         urls = [
  #           "https://archive.mesa3d.org/mesa-${version}.tar.xz"
  #           "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
  #         ];
  #         ## Calcul du hash : nix-prefetch-url https://archive.mesa3d.org/mesa-${version}.tar.xz
  #         sha256 = "0wizyf2amz589cv3anz27rq69zvyxk8f4gb3ckn6rhymcj7fji1a";
  #       };
  #       ##== Exemple : retrait d'un patch problématique
  #       #patches = builtins.filter (p: !(builtins.match ".*musl.patch" (toString p) != null)) (
  #       #  oldAttrs.patches or [ ]
  #       #);
  #     });
  #   })
  # ];

  #==== Boot ====
  boot = {
    # Chargement du pilote AMD GPU dès l'initrd pour un démarrage plus fluide
    initrd.kernelModules = [ "amdgpu" ];

    # Utilise systemd dans l'initrd (boot plus moderne et rapide)
    initrd.systemd.enable = true;

    # Réduit la verbosité des logs au démarrage pour un boot plus propre
    consoleLogLevel = 0; # Niveau minimal de logs console
    initrd.verbose = false; # Désactive les messages verbeux de l'initrd

    # Paramètres du noyau
    kernelParams = [
      "video=2160x1440@165" # Force la résolution et le taux de rafraîchissement
      #  "quiet" # Réduit les messages du noyau
      "splash" # Active l'écran de démarrage graphique
      "boot.shell_on_fail" # Ouvre un shell en cas d'échec du boot (utile pour le dépannage)
      "amdgpu.dcverbose=0" # Réduit la verbosité du pilote AMD Display Core
      "rd.systemd.show_status=false" # Cache les messages systemd au démarrage
      "rd.udev.log_level=3" # Réduit les logs udev dans l'initrd
      "udev.log_priority=3" # Niveau de log udev (3 = erreurs uniquement)
      "intel_iommu=on" # Active IOMMU Intel (nécessaire pour le GPU passthrough)
    ];

    # Paramètres sysctl du noyau
    kernel.sysctl = {
      # Désactive la mitigation split lock (peut améliorer les perfs de certains jeux)
      "kernel.split_lock_mitigate" = 0;
    };

    # Modules noyau à charger au démarrage
    kernelModules = [
      "ntsync" # Module pour ntSync (améliore les perfs Wine/Proton)
      "vfio_pci" # GPU passthrough pour les VMs
      "vfio" # Framework de virtualisation d'I/O
      "vfio_iommu_type1" # Type IOMMU pour VFIO
    ];

    # Systèmes de fichiers supportés
    supportedFilesystems = [
      "ntfs" # Support NTFS (Windows)
      "exfat" # Support exFAT (clés USB, cartes SD)
      "vfat" # Support FAT32
      "ext4" # Système de fichiers Linux standard
      "btrfs" # Système de fichiers moderne avec snapshots
    ];

    # Configuration du chargeur de démarrage
    loader = {
      timeout = 0; # Pas de timeout (boot direct)
      systemd-boot = {
        enable = true; # Utilise systemd-boot (UEFI)
        consoleMode = "max"; # Résolution maximale pour le menu de boot
      };
      efi.canTouchEfiVariables = true; # Permet de modifier les variables EFI
    };

    # Noyau Linux à utiliser
    kernelPackages = pkgs.linuxPackages_latest; # Noyau Linux le plus récent
    # Alternatives disponibles :
    #kernelPackages = pkgs.linuxPackages_lqx; # Noyau optimisé pour desktop
    #kernelPackages = pkgs.linuxPackages_xanmod_latest; # Noyau Xanmod (gaming)
    #kernelPackages = pkgs.linuxPackages_testing; # Noyau de test
  };

  #==== Réseau ====
  networking = {
    hostName = "maousse"; # Nom de la machine sur le réseau
    networkmanager.enable = true; # Gestionnaire de réseau (WiFi, Ethernet, VPN)
    firewall.enable = false; # Firewall désactivé (à activer en environnement de production)
  };

  #==== Services Systemd ====
  systemd.services = {
    # Désactive l'attente de la connexion réseau au boot (accélère le démarrage)
    NetworkManager-wait-online.enable = false;

    # Désactive le démarrage automatique de Samba (démarrage manuel uniquement)
    samba-smbd.wantedBy = lib.mkForce [ ]; # Serveur Samba
    samba-nmbd.wantedBy = lib.mkForce [ ]; # NetBIOS name service
    samba-winbindd.wantedBy = lib.mkForce [ ]; # Service d'authentification Windows

    # Service de notification après une mise à jour automatique
    nixos-upgrade-notification = {
      description = "Mise à jour NixOS";
      after = [ "nixos-upgrade.service" ]; # S'exécute après la mise à jour
      wantedBy = [ "nixos-upgrade.service" ]; # Déclenché par le service de mise à jour

      # Outils nécessaires au script
      path = with pkgs; [
        coreutils # Utilitaires de base (readlink, mkdir, cat, etc.)
        libnotify # Pour envoyer des notifications (notify-send)
      ];

      # Script qui vérifie si une nouvelle génération est disponible
      script = ''
        CURRENT_GEN=$(readlink -f /run/current-system)
        LATEST_GEN=$(readlink -f /nix/var/nix/profiles/system)
        LOCK_FILE="/tmp/nixos-upgrade-notification/notified"

        # Si la génération actuelle diffère de la dernière générée
        if [ "$CURRENT_GEN" != "$LATEST_GEN" ]; then
          mkdir -p /tmp/nixos-upgrade-notification
          
          # Vérifie si on a déjà notifié pour cette génération
          if [ ! -f "$LOCK_FILE" ] || [ "$(cat "$LOCK_FILE" 2>/dev/null)" != "$LATEST_GEN" ]; then
            # Envoie une notification persistante
            notify-send "NixOS : Mise à jour prête" "Mise à jour effectuée. Redémarrage recommandé pour appliquer les changements." --icon=system-software-update --urgency=critical --expire-time=0 --category=system
            echo "$LATEST_GEN" > "$LOCK_FILE"
          fi
        else
          # Nettoie le fichier de verrouillage si les générations sont identiques
          rm -f "$LOCK_FILE"
        fi
      '';

      serviceConfig = {
        Type = "oneshot"; # Service qui s'exécute une fois
        User = "sinsry"; # Utilisateur qui reçoit la notification
        Environment = [
          "DISPLAY=:0" # Affichage X11
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus" # Bus D-Bus pour les notifications
        ];
      };
    };
  };

  #==== Localisation ====
  time.timeZone = "Europe/Paris"; # Fuseau horaire

  # Configuration des locales (langue française)
  i18n = {
    defaultLocale = "fr_FR.UTF-8"; # Locale par défaut

    # Configuration détaillée des paramètres régionaux
    extraLocaleSettings = {
      LC_ADDRESS = "fr_FR.UTF-8"; # Format d'adresse
      LC_IDENTIFICATION = "fr_FR.UTF-8"; # Identification
      LC_MEASUREMENT = "fr_FR.UTF-8"; # Système métrique
      LC_MONETARY = "fr_FR.UTF-8"; # Format monétaire (euros)
      LC_NAME = "fr_FR.UTF-8"; # Format des noms
      LC_NUMERIC = "fr_FR.UTF-8"; # Format des nombres
      LC_PAPER = "fr_FR.UTF-8"; # Taille de papier (A4)
      LC_TELEPHONE = "fr_FR.UTF-8"; # Format téléphone
      LC_TIME = "fr_FR.UTF-8"; # Format date/heure
    };
  };

  console.keyMap = "us"; # Clavier console (QWERTY)
  nixpkgs.config.allowUnfree = true; # Autorise les paquets non-libres (Steam, Discord, etc.)

  #==== Matériel ====
  hardware = {
    # Active le contrôle de l'overclocking pour GPU AMD
    amdgpu.overdrive.enable = true;

    # Configuration Bluetooth
    bluetooth = {
      enable = true; # Active le Bluetooth
      powerOnBoot = true; # Allume le Bluetooth au démarrage
    };

    # Support des manettes Xbox via le pilote amélioré xpadneo
    xpadneo.enable = true;

    # Configuration graphique
    graphics = {
      enable = true; # Active l'accélération graphique
      enable32Bit = true; # Support 32-bit (nécessaire pour certains jeux Steam)

      # Paquets supplémentaires pour le support graphique AMD
      extraPackages = with pkgs; [
        rocmPackages.clr.icd # Support OpenCL pour GPU AMD (calcul)
        vulkan-loader # Chargeur Vulkan
        vulkan-validation-layers # Validation Vulkan (debug)
      ];
    };
  };

  #==== Services ====
  services = {
    # LACT : Linux AMDGPU Controller (overclocking et monitoring GPU AMD)
    lact.enable = true;

    # Configuration du serveur X
    xserver = {
      enable = true; # Active X11
      xkb.layout = "us"; # Disposition clavier QWERTY
      videoDrivers = [ "amdgpu" ]; # Pilote graphique AMD
      excludePackages = with pkgs; [ xterm ]; # Retire xterm (non utilisé avec KDE)
    };

    # SDDM : Display Manager pour KDE
    displayManager.sddm = {
      enable = true;
      wayland.enable = true; # Active le support Wayland
      theme = "breeze"; # Thème Breeze (par défaut KDE)
      extraPackages = with pkgs; [ papirus-icon-theme ]; # Icônes Papirus
    };

    # Samba : Partage de fichiers Windows/Linux
    samba = {
      enable = true;
      openFirewall = true; # Ouvre les ports nécessaires
    };

    # Avahi : Découverte de services réseau (zeroconf/Bonjour)
    avahi = {
      enable = true;
      nssmdns4 = true; # Résolution de noms .local via mDNS
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true; # Publie les adresses IP
        workstation = true; # Se déclare comme station de travail
      };
    };

    rpcbind.enable = true; # Nécessaire pour NFS
    gvfs.enable = true; # Support des systèmes de fichiers virtuels (montage automatique)
    desktopManager.plasma6.enable = true; # Active KDE Plasma 6

    #qemuGuest.enable = true; # À activer si NixOS est dans une VM QEMU
    spice-vdagentd.enable = true; # Agent SPICE pour VMs (copier-coller, résolution dynamique)

    # Configuration libinput (touchpad et souris)
    libinput = {
      enable = true;
      mouse = {
        accelProfile = "flat"; # Désactive l'accélération souris (important pour gaming)
      };
    };
  };

  # Virtualisation KVM/QEMU avec libvirt
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true; # TPM virtuel (nécessaire pour Windows 11)
    };
    # Support du partage de fichiers avec les VMs via virtiofs
    qemu.vhostUserPackages = with pkgs; [
      virtiofsd # Démon pour partage de dossiers avec VMs
    ];
  };

  #==== Programmes ====
  programs = {
    # GameMode : Optimisations système pour le gaming
    gamemode = {
      enable = true;
      enableRenice = true; # Permet de changer la priorité des processus
      settings = {
        general = {
          renice = 10; # Priorité à donner aux jeux (10 = nice, -20 = priorité max)
        };
      };
    };

    # KDE Partition Manager
    partition-manager = {
      enable = true;
    };

    # Steam : Plateforme de jeux
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Remote Play via Internet
      dedicatedServer.openFirewall = true; # Serveurs dédiés
      localNetworkGameTransfers.openFirewall = true; # Transfert de jeux en réseau local

      package = pkgs.steam.override {
        extraEnv = {
          # Force le scaling de l'interface (utile pour HiDPI)
          STEAM_FORCE_DESKTOPUI_SCALING = "1";
        };
        extraArgs = "-language french"; # Interface en français
      };
    };

    # Firefox
    firefox = {
      enable = true;
      languagePacks = [ "fr" ]; # Pack de langue française
      preferences = {
        "intl.locale.requested" = "fr"; # Demande la locale française
      };
      # Intégration avec KDE Plasma (média controls, notifications)
      nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
    };

    # Chromium
    chromium = {
      enable = true;
      extraOpts = {
        # Intégration KDE Plasma pour Chromium
        "NativeMessagingHosts" = {
          "org.kde.plasma.browser_integration" =
            "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
        };
      };
    };

    # Visual Studio Code
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-ceintl.vscode-language-pack-fr # Pack langue française
        anthropic.claude-code # Extension Claude Code (AI)
        jnoortheen.nix-ide # Support Nix (coloration, complétion)
        ms-vscode-remote.remote-ssh # SSH distant
        ms-vscode-remote.remote-ssh-edit # Édition SSH
      ];
    };

    # Git : Gestionnaire de versions
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main"; # Branche par défaut
        user = {
          name = "Sinsry";
          email = "Sinsry@users.noreply.github.com"; # Email no-reply GitHub
        };
        # Cache les identifiants pendant 7 jours (604800 secondes)
        credential.helper = "cache --timeout=604800";
        # Template de commit par défaut
        commit.template = pkgs.writeText "commit-template" ''
          Update 
        '';
      };
    };

    # SSH
    ssh = {
      startAgent = true; # Démarre l'agent SSH automatiquement
      enableAskPassword = true; # Active la demande de mot de passe
      askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"; # Dialogue KDE pour les mots de passe SSH
    };

    # nix-ld : Permet d'exécuter des binaires non-NixOS
    nix-ld = {
      enable = true;
      # Bibliothèques de base à fournir aux binaires externes
      libraries = with pkgs; [
        stdenv.cc.cc.lib # Bibliothèque C++ standard
        zlib # Compression
        openssl # Cryptographie
      ];
    };

    dconf.enable = true; # Base de données de configuration (nécessaire pour certaines apps GNOME/GTK)

    # Configuration Bash
    bash = {
      completion.enable = true; # Active l'autocomplétion
      interactiveShellInit = ''
        fastfetch # Affiche les infos système au lancement du terminal
      '';
    };

    virt-manager.enable = true; # Interface graphique pour gérer les VMs
  };

  #==== Utilisateurs ====
  users.users.sinsry = {
    isNormalUser = true; # Utilisateur normal (non système)
    description = "Sinsry"; # Nom complet
    extraGroups = [
      "networkmanager" # Gestion du réseau
      "wheel" # Accès sudo
      "gamemode" # Utilisation de GameMode
      "libvirtd" # Gestion des VMs
    ];
  };

  #==== Sécurité ====
  # Limites PAM pour les membres du groupe gamemode
  security.pam.loginLimits = [
    {
      domain = "@gamemode"; # S'applique au groupe gamemode
      type = "-"; # Soft et hard limit
      item = "nice"; # Priorité des processus
      value = "-20"; # Permet de mettre la priorité jusqu'à -20 (max)
    }
  ];

  #==== Environnement ====
  environment = {
    # Paquets système disponibles pour tous les utilisateurs
    systemPackages = with pkgs; [
      cifs-utils # Outils pour montage CIFS/SMB
      discord # Client Discord
      dnsmasq # Serveur DNS/DHCP léger
      dualsensectl # Contrôle manettes PS5 DualSense
      fastfetch # Affichage infos système (neofetch moderne)
      faugus-launcher # Lanceur de jeux Windows
      ffmpeg # Manipulation audio/vidéo
      google-chrome # Navigateur Google Chrome
      goverlay # Interface graphique pour MangoHud
      jq # Parser JSON en ligne de commande
      kdePackages.breeze-gtk # Thème GTK Breeze
      kdePackages.filelight # Analyseur d'espace disque
      kdePackages.ksshaskpass # Dialogue mot de passe SSH
      kdePackages.plasma-browser-integration # Intégration navigateur
      kdePackages.qtwebengine # Moteur web Qt
      libnotify # Bibliothèque de notifications
      usbutils # Outils USB (lsusb)
      mangohud # Overlay gaming (FPS, température, etc.)
      meld # Outil de comparaison/fusion de fichiers
      mpv # Lecteur multimédia
      nfs-utils # Outils NFS
      nixd # Serveur de langage Nix (LSP)
      nixfmt # Formateur de code Nix
      nvd # Compare les générations NixOS
      papirus-icon-theme # Thème d'icônes Papirus
      pciutils # Outils PCI (lspci)
      protonvpn-gui # Interface VPN ProtonVPN
      psmisc # Outils processus (killall, fuser)
      rar # Compression RAR
      virt-viewer # Visualiseur de VMs
      rsync # Synchronisation de fichiers
      vlc # Lecteur multimédia
      virt-v2v # Conversion de VMs
      vorta # Interface graphique pour Borg Backup
      vulkan-tools # Outils Vulkan (vulkaninfo)
      unzip # Décompression ZIP
      wowup-cf # Gestionnaire d'addons World of Warcraft

      #====== Paquets GStreamer pour SVW (commentés) ======
      # Nécessaires pour certaines applications Qt utilisant les médias
      # gst_all_1.gstreamer
      # gst_all_1.gst-vaapi # Accélération matérielle
      # gst_all_1.gst-plugins-base
      # gst_all_1.gst-plugins-good
      # gst_all_1.gst-plugins-bad
      # gst_all_1.gst-plugins-ugly
      # gst_all_1.gst-libav # Support formats via libav
      # qt6.qtmultimedia

      # Configuration personnalisée du thème SDDM (écran de connexion)
      (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
        [General]
        background=/etc/nixos/asset/wallpaper.png
      '')

      # Configuration globale des icônes KDE
      (pkgs.writeTextDir "etc/xdg/kdeglobals" ''
        [Icons]
        Theme=Papirus-Dark
      '')
    ];

    # Paquets Plasma 6 à exclure (désinstaller) si nécessaire
    # plasma6.excludePackages = with pkgs; [
    #   # Liste des applications KDE à ne pas installer
    # ];

    # Variables d'environnement globales
    sessionVariables = {
      GDK_BACKEND = "x11"; # Force GTK à utiliser X11 (certaines apps Wayland ont des bugs)
      GTK_THEME = "Breeze-Dark"; # Thème GTK sombre
      #  SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"; # Dialogue SSH
      SSH_ASKPASS_REQUIRE = "prefer"; # Préfère le dialogue graphique
      # QT_MEDIA_BACKEND = "gstreamer"; # Force GStreamer pour Qt (si décommenté)
    };

    # Alias shell pratiques
    shellAliases = {
      # Rebuild la config depuis /etc/nixos
      nixrebuild = "sudo nixos-rebuild switch --flake path:/etc/nixos#maousse";

      # Met à jour le flake puis rebuild
      nixupdate = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake path:/etc/nixos#maousse && cd ~/";

      # Push la config vers Git
      nixpush = "cd /etc/nixos && sudo git add . && (sudo git commit -m 'Update' || true ) && sudo git push && cd ~/";

      # Liste les générations système
      nixlistenv = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

      # Nettoie le store Nix et rebuild le bootloader
      nixgarbage = "sudo nix-collect-garbage -d && sudo nixos-rebuild boot";

      # Compare la version locale du flake avec nixpkgs upstream
      nixcheck = "git ls-remote https://github.com/NixOS/nixpkgs nixos-unstable | cut -c1-7 && nix flake metadata --json path:/etc/nixos | jq -r .locks.nodes.nixpkgs.locked.rev | cut -c1-7";
    };

    # Fichiers de configuration système
    etc = {
      # Quirks libinput personnalisés (corrections pour périphériques spécifiques)
      "libinput/local-overrides.quirks".source = ./asset/local-overrides.quirks;

      # Configuration readline (autocomplétion Bash)
      "inputrc".text = ''
        set completion-ignore-case on # Ignore la casse dans l'autocomplétion
        set show-all-if-ambiguous on # Affiche toutes les possibilités directement
        set completion-map-case on # Traite - et _ comme équivalents
      '';
    };
  };

  #==== Système ====
  system = {
    # Script d'activation : crée /bin/bash (nécessaire pour certains scripts)
    activationScripts.binbash = ''
      mkdir -p /bin
      ln -sf ${pkgs.bash}/bin/bash /bin/bash
    '';

    # Configuration des mises à jour automatiques
    autoUpgrade = {
      enable = true; # Active les mises à jour auto
      allowReboot = false; # Ne redémarre PAS automatiquement
      flake = "/etc/nixos#maousse"; # Flake à utiliser
      dates = "hourly"; # Vérifie les mises à jour toutes les heures
    };

    # Version de NixOS utilisée lors de l'installation
    # NE PAS MODIFIER (sert à la compatibilité entre versions)
    stateVersion = "25.11";
  };

  #==== Swap ====
  # ZRAM : Compression de la RAM pour augmenter la mémoire disponible
  zramSwap = {
    enable = true;
    memoryPercent = 12; # Utilise 12% de la RAM pour le swap compressé
  };

  #==== Nix ====
  nix = {
    settings = {
      # Active les fonctionnalités expérimentales
      experimental-features = [
        "nix-command" # Commandes nix nouvelle génération
        "flakes" # Support des flakes
      ];

      auto-optimise-store = true; # Déduplique automatiquement le store Nix
      download-buffer-size = 1073741824; # Buffer de téléchargement 1GB (accélère les builds)
      max-jobs = "auto"; # Nombre de jobs parallèles (auto = nombre de cores)
      cores = 0; # Nombre de cores par job (0 = tous)
    };

    # Garbage collector automatique
    gc = {
      automatic = true; # Active le nettoyage auto
      dates = "weekly"; # Hebdomadaire
      options = "--delete-older-than 15d"; # Supprime les générations de plus de 15 jours
    };
  };

  #==== Qt ====
  # Configuration Qt pour correspondre au thème KDE
  qt = {
    enable = true;
    platformTheme = "kde"; # Utilise le thème KDE
    style = "breeze"; # Style Breeze
  };
}
