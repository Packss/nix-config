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
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernelParams = [
    "acpi_backlight=native"
    "zswap.enabled=1"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
  ];

  services.udev.extraRules = ''
    KERNEL=="event[0-9]*", SUBSYSTEM=="input", SUBSYSTEMS=="input", ATTRS{uniq}=="ce:da:84:14:a5:40", SYMLINK+="input/by-id/bluetooth-sofle-keyboard"
  '';
  services.logind.settings.Login = {
    KillUserProcesses = false;
  };
  specialisation = {
    passthrough.configuration = {
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
      systemd.tmpfiles.rules = [
        ''f /dev/shm/kvmfr-* 0660 "enzo" kvm -''
      ];
      services.persistent-evdev = {
        enable = true;
        devices = {
          sofle-keyboard = "bluetooth-sofle-keyboard";
          ajazz-mouse1 = "usb-Compx_AJAZZ_2.4G-if02-event-mouse";
          g29-wheel = "usb-Logitech_G29_Driving_Force_Racing_Wheel-event-joystick";
        };
      };
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.graphics.enable = true;
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
    #package = config.boot.kernelPackages.nvidiaPackages.beta;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "595.45.04";
      sha256_64bit = "sha256-zUllSSRsuio7dSkcbBTuxF+dN12d6jEPE0WgGvVOj14=";
      sha256_aarch64 = "sha256-jl6lQWsgF6ya22sAhYPpERJ9r+wjnWzbGnINDpUMzsk=";
      openSha256 = "sha256-uqNfImwTKhK8gncUdP1TPp0D6Gog4MSeIJMZQiJWDoE=";
      settingsSha256 = "sha256-Y45pryyM+6ZTJyRaRF3LMKaiIWxB5gF5gGEEcQVr9nA=";
      persistencedSha256 = "sha256-5FoeUaRRMBIPEWGy4Uo0Aho39KXmjzQsuAD9m/XkNpA=";
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
  hardware.block.scheduler = {
    "nvme[0-9]*" = "kyber";
  };

  services.fstrim.enable = true;
  programs.fuse.enable = true;
  services.udisks2.enable = true;
  programs.gnome-disks.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.virt-manager.enable = true;
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enable = true;
    };
  };
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
  systemd.tmpfiles.rules = [
    "d /mnt/games 0755 enzo users -"
  ];
  networking.hostName = "ignis-nix"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";
  time.hardwareClockInLocalTime = true;
  environment.sessionVariables = {
    TZ = "America/Sao_Paulo";
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "pt_BR.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
    ]; # Enable ‘sudo’ for the user.
  };

  programs = {
    firefox.enable = true;
    xwayland.enable = true;
    dsearch = {
      enable = true;
      systemd = {
        enable = true;
        target = "default.target";
      };
    };
    gamescope = {
      enable = true;
      capSysNice = false;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    gamemode = {
      enable = true;
      enableRenice = true;
    };
  };
  services.wivrn = {
    enable = true;
    autoStart = true;
    highPriority = true;
    openFirewall = true;
    defaultRuntime = true;
    steam.importOXRRuntimes = true;
  };

  programs.niri.enable = true;
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
    enableCalendarEvents = false;
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

  environment.localBinInPath = true;
  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    qemu
    ryzenadj
    ddcutil
    gcc
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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
  services.flatpak.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    fira-code
    nerd-fonts.noto
    nerd-fonts.fira-code
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.upower.enable = true;
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };
  services.power-profiles-daemon.enable = true;
  services.auto-cpufreq = {
    enable = false;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "ondemand";
        turbo = "auto";
      };
    };
  };
  services.avahi = {
    enable = true;
    hostName = "ignis-nix";
    openFirewall = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish.enable = true;
    publish.userServices = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      } # KDE Connect
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      } # KDE Connect
    ];
  };
  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
