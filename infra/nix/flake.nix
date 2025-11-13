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
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-generators, agenix }:
    let

      hostSystems = {
        laptop-old = "x86_64-linux";
        laptop-ultra = "x86_64-linux";
        laptop-firebat = "x86_64-linux";
        ec2-controlplane = "x86_64-linux";
        test-controlplane = "x86_64-linux";
        test-worker-node = "x86_64-linux";
      };

      k8sRoles = {
        laptop-old = "worker";
        laptop-ultra = "worker";
        laptop-firebat = "worker";
        ec2-controlplane = "control-plane";
        test-controlplane = "control-plane";
        test-worker-node = "worker";
      };

      overlays = [
        (final: prev: {
          unstable = import nixpkgs-unstable { system = prev.system; };
        })
      ];


      certToolkitModule = import ./modules/cert-toolkit;
      
      mkRecreateCertsScript = { nixosConfigurations, system }: let
        pkgs = import nixpkgs { inherit system; };
        lib = nixpkgs.lib;
      in pkgs.writeShellScriptBin "recreate-certs" ''
        ${lib.pipe nixosConfigurations [
          lib.attrValues
          (map (cfg: lib.attrValues cfg.config.certToolkit.cas))
          lib.concatLists
          (map (ca: [ca.ca] ++ (lib.attrValues ca.certs)))
          lib.concatLists
          (map (cert: cert.createScript))
          (lib.strings.concatStringsSep "\n")
        ]}
      '';

      mkRecreateCertsApp = args: {
        type = "app";
        program = "${mkRecreateCertsScript args}/bin/recreate-certs";
      };

      mkNixosConfig = hostname: system: role:
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit agenix self;
            k8sRole = role;
            flakeRoot = self;
          };

          modules = [
            ({ config, pkgs, ... }: {
              nixpkgs.overlays = overlays;
            })
            agenix.nixosModules.default
            certToolkitModule
            ./hosts/${hostname}/configuration.nix
          ];
        };

    in {
      # Host configurations
      nixosConfigurations = {
        laptop-old        = mkNixosConfig "laptop-old"       hostSystems.laptop-old       k8sRoles.laptop-old;
        laptop-ultra      = mkNixosConfig "laptop-ultra"     hostSystems.laptop-ultra     k8sRoles.laptop-ultra;
        laptop-firebat    = mkNixosConfig "laptop-firebat"   hostSystems.laptop-firebat   k8sRoles.laptop-firebat;
        ec2-controlplane  = mkNixosConfig "ec2-controlplane" hostSystems.ec2-controlplane k8sRoles.ec2-controlplane;
        test-controlplane = mkNixosConfig "test-controlplane" hostSystems.test-controlplane k8sRoles.test-controlplane;
        test-worker-node  = mkNixosConfig "test-worker-node"  hostSystems.test-worker-node k8sRoles.test-worker-node;
      };

      # Default packages for each system
      packages = {
        x86_64-linux.default = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.laptop-old = self.nixosConfigurations.laptop-old.config.system.build.toplevel;
        x86_64-linux.laptop-ultra = self.nixosConfigurations.laptop-ultra.config.system.build.toplevel;
        x86_64-linux.laptop-firebat = self.nixosConfigurations.laptop-firebat.config.system.build.toplevel;
        x86_64-linux.ec2-controlplane = self.nixosConfigurations.ec2-controlplane.config.system.build.toplevel;
        x86_64-linux.test-controlplane = self.nixosConfigurations.test-controlplane.config.system.build.toplevel;
        x86_64-linux.test-worker-node = self.nixosConfigurations.test-worker-node.config.system.build.toplevel;
      };

      # Certificate management apps
      apps.x86_64-linux = {
        "certs-recreate" = mkRecreateCertsApp {
          system = "x86_64-linux";
          nixosConfigurations = self.nixosConfigurations;
        };

        "certs-recreate-test" = mkRecreateCertsApp {
          system = "x86_64-linux";
          nixosConfigurations = {
            test-controlplane = self.nixosConfigurations.test-controlplane;
            test-worker-node = self.nixosConfigurations.test-worker-node;
          };
        };
      };

      
    };
}
