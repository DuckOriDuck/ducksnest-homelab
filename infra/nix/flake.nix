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
        aarch64-linux.default = self.nixosConfigurations.ec2-controlplane.config.system.build.toplevel;
        modules = [
            {
              # nix.registry.nixpkgs.flake = nixpkgs;
              virtualisation.diskSize = 10 * 1024;
            };
        # EC2 AMI images (available on both x86_64 and aarch64)
        x86_64-linux.ec2-controlplane-ami = nixos-generators.nixosGenerate {
          system  = "x86_64-linux";
          modules = [ ./hosts/ec2-controlplane/configuration.nix ];
          format = "amazon";
        };
        
        x86_64-linux.ec2-jenkins-ami = nixos-generators.nixosGenerate {
          system  = "x86_64-linux";
          modules = [ ./hosts/ec2-jenkins/configuration.nix ];
          format = "amazon";
        };
      };
    };
}
