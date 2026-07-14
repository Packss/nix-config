{
  inputs = {
    # This is pointing to an unstable release.
    # If you prefer a stable release instead, you can this to the latest number shown here: https://nixos.org/download
    # i.e. nixos-24.11
    # Use `nix flake update` to update the flake to the latest revision of the chosen release channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    acer-predator.url = "github:Packss/acer-kb-module-flake";
    # linux-nitrosense.url = "github:Packss/linux-nitrosense-rust";
    linux-nitrosense.url = "path:/mnt/projects/build/linux-nitrosense-rust";
    dmemcg-booster.url = "path:/mnt/projects/build/dmemcg-booster";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    stability-matrix-nix.url = "github:SmarakNayak/stability-matrix-nix";
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
      inputs.nixpkgs.follows = "nixpkgs"; # this line is optional, prevents downloading two versions of nixpkgs but disables cache
    };
    helium = {
      url = "github:AlvaroParker/helium-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      nixpkgs-xr,
      acer-predator,
      linux-nitrosense,
      dmemcg-booster,
      nix-cachyos-kernel,
      helium,
      ...
    }@inputs:
    {
      nixosConfigurations.ignis-nix = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          (
            { pkgs, ... }:
            {
              nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ];
            }
          )
          acer-predator.nixosModules.default
          {
            hardware.acer-predator.enable = true;
          }
          linux-nitrosense.nixosModules.default
          {
            services.linux-nitrosense.enable = true;
          }
          dmemcg-booster.nixosModules.default
          {
            services.dmemcg-booster.enable = true;
            services.dmemcg-booster.startAtBoot = true;
          }
          nixpkgs-xr.nixosModules.nixpkgs-xr
          ./configuration.nix
        ];
      };
    };
}
