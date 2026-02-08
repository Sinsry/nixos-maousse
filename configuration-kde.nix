{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./network-mounts.nix
    ./disks-mounts.nix
  ];
  #==== Overlay Mesa (temporaire) ====
  nixpkgs.overlays = [
    (self: super: {
      mesa = super.mesa.overrideAttrs (oldAttrs: rec {
        version = "26.0.0-rc3";
        src = super.fetchurl {
          urls = [
            "https://archive.mesa3d.org/mesa-${version}.tar.xz"
            "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
          ];
          ## calcul du hash : nix-prefetch-url https://archive.mesa3d.org/mesa-${version}.tar.xz
          sha256 = "1mjhmsb2l52q6gzl2q5q89iiwirh0i6hzl5hvb7gy9dmkfqhy0f0";
        };
        ##== retrait d'un patch
        patches = builtins.filter (p: !(builtins.match ".*musl.patch" (toString p) != null)) (
          oldAttrs.patches or [ ]
        );
        ##== retrait d'un patch
      });
    })
  ];

  #==== Boot ====
  boot = {
    initrd.kernelModules = [ "amdgpu" ];
    initrd.systemd.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "video=2160x1440@165"
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "amdgpu.dcverbose=0"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "intel_iommu=on"
    ];
    kernel.sysctl = {
      "kernel.split_lock_mitigate" = 0;
    };
    kernelModules = [
      "ntsync"
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
    ];
    supportedFilesystems = [
      "ntfs"
      "exfat"
      "vfat"
      "ext4"
      "btrfs"
    ];
    loader = {
      timeout = 0;
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
    #kernelPackages = pkgs.linuxPackages_latest;
    #kernelPackages = pkgs.linuxPackages_lqx;
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
  };

  #==== Réseau ====
  networking = {
    hostName = "maousse";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  #==== Services Systemd ====
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    samba-smbd.wantedBy = lib.mkForce [ ];
    samba-nmbd.wantedBy = lib.mkForce [ ];
    samba-winbindd.wantedBy = lib.mkForce [ ];
    nixos-upgrade-notification = {
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
  };

  #==== Localisation ====
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
  console.keyMap = "us";
  nixpkgs.config.allowUnfree = true;

  #==== Matériel ====
  hardware = {
    amdgpu.overdrive.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    xpadneo.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
        vulkan-loader
        vulkan-validation-layers
      ];
    };
  };

  #==== Services ====
  services = {
    lact.enable = true;
    xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = [ "amdgpu" ];
      excludePackages = with pkgs; [ xterm ];
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "breeze";
      extraPackages = with pkgs; [ papirus-icon-theme ];
    };
    samba = {
      enable = true;
      openFirewall = true;
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
    rpcbind.enable = true;
    gvfs.enable = true;
    desktopManager.plasma6.enable = true;
    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
  };
  virtualisation.libvirtd = {
    enable = true;
      qemu = {
        swtpm.enable = true;
      };
    qemu.vhostUserPackages = with pkgs; [
      virtiofsd
    ];
  };

  #==== Programmes ====
  programs = {
    gamemode = {
      enable = true;
      enableRenice = true;
      settings = {
        general = {
          renice = 10;
        };
      };
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
      package = pkgs.steam.override {
        extraEnv = {
          STEAM_FORCE_DESKTOPUI_SCALING = "1";
        };
        extraArgs = "-language french";
      };
    };
    firefox = {
      enable = true;
      languagePacks = [ "fr" ];
      preferences = {
        "intl.locale.requested" = "fr";
      };
      nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
    };
    chromium = {
      enable = true;
      extraOpts = {
        "NativeMessagingHosts" = {
          "org.kde.plasma.browser_integration" =
            "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
        };
      };
    };
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-ceintl.vscode-language-pack-fr
        anthropic.claude-code
        jnoortheen.nix-ide
      ];
    };
    git = {
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
    ssh = {
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
      ];
    };
    dconf.enable = true;
    bash = {
      completion.enable = true;
      interactiveShellInit = ''
        fastfetch
      '';
    };
    virt-manager.enable = true;
  };

  #==== Utilisateurs ====
  users.users.sinsry = {
    isNormalUser = true;
    description = "Sinsry";
    extraGroups = [
      "networkmanager"
      "wheel"
      "gamemode"
      "libvirtd"
    ];
  };

  #==== Sécurité ====
  security.pam.loginLimits = [
    {
      domain = "@gamemode";
      type = "-";
      item = "nice";
      value = "-20"; # Permet de mettre la priorité jusqu'à -20
    }
  ];

  #==== Environnement ====
  environment = {
    systemPackages = with pkgs; [
      cifs-utils
      discord
      dnsmasq
      fastfetch
      faugus-launcher
      ffmpeg
      google-chrome
      goverlay
      kdePackages.breeze-gtk
      kdePackages.filelight
      kdePackages.kate
      kdePackages.ksshaskpass
      kdePackages.partitionmanager
      kdePackages.plasma-browser-integration
      kdePackages.qtwebengine
      libnotify
      usbutils
      mangohud
      meld
      mpv
      nfs-utils
      nil
      nixd
      nixfmt
      nvd
      papirus-icon-theme
      pciutils
      protonvpn-gui
      psmisc
      rar
      rsync
      vlc
      vorta
      vulkan-tools
      wowup-cf
      (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
        [General]
        background=/etc/nixos/asset/wallpaper.png
      '')
      (pkgs.writeTextDir "etc/xdg/kdeglobals" ''
        [Icons]
        Theme=Papirus-Dark
      '')
    ];
    #    plasma6.excludePackages = with pkgs; [
    #   ];

    sessionVariables = {
      GDK_BACKEND= "x11";
      GTK_THEME = "Breeze-Dark";
      SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
      SSH_ASKPASS_REQUIRE = "prefer";
    };
    shellAliases = {
      nixrebuild = "sudo nixos-rebuild switch --flake path:/etc/nixos#maousse";
      nixupdate = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake path:/etc/nixos#maousse && cd ~/";
      nixpush = "cd /etc/nixos && sudo git add . && (sudo git commit -m 'Update' || true ) && sudo git push && cd ~/";
      nixlistenv = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nixgarbage = "sudo nix-collect-garbage -d && sudo nixos-rebuild boot";
    };
    etc = {
      "libinput/local-overrides.quirks".source = ./asset/local-overrides.quirks;
      "inputrc".text = ''
        set completion-ignore-case on
        set show-all-if-ambiguous on
        set completion-map-case on
      '';
    };
  };

  #==== Système ====
  system = {
    activationScripts.binbash = ''
      mkdir -p /bin
      ln -sf ${pkgs.bash}/bin/bash /bin/bash
    '';
    autoUpgrade = {
      enable = true;
      allowReboot = false;
      dates = "22:00";
    };
    stateVersion = "25.11";
  };

  #==== Swap ====
  zramSwap = {
    enable = true;
    memoryPercent = 12;
  };

  #==== Nix ====
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
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

  #==== Qt ====
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };
}