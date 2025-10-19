{
  description = "DucksNest Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    k8nix-cert-management = {
      url = "path:../k8nix-cert-management";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-generators, agenix, k8nix-cert-management }:
    let
      # System architectures for each host
      hostSystems = {
        laptop-old = "x86_64-linux";
        laptop-ultra = "x86_64-linux";
        laptop-firebat = "x86_64-linux";
        ec2-controlplane = "x86_64-linux";
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

          specialArgs = {
            inherit agenix k8nix-cert-management;
          };

          modules = [
            # Apply overlays globally
            ({ config, pkgs, ... }: {
              nixpkgs.overlays = overlays;
            })

            # Agenix module for secret management
            agenix.nixosModules.default

            # CertToolkit module for certificate management
            k8nix-cert-management.nixosModules.certToolkit

            # Shared CA definitions
            ./modules/certs/ca.nix

            # Import the host-specific configuration
            ./hosts/${hostname}/configuration.nix
          ];
        };

    in {
      # Host configurations
      nixosConfigurations = {
        laptop-old       = mkNixosConfig "laptop-old"       hostSystems.laptop-old;
        laptop-ultra     = mkNixosConfig "laptop-ultra"     hostSystems.laptop-ultra;
        laptop-firebat   = mkNixosConfig "laptop-firebat"   hostSystems.laptop-firebat;
        ec2-controlplane = mkNixosConfig "ec2-controlplane" hostSystems.ec2-controlplane;
      };

      # Certificate management apps
      apps.x86_64-linux.certs.recreate = k8nix-cert-management.mkRecreateCertsApp {
        system = "x86_64-linux";
        nixosConfigurations = self.nixosConfigurations;
        caModules = [ ./modules/certs/ca.nix ];
      };

      # Default packages for each system
      packages = {
        x86_64-linux.default = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.laptop-old = self.nixosConfigurations.laptop-old.config.system.build.toplevel;
        x86_64-linux.laptop-ultra = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.laptop-firebat = self.nixosConfigurations.laptop-firebat.config.system.build.toplevel;
        x86_64-linux.ec2-controlplane = self.nixosConfigurations.ec2-controlplane.config.system.build.toplevel;
      };
    };
}
