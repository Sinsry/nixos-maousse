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
  # nixpkgs.overlays = [
  #   (self: super: {
  #     mesa = super.mesa.overrideAttrs (oldAttrs: rec {
  #       version = "26.0.0";
  #       src = super.fetchurl {
  #         urls = [
  #           "https://archive.mesa3d.org/mesa-${version}.tar.xz"
  #           "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
  #         ];
  #         ## calcul du hash : nix-prefetch-url https://archive.mesa3d.org/mesa-${version}.tar.xz
  #         sha256 = "0wizyf2amz589cv3anz27rq69zvyxk8f4gb3ckn6rhymcj7fji1a";
  #       };
  #       ##== retrait d'un patch
  #       #patches = builtins.filter (p: !(builtins.match ".*musl.patch" (toString p) != null)) (
  #       #  oldAttrs.patches or [ ]
  #       #);
  #       ##== retrait d'un patch
  #     });
  #   })
  # ];

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
    kernelPackages = pkgs.linuxPackages_latest;
    #kernelPackages = pkgs.linuxPackages_lqx;
    #kernelPackages = pkgs.linuxPackages_xanmod_latest;
    #kernelPackages = pkgs.linuxPackages_testing;
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
      description = "Mise à jour NixOS";
      after = [ "nixos-upgrade.service" ];
      wantedBy = [ "nixos-upgrade.service" ];
      path = with pkgs; [
        coreutils
        libnotify
      ];
      script = ''
        CURRENT_GEN=$(readlink -f /run/current-system)
        LATEST_GEN=$(readlink -f /nix/var/nix/profiles/system)
        LOCK_FILE="/tmp/nixos-upgrade-notification/notified"
        if [ "$CURRENT_GEN" != "$LATEST_GEN" ]; then
          mkdir -p /tmp/nixos-upgrade-notification
          if [ ! -f "$LOCK_FILE" ] || [ "$(cat "$LOCK_FILE" 2>/dev/null)" != "$LATEST_GEN" ]; then
            notify-send "NixOS : Mise à jour prête" "Mise à jour effectuée. Redémarrage recommandé pour appliquer les changements." --icon=system-software-update --urgency=critical --expire-time=0 --category=system
            echo "$LATEST_GEN" > "$LOCK_FILE"
          fi
        else
          rm -f "$LOCK_FILE"
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
    partition-manager = {
      enable = true;
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
        commit.template = pkgs.writeText "commit-template" ''
          Update 
        '';
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
      dualsensectl
      fastfetch
      faugus-launcher
      ffmpeg
      google-chrome
      goverlay
      jq
      kdePackages.breeze-gtk
      kdePackages.filelight
      kdePackages.kate
      kdePackages.ksshaskpass
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
      stoat-desktop
      vlc
      virt-v2v
      vorta
      vulkan-tools
      unzip
      wowup-cf
      #====== pour SVW
      # gst_all_1.gstreamer
      # gst_all_1.gst-vaapi
      # gst_all_1.gst-plugins-base
      # gst_all_1.gst-plugins-good
      # gst_all_1.gst-plugins-bad
      # gst_all_1.gst-plugins-ugly
      # gst_all_1.gst-libav
      # qt6.qtmultimedia
      #====== pour SVW
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
      GDK_BACKEND = "x11";
      GTK_THEME = "Breeze-Dark";
      SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
      SSH_ASKPASS_REQUIRE = "prefer";
      # QT_MEDIA_BACKEND = "gstreamer";
    };
    shellAliases = {
      nixrebuild = "sudo nixos-rebuild switch --flake path:/etc/nixos#maousse";
      nixupdate = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake path:/etc/nixos#maousse && cd ~/";
      nixpush = "cd /etc/nixos && sudo git add . && (sudo git commit -m 'Update' || true ) && sudo git push && cd ~/";
      nixlistenv = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nixgarbage = "sudo nix-collect-garbage -d && sudo nixos-rebuild boot";
      nixcheck = "git ls-remote https://github.com/NixOS/nixpkgs nixos-unstable | cut -c1-7 && nix flake metadata --json path:/etc/nixos | jq -r .locks.nodes.nixpkgs.locked.rev | cut -c1-7";
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
      flake = "/etc/nixos#maousse";
      dates = "hourly";
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
