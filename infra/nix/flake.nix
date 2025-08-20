{
  description = "DucksNest Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-generators }:
    let
      # System architectures for each host
      hostSystems = {
        laptop-old = "x86_64-linux";
        laptop-ultra = "x86_64-linux";
        ec2-controlplane = "x86_64-linux";
        ec2-jenkins      = "x86_64-linux"; 
      };
      
      # Overlay for unstable packages
      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable { system = prev.system; };
        })
      ];

      # Function to create NixOS configuration
      mkNixosConfig = hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          
          modules = [
            # Apply overlays globally
            ({ config, pkgs, ... }: {
              nixpkgs.overlays = overlays;
            })
            
            # Import the host-specific configuration
            ./hosts/${hostname}/configuration.nix
          ];
        };

    in {
      # Host configurations
      nixosConfigurations = {
        laptop-old       = mkNixosConfig "laptop-old"       hostSystems.laptop-old;
        laptop-ultra     = mkNixosConfig "laptop-ultra"     hostSystems.laptop-ultra;
        ec2-controlplane = mkNixosConfig "ec2-controlplane" hostSystems.ec2-controlplane;
        ec2-jenkins      = mkNixosConfig "ec2-jenkins"      hostSystems.ec2-jenkins;
      };

      # Default packages for each system
      packages = {
        x86_64-linux.default = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.laptop-old = self.nixosConfigurations.laptop-old.config.system.build.toplevel;
        x86_64-linux.laptop-ultra = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.ec2-controlplane = self.nixosConfigurations.ec2-controlplane.config.system.build.toplevel;
        x86_64-linux.ec2-jenkins = self.nixosConfigurations.ec2-jenkins.config.system.build.toplevel;
      };
    };
}
