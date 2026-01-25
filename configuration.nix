{ _config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./network-mounts.nix
    ./disks-mounts.nix
  ];

#==========================================================================
#==========================================================================
#==========================================================================
#==============================+++++=======================================



  nixpkgs.overlays = [
    (self: super: {
      mesa = super.mesa.overrideAttrs (oldAttrs: rec {
        version = "26.0.0-rc1";
        src = super.fetchurl {
          urls = [
            "https://archive.mesa3d.org/mesa-${version}.tar.xz"
            "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
          ];
          sha256 = "0i4ynz01vdv4lmiv8r58i0vjaj2d71lk5lw6r0wjzsldjl06zrrx";
        };

        ##== retrais d'un patch
        patches = builtins.filter (p:
        !(builtins.match ".*musl.patch" (toString p) != null)
      ) (oldAttrs.patches or []);
      ##==


      });
    })
  ];

#==========================================================================
#==========================================================================
#==========================================================================
#==========================================================================



  boot = {
    initrd.kernelModules = [ "amdgpu" ];
    consoleLogLevel = 0;
    initrd.verbose = false;
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

    kernelModules = [
      "ntsync"
    ];

    supportedFilesystems = [
      "ntfs"
      "exfat"
      "vfat"
      "ext4"
      "btrfs"
    ];

    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };

      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking.firewall.enable = false;
  networking = {
    hostName = "maousse";
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Paris";
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

  nixpkgs.config.allowUnfree = true;

  services.lact.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;  # Ouvre les ports pour Remote Play
    dedicatedServer.openFirewall = true;  # Pour les serveurs dédiés
    localNetworkGameTransfers.openFirewall = true;  # Transferts LAN
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];

    package = pkgs.steam.override {
      extraEnv = {
        STEAM_FORCE_DESKTOPUI_SCALING = "1";
      };
      extraArgs = "-language french";
    };
  };

  services.xserver = {
    enable = true;
    xkb.layout = "us";
    videoDrivers = [ "amdgpu" ];
  };
  
  console.keyMap = "us";

  services.xserver.excludePackages = with pkgs; [
    xterm
  ];

 services.displayManager.sddm = {
    enable = true;
     wayland.enable = true;
     theme = "breeze";

     extraPackages = with pkgs; [
     papirus-icon-theme
     ];

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
  };

  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    ntfs3g
    exfatprogs
    nvd
    rar
    libnotify
    google-chrome
    meld
    cifs-utils
    samba
    nfs-utils
    nil
    nixfmt
    psmisc
    git
    discord
    heroic
    mangohud
    goverlay
    vulkan-tools
    vlc
    mpv
    ffmpeg
    papirus-icon-theme
    wowup-cf
    fastfetch
    rsync
    vorta
    protonvpn-gui
    kdePackages.kate
    kdePackages.breeze-gtk
    kdePackages.partitionmanager
    kdePackages.filelight
    kdePackages.plasma-browser-integration

    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=/etc/nixos/asset/maousse/wallpaper-sddm.png
     '')
    (pkgs.writeTextDir "etc/xdg/kdeglobals" ''
      [Icons]
      Theme=Papirus-Dark
    '')
  ];

  programs.firefox = {
    enable = true;
    languagePacks = [ "fr" ];
    preferences = {
      "intl.locale.requested" = "fr";
    };
    nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
  };



  programs.chromium = {
  enable = true;
  extraOpts = {
    "NativeMessagingHosts" = {
      "org.kde.plasma.browser_integration" = "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
    };
  };
};

  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        name = "Sinsry";
        email = "Sinsry@users.noreply.github.com";
      };
      credential.helper = "cache --timeout=604800";
    };
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "22:00";
  };

  systemd.services.nixos-upgrade-notification = {
    description = "Notification de mise à jour NixOS intelligente";
    after = [ "nixos-upgrade.service" ];
    wantedBy = [ "nixos-upgrade.service" ];

    script = ''
      CURRENT_GEN=$(readlink /run/current-system)
      LATEST_GEN=$(readlink /nix/var/nix/profiles/system)

      if [ "$CURRENT_GEN" != "$LATEST_GEN" ]; then
        ${pkgs.libnotify}/bin/notify-send "NixOS : Mise à jour prête" \
          "Mise à jour effectuée." \
          --icon=system-software-update \
          --urgency=normal
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      User = "sinsry";
      Environment = [
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 12;
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      download-buffer-size = 1073741824;
      max-jobs = "auto";
      cores = 0;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 15d";
    };
  };

  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  environment.variables = {
    XCURSOR_THEME = "breeze_cursors";
    QT_QPA_PLATFORMTHEME = "kde";
  };

  programs.dconf.enable = true;

  environment.sessionVariables = {
    GTK_THEME = "Breeze-Dark";
  };


  environment.shellAliases = {
    rebuild = ''
      sudo nixos-rebuild switch --flake path:/etc/nixos#maousse
    '';
    nixpush = "cd /etc/nixos && sudo git add . && sudo git commit -m 'Update' && sudo git push";
  };

  environment.etc."libinput/local-overrides.quirks".source = ./asset/maousse/local-overrides.quirks;

  environment.etc."inputrc".text = ''
    set completion-ignore-case on
    set show-all-if-ambiguous on
    set completion-map-case on
  '';

  programs.bash.interactiveShellInit = ''
    fastfetch
  '';

  system.stateVersion = "25.11";
}
