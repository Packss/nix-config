{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  # --- Configurações do Nix e Sistema Base ---
  imports = [ ./hardware-configuration.nix ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
  nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
  nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];

  # --- Boot e Kernel ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "acpi_backlight=native"
    "zswap.enabled=1"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
    "pcie_aspm=off"
  ];
  boot.kernelModules = [
    "fuse"
    "ntsync"
  ];

  boot.extraModprobeConfig = ''
    options mt7921e disable_aspm=1
  '';

  # --- Hardware e Gráficos ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
      libva-vdpau-driver
    ];
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = true;
    nvidiaSettings = true;
    #package = config.boot.kernelPackages.nvidiaPackages.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "610.43.02";
      sha256_64bit = "sha256-MDSgVLtM33dS/43CclZMsQVROAS/9TU4lFkBsWyndGM=";
      sha256_aarch64 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      openSha256 = "sha256-hP5NVZZ4vGsACHLmUDKq4uckpd/kn1GxCSYnnJfAuBs=";
      settingsSha256 = "sha256-0YAhufRgjDW+uR+kjaTb154fibpcDw8QowfrucoZsKE=";
      persistencedSha256 = "sha256-Whgv9X+v2fRhzliOl2LzltY9v1SxDafFfv3IUPqj/hk=";
    };
  };

  hardware.nvidia.prime = {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    amdgpuBusId = "PCI:116:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  services.lact.enable = true;

  services.udev.extraRules = ''
    KERNEL=="event[0-9]*", SUBSYSTEM=="input", SUBSYSTEMS=="input", ATTRS{uniq}=="ce:da:84:14:a5:40", SYMLINK+="input/by-id/bluetooth-sofle-keyboard"
    KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput", TAG+="uaccess"
    KERNEL=="uhid", GROUP="input", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*",   ATTRS{name}=="Wolf PS5 (virtual) pad", GROUP="root", MODE="0660", ENV{ID_SEAT}="seat9"
    SUBSYSTEMS=="input", ATTRS{name}=="Wolf X-Box One (virtual) pad", GROUP="root", MODE="0660", ENV{ID_SEAT}="seat9"
    SUBSYSTEMS=="input", ATTRS{name}=="Wolf PS5 (virtual) pad", GROUP="root", MODE="0660", ENV{ID_SEAT}="seat9"
    SUBSYSTEMS=="input", ATTRS{name}=="Wolf gamepad (virtual) motion sensors", GROUP="root", MODE="0660", ENV{ID_SEAT}="seat9"
    SUBSYSTEMS=="input", ATTRS{name}=="Wolf Nintendo (virtual) pad", GROUP="root", MODE="0660", ENV{ID_SEAT}="seat9"
  '';

  # --- Armazenamento e File Systems ---
  fileSystems."/".options = [
    "noatime"
    "compress=zstd"
  ];
  fileSystems."/home".options = [
    "noatime"
    "compress=zstd"
  ];

  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-uuid/4eb277c2-bfa6-4a7a-9b27-ef4d43b1f8ff";
    fsType = "btrfs";
    options = [
      "discard=async"
      "ssd"
      "compress=zstd"
      "user"
      "users"
      "exec"
      "noatime"
      "subvol=@games"
      "nofail"
      "x-gvfs-show"
    ];
  };

  fileSystems."/mnt/projects" = {
    device = "/dev/disk/by-uuid/4eb277c2-bfa6-4a7a-9b27-ef4d43b1f8ff";
    fsType = "btrfs";
    options = [
      "discard=async"
      "ssd"
      "compress=zstd"
      "user"
      "users"
      "exec"
      "noatime"
      "subvol=@projects"
      "nofail"
      "x-gvfs-show"
    ];
  };

  fileSystems."/media/gamedisk" = {
    device = "/dev/nvme0n1p4";
    fsType = "lowntfs-3g";
    options = [
      "nofail"
      "x-gvfs-show"
      "uid=1000"
      "gid=100"
      "rw"
      "user"
      "exec"
      "umask=000"
    ];
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  programs.fuse.enable = true;
  services.fstrim.enable = true;
  services.udisks2.enable = true;
  hardware.block.scheduler."nvme[0-9]*" = "kyber";
  systemd.tmpfiles.rules = [ "d /mnt/games 0755 enzo users -" ];

  # --- Rede e Segurança ---
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.hostName = "ignis-nix";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
  networking.nftables.enable = true;

  networking.interfaces.wlp4s0 = {
    ipv4.addresses = [
      {
        address = "192.168.50.1";
        prefixLength = 24;
      }
    ];
  };
  networking.nat = {
    enable = true;
    externalInterface = "enp3s0";
    #externalInterface = "enp117s0f3u1";
    internalInterfaces = [ "wlp4s0" ];
  };
  services.tailscale.enable = true;
  services.dnsmasq = {
    enable = false;
    settings = {
      interface = "wlp4s0";
      dhcp-range = [ "192.168.50.10,192.168.50.250,255.255.255.0,12h" ];
      dhcp-option = [
        "3,192.168.50.1"
        "6,8.8.8.8,1.1.1.1"
      ];
    };
  };
  systemd.services.tailscaled.serviceConfig.Environment = [ "TS_DEBUG_FIREWALL_MODE=nftables" ];
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;

  services.avahi = {
    enable = true;
    hostName = "ignis-nix";
    openFirewall = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish.enable = true;
    publish.userServices = true;
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "tailscale0"
      "wlp4s0"
    ];
    allowedUDPPorts = [
      config.services.tailscale.port
      5201
      10400
      10401
      27031
      27036
      25565
      48998
      47999
      48000
      48100
      48200
      9757
    ];
    allowedTCPPorts = [
      5201
      27036
      27037
      25565
      47984
      47989
      48010
      9757
    ];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ]; # KDE Connect
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ]; # KDE Connect
    interfaces."wlp4s0" = {
      allowedUDPPorts = [
        53
        67
      ];
      allowedTCPPorts = [ 53 ];
    };
  };

  systemd.services.smbd = {
    serviceConfig = {
      # 1. Turn off strict home directory masking for this service
      ProtectHome = "no";

      # 2. Ensure any mounts made on the host propagate down into the service namespace
      MountFlags = "shared";

      # 3. Alternatively, if it still hides the mount, explicitly include your path:
      ReadWritePaths = [
        "/home/enzo/"
        "/mnt/games/"
      ];
      BindPaths = [ "/home/enzo/Vaults/Vault/:/home/enzo/mnt/" ];
    };
  };
  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
    settings = {
      global = {
        "unix extensions" = "no";
      };
      "games" = {
        "path" = "/mnt/games/";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "enzo";
      };
      "home-enzo" = {
        "path" = "/home/enzo/";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "enzo";
        "follow symlinks" = "yes";
        "wide links" = "yes";
      };
    };
  };
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.allowPing = true;

  # --- Localização e Internacionalização ---
  time.timeZone = "America/Sao_Paulo";
  time.hardwareClockInLocalTime = true;
  i18n.defaultLocale = "pt_BR.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };
  services.xserver.xkb.layout = "us";
  environment.sessionVariables.TZ = "America/Sao_Paulo";

  # --- Usuários ---
  users.users.samira = {
    isNormalUser = true;
    extraGroups = [
      "i2c"
      "wheel"
      "input"
      "networkmanager"
      "plugdev"
      "libvirtd"
      "kvm"
      "video"
      "render"
    ];
  };

  users.users.enzo = {
    isNormalUser = true;
    extraGroups = [
      "i2c"
      "wheel"
      "input"
      "networkmanager"
      "plugdev"
      "libvirtd"
      "kvm"
      "video"
      "render"
      "uinput"
    ];
  };

  # --- Serviços do Sistema ---
  services.printing.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  services.libinput.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  services.openssh.enable = true;
  services.flatpak.enable = true;

  # --- Interface e Ambiente de Desktop ---
  services.desktopManager.cosmic.enable = true;
  programs.niri.enable = true;
  programs.xwayland.enable = true;

  programs.dms-shell = {
    enable = true;
    quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    systemd = {
      enable = false;
      restartIfChanged = true;
    };
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableClipboardPaste = true;
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    fira-code
    nerd-fonts.noto
    nerd-fonts.fira-code
  ];

  # --- Virtualização e Containers ---
  virtualisation = {
    containers.enable = true;
    docker = {
      enable = true;
      enableNvidia = true;
      rootless.enable = true;
    };
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enable = true;
    };
  };

  programs.virt-manager.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # --- Gaming e Ferramentas ---
  programs.steam = {
    enable = false;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    extraPackages = [ pkgs.sdl2-compat ];
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };

  # --- Pacotes e Wrappers ---
  environment.localBinInPath = true;
  environment.systemPackages = with pkgs; [
    gnome-disk-utility
    steam-run
    ntfs3g
    cage
    libappindicator
    wayvr
    xrizer
    android-tools
    xrizer
    waypipe
    qemu
    ryzenadj
    ddcutil
    gcc
    vim
    wget
    foot
    fuzzel
    brightnessctl
    xwayland-satellite
    distrobox
    crun
    wl-clipboard-rs
    oversteer
    linux-wifi-hotspot
    iw
    haveged
    hostapd
    iperf3
    lsfg-vk
    lsfg-vk-ui
    inputs.helium.packages.${system}.default
    openvpn
    ntfsprogs-plus
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # --- Especialização: GPU Passthrough ---
  specialisation.passthrough.configuration = {
    boot.initrd.kernelModules = [
      "vfio_pci"
      "vfio"
      "mdev"
      "vfio_iommu_type1"
    ];
    boot.kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "vfio_pci"
      "vfio"
      "mdev"
      "vfio-pci.ids=10de:24a0,10de:228b"
    ];

    virtualisation.spiceUSBRedirection.enable = true;
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    systemd.tmpfiles.rules = [ ''f /dev/shm/kvmfr-* 0660 "enzo" kvm -'' ];

    services.persistent-evdev = {
      enable = true;
      devices = {
        sofle-keyboard = "bluetooth-sofle-keyboard";
        ajazz-mouse1 = "usb-Compx_AJAZZ_2.4G-if02-event-mouse";
        g29-wheel = "usb-Logitech_G29_Driving_Force_Racing_Wheel-event-joystick";
      };
    };
  };
}
