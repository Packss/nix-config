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

  # --- Boot e Kernel ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelParams = [
    "acpi_backlight=native"
    "zswap.enabled=1"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
  ];

  # --- Hardware e Gráficos ---
  hardware.graphics.enable = true;
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
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "595.58.03";
      sha256_64bit = "sha256-jA1Plnt5MsSrVxQnKu6BAzkrCnAskq+lVRdtNiBYKfk=";
      sha256_aarch64 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      openSha256 = "sha256-6LvJyT0cMXGS290Dh8hd9rc+nYZqBzDIlItOFk8S4n8=";
      settingsSha256 = "sha256-2vLF5Evl2D6tRQJo0uUyY3tpWqjvJQ0/Rpxan3NOD3c=";
      persistencedSha256 = "sha256-AtjM/ml/ngZil8DMYNH+P111ohuk9mWw5t4z7CHjPWw=";
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

  services.udev.extraRules = ''
    KERNEL=="event[0-9]*", SUBSYSTEM=="input", SUBSYSTEMS=="input", ATTRS{uniq}=="ce:da:84:14:a5:40", SYMLINK+="input/by-id/bluetooth-sofle-keyboard"
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

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  services.fstrim.enable = true;
  services.udisks2.enable = true;
  hardware.block.scheduler."nvme[0-9]*" = "kyber";
  systemd.tmpfiles.rules = [ "d /mnt/games 0755 enzo users -" ];

  # --- Rede e Segurança ---
  networking.hostName = "ignis-nix";
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  services.tailscale.enable = true;
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
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
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
  };

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
  programs.niri.enable = true;
  programs.xwayland.enable = true;

  programs.dms-shell = {
    enable = true;
    quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    systemd = {
      enable = true;
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
  programs.steam =
    let
      patchedBwrap = pkgs.bubblewrap.overrideAttrs (o: {
        patches = (o.patches or [ ]) ++ [
          ./bwrap-cap-nice.patch
        ];
      });
    in
    {
      enable = true;
      remotePlay.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
        proton-ge-rtsp-bin
      ];
      package = pkgs.steam.override {
        buildFHSEnv = (
          args:
          (
            (pkgs.buildFHSEnv.override {
              bubblewrap = patchedBwrap;
            })
            (
              args
              // {
                extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [ "--cap-add ALL" ];
              }
            )
          )
        );
      };
    };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };

  services.wivrn = {
    enable = true;
    highPriority = true;
    openFirewall = true;
    steam.importOXRRuntimes = true;
    package = (pkgs.wivrn.override { cudaSupport = true; });
  };

  # --- Pacotes e Wrappers ---
  environment.localBinInPath = true;
  environment.systemPackages = with pkgs; [
    wayvr
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
