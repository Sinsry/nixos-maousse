{ _config, pkgs, ... }:

{

  imports = [
    # Inclut les résultats du scan matériel (drivers, partitions).
    ./hardware-configuration.nix 
    ./network-mounts.nix
    ./disks-mounts.nix
  ];

  # --- BOOT ET GRAPHIQUES ---
  boot = {
    # Charge le module AMDGPU tôt pour éviter les flashs au démarrage.
    initrd.kernelModules = [ "amdgpu" ];
    
    # Supprime les messages de texte du noyau au démarrage.
    consoleLogLevel = 0;
    initrd.verbose = false;
    
    # Paramètres magiques pour un démarrage propre, silencieux et en 165Hz.
    kernelParams = [
      "video=2160x1440@165"
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "amdgpu.dcverbose=0"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    # Configuration du bootloader Systemd-boot.
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };

    # Utilise le dernier Kernel stable pour un support optimal de la RX 9070.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.firewall.enable = false;

  # --- RÉSEAU ET SYSTÈME ---
  networking = {
    hostName = "maousse"; # Nom de la machine.
    networkmanager.enable = true; # Active la gestion simplifiée du réseau.
  };
  
  time.timeZone = "Europe/Paris"; # Fuseau horaire.
  
  i18n = {
    defaultLocale = "fr_FR.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "fr_FR.UTF-8";
      LC_IDENTIFICATION = "fr_FR.UTF-8";
      LC_MEASUREMENT = "fr_FR.UTF-8";
      LC_MONETARY = "fr_FR.UTF-8";
      LC_NAME = "fr_FR.UTF-8";
      LC_NUMERIC = "fr_FR.UTF-8";
      LC_PAPER = "fr_FR.UTF-8";
      LC_TELEPHONE = "fr_FR.UTF-8";
      LC_TIME = "fr_FR.UTF-8";
    };
  };
  
  # Autorise les logiciels propriétaires (Steam, drivers, etc.).
  nixpkgs.config.allowUnfree = true;

  # LACT pour contrôle GPU AMD
  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  # Active Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;  # Ouvre les ports pour Remote Play
    dedicatedServer.openFirewall = true;  # Pour les serveurs dédiés
    localNetworkGameTransfers.openFirewall = true;  # Transferts LAN

    # Active Proton-GE
    extraCompatPackages = with pkgs; [
      proton-ge-bin
  ];
  # Force Steam en français
  package = pkgs.steam.override {
    extraEnv = {
      STEAM_FORCE_DESKTOPUI_SCALING = "1";
    };
    extraArgs = "-language french";
  };
  };

  # --- INTERFACE (KDE PLASMA 6) ---
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    videoDrivers = [ "amdgpu" ];
  };
  
  console.keyMap = "us";

  services.xserver.excludePackages = with pkgs; [
    xterm
  ];

  services.desktopManager.plasma6.enable = true;

  # services.desktopManager.plasma6.extraPackages = with pkgs.kdePackages; [
  #   Ajoutez ici d'autres packages KDE si nécessaire
  #];
  
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";

  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;  # Active automatiquement au démarrage
  };

  # Accélération matérielle et support ROCm pour OpenCL.
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Nécessaire pour les jeux 32 bits (Steam).
    extraPackages = with pkgs; [ 
      rocmPackages.clr.icd
      vulkan-loader
      vulkan-validation-layers
    ];
  };

  # --- DÉCOUVERTE RÉSEAU (SMB/NFS) ---
  # Activer Samba et Avahi pour la découverte réseau
  services.samba = {
    enable = true;
    openFirewall = true;
  };

  # Avahi pour la découverte mDNS/Zeroconf
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Support NFS
  services.rpcbind.enable = true;

  # Gvfs pour l'intégration SMB/NFS dans Dolphin/KDE
  services.gvfs.enable = true;

  # --- UTILISATEUR ET PACKAGES ---
  users.users.sinsry = {
    isNormalUser = true;
    description = "Sinsry";
    extraGroups = [ "networkmanager" "wheel" ]; # Wheel permet d'utiliser sudo.
    packages = with pkgs; [ 
      kdePackages.kate 
    ];
  };

  # Utilitaires système installés en natif.
  environment.systemPackages = with pkgs; [
    nvd                       # Pour comparer les versions de NixOS
    libnotify                 # Pour envoyer des bulles de notification
    google-chrome             # Navigateur interne
    meld                      # Pour comparer des fichiers
    cifs-utils                # Pour SMB/CIFS
    samba                     # Client Samba
    nfs-utils                 # Pour NFS
    nil                       # Nix Language Server
    nixfmt                    # Formateur Nix (optionnel)
    psmisc                    # Contient killall, fuser, etc.
    kdePackages.breeze-gtk  # Thème Breeze pour GTK
    kdePackages.partitionmanager
    git
    discord
    heroic
    mangohud
    goverlay
    vulkan-tools
    vlc
    mpv
    ffmpeg
    gamescope
    papirus-icon-theme
    plasma-panel-colorizer
  ];

  programs.firefox = { # Navigateur interne + config fr
    enable = true;
    languagePacks = [ "fr" ];
    preferences = {
      "intl.locale.requested" = "fr";
    };
  };

  # Configuration Git
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        name = "Sinsry";
        email = "Sinsry@users.noreply.github.com";
      };
      credential.helper = "cache --timeout=604800";  # Cache le token 1 semaine
    };
  };


  # --- MISES À JOUR ET NETTOYAGE ---
  # Automatisation des mises à jour système à 4h du matin.
  system.autoUpgrade = {
    enable = true;
    allowReboot = false; # On ne redémarre jamais sans ton accord.
    dates = "04:00";
  };

  # Service de notification pour prévenir quand une mise à jour est prête.
  systemd.services.nixos-upgrade-notification = {
    description = "Notification de mise à jour NixOS intelligente";
    # On le lance après la mise à jour automatique
    after = [ "nixos-upgrade.service" ];
    wantedBy = [ "nixos-upgrade.service" ];
    
    script = ''
      # On compare l'ID de la version actuelle avec celle du lien 'system'
      # Si c'est différent, alors on notifie.
      CURRENT_GEN=$(readlink /run/current-system)
      LATEST_GEN=$(readlink /nix/var/nix/profiles/system)

      if [ "$CURRENT_GEN" != "$LATEST_GEN" ]; then
        ${pkgs.libnotify}/bin/notify-send "NixOS : Mise à jour prête" \
          "Une nouvelle version a été générée. Redémarre quand tu veux pour l'activer." \
          --icon=system-software-update \
          --urgency=normal
      fi
    '';
    
    serviceConfig = {
      Type = "oneshot";
      User = "sinsry";
      Environment = [  # ✅ Liste de variables d'environnement
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };
  };
  # Configuration interne de Nix (Flakes et optimisation).
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true; # Mutualise les fichiers pour gagner de la place.
      download-buffer-size = 134217728; # 128 MB pour des téléchargements plus rapides.
    };
    # Nettoyage automatique des anciennes versions (Garbage Collector).
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d"; # Garde 30 jours d'historique.
    };
  };

  # --- THÈME ET FIN ---
  # Force le thème Plasma sur les applications GTK et Qt.
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };
  
  # Thème de curseur uniforme.
  environment.variables.XCURSOR_THEME = "breeze_cursors";
  
  # Permet aux applications de sauvegarder leurs réglages.
  programs.dconf.enable = true;

  environment.sessionVariables = {
  GTK_THEME = "Breeze-Dark";
  };

  # Rebuild + push alias
  environment.shellAliases = {
    rebuild = ''
      sudo nixos-rebuild switch --flake path:/etc/nixos#maousse
    '';
    nixpush = "cd /etc/nixos && sudo git add . && sudo git commit -m 'Update' && sudo git push";
  };

  # Version de NixOS d'origine (ne pas changer sans lire la doc).
  system.stateVersion = "25.11";
}



