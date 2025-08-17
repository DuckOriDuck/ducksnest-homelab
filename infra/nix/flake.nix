{
  description = "DucksNest Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # For container and K8s tooling
    flake-utils.url = "github:numtide/flake-utils";
    
    # For development shells
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, flake-utils, devshell }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      
      # system architecture for each host
      hostSystems = {
        laptop-old = "x86_64-linux";
        laptop-ultra = "x86_64-linux";
        ec2-controlplane = "aarch64-linux";  # Graviton
        ec2-jenkins = "aarch64-linux";       # Graviton
      };
      
      # inject unstable set as pkgs.unstable
      pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = overlaysFor system;
      };
      
      # Overlay for unstable packages
      overlaysFor = system: [
        (final: prev: {
        unstable = import nixpkgs-unstable { inherit system; };
        })
      ];


      # Common packages for all homelab hosts
      commonPackagesFor = system:
      let
      pkgs = pkgsFor system;
      in with pkgs; [
        # System tools
        htop
        btop
        fastfetch
        tree
        tmux
        screen
        
        # Network tools
        curl
        wget
        nmap
        net-tools
        bind
        iperf3
        
        # Container & K8s tools
        cri-o
        cri-tools
        kubernetes
        kubernetes-helm
        kustomize
        k9s
        
        # Development tools
        git
        nvim
        jq
        yq
        
        # Monitoring tools
        prometheus
        grafana
        
        # Security tools
        gnupg
        age
        sops

        # Network Overlay Tools
        headscale
        tailscale
      ];
      
      
      
      #Function to create NixoOS Settings
      mkNixosConfig = hostname: system:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          commonPackages = commonPackagesFor system;
          inherit system;
        };

        modules = [
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = overlaysFor system;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            nixpkgs.config.allowUnfree = true;
            environment.systemPackages = commonPackagesFor system;
          })

          ./hosts/${hostname}/configuration.nix
          ./modules/common/base.nix
          ./modules/common/security.nix  
          ./modules/common/users.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.duck = import ./hosts/${hostname}/home.nix;
          }
        ];
      };

    in {
      nixosConfigurations = {
      laptop-old       = mkNixosConfig "laptop-old"      hostSystems.laptop-old;
      laptop-ultra     = mkNixosConfig "laptop-ultra"    hostSystems.laptop-ultra;
      ec2-controlplane = mkNixosConfig "ec2-controlplane" hostSystems.ec2-controlplane;
      ec2-jenkins      = mkNixosConfig "ec2-jenkins"     hostSystems.ec2-jenkins;
    };
      
      # Development shell for managing the homelab
      devShells =
      builtins.listToAttrs (map (system: {
        name = system;
        value = {
          default = (pkgsFor system).mkShell {
            buildInputs =
              (commonPackagesFor system)
              ++ with (pkgsFor system); [
                nixos-rebuild
                home-manager
              ];

            shellHook = ''
              echo "🦆 Welcome to DuckNest Homelab DevShell (${system})"
              echo "Available tools: terraform, kubectl, helm, etc."
              echo ""
              echo "Quick commands:"
              echo "  sudo nixos-rebuild switch --flake .#laptop-old"
              echo "  sudo nixos-rebuild switch --flake .#ec2-controlplane"
              echo "  home-manager switch --flake .#duck@<hostname>"
              echo ""
            '';
          };
        };
      }) systems);
    };
}