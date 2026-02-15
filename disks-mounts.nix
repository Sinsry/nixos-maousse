{
  #==== Montages disques ====
  fileSystems = {
    # Clé USB Ventoy
    "/mnt/Ventoy" = {
      device = "/dev/disk/by-uuid/4E21-0000";
      fsType = "exfat";
      options = [
        "nofail"
        "rw"
        "umask=0000"
        "uid=1000"
        "gid=100"
      ];
    };

    # Partition Windows
    "/mnt/Windows" = {
      device = "/dev/disk/by-uuid/90B4C5E3B4C5CBC2";
      fsType = "ntfs";
      options = [
        "nofail"
        "noperm"
      ];
    };

    # Partition Data Windows
    "/mnt/Data_Windows" = {
      device = "/dev/disk/by-uuid/D8CA1469CA1445E2";
      fsType = "ntfs";
      options = [
        "nofail"
        "noperm"
      ];
    };

    # Partition Jeux (ext4)
    "/home/sinsry/Jeux" = {
      device = "/dev/disk/by-uuid/c5f40b61-d064-468c-932a-c3460bc762ed";
      fsType = "ext4";
      options = [
        "nofail"
        "discard"
      ];
    };
  };

  #==== Création des points de montage ====
  systemd.tmpfiles.rules = [
    "d /mnt/Ventoy 0755 root root -"
    "d /mnt/Windows 0755 root root -"
    "d /mnt/Data_Windows 0755 root root -"
    "d /home/sinsry/Jeux 0755 sinsry users -"
  ];
}
