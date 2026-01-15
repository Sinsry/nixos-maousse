{ _config, _pkgs, ... }:

{
  # Assurer que les points de montage existent
  systemd.tmpfiles.rules = [
    "d /mnt/Data 0755 root root -"
    "d /mnt/Torrents 0755 root root -"
  ];

  # Configuration des montages NFS
  fileSystems."/mnt/Data" = {
    device = "192.168.1.2:/mnt/NAS/Data";
    fsType = "nfs";
    options = [
      "_netdev"
      "v4"
      "x-systemd.automount"
      "x-systemd.mount-timeout=1s"
      "timeo=14"
      "retrans=2"
      "nolock"
      "soft"
    ];
  };

  fileSystems."/mnt/Torrents" = {
    device = "192.168.1.2:/mnt/NAS/Torrents";
    fsType = "nfs";
    options = [
      "_netdev"
      "v4"
      "x-systemd.automount"
      "x-systemd.mount-timeout=1s"
      "timeo=14"
      "retrans=2"
      "nolock"
      "soft"
    ];
  };
}
