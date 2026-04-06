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
      ...
    }@inputs:
    {
      nixosConfigurations.ignis-nix = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          acer-predator.nixosModules.default
          {
            hardware.acer-predator.enable = true;
          }
          linux-nitrosense.nixosModules.default
          {
            services.linux-nitrosense.enable = true;
          }
          nixpkgs-xr.nixosModules.nixpkgs-xr
          ./configuration.nix
        ];
      };
    };
}
