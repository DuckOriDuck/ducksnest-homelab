# Home Manager configuration for duck user on laptopA
{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "duck";
  home.homeDirectory = "/home/duck";

  # This value determines the Home Manager release with which your
  # configuration is compatible. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "23.11";

  # User packages that don't require system-level installation
  home.packages = with pkgs; [
    # Development tools
    nodejs_20
    python3
    go
    rustc
    cargo
    
    # Cloud CLI tools (latest versions)
    unstable.kubectl
    unstable.kubernetes-helm
    unstable.terraform
    
    # Monitoring and observability
    unstable.k9s
    unstable.stern
    
    # Text processing
    ripgrep
    fd
    bat
    exa
    
    # File management
    fzf
    zoxide
    
    # Network tools
    mtr
    dog  # DNS lookup tool
    
    # Container development
    dive  # Docker image explorer
    hadolint  # Dockerfile linter
    
    # Fonts for development
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "JetBrainsMono" ]; })
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Duck";
    userEmail = "duck@homelab.local";
    
    extraConfig = {
      core = {
        editor = "vim";
        autocrlf = false;
      };
      
      push = {
        default = "simple";
        autoSetupRemote = true;
      };
      
      pull = {
        rebase = true;
      };
      
      init = {
        defaultBranch = "main";
      };
      
      # Homelab-specific Git aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        
        # Homelab workflow aliases
        sync-main = "!git checkout main && git pull origin main";
        deploy-dev = "!git checkout develop && git merge main && git push origin develop";
        feature = "checkout -b feature/";
        hotfix = "checkout -b hotfix/";
      };
    };
  };

  # Bash configuration with homelab aliases
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    bashrcExtra = ''
      # Homelab environment setup
      export HOMELAB_ENV="laptopA"
      export KUBECONFIG="$HOME/.kube/config"
      export EDITOR="vim"
      
      # Kubernetes context helper
      function kctx() {
        kubectl config use-context "$1"
      }
      
      # Namespace helper
      function kns() {
        kubectl config set-context --current --namespace="$1"
      }
      
      # ArgoCD login helper
      function argocd-login() {
        argocd login argocd.homelab.local --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
      }
      
      # Terraform workspace helper
      function tf-workspace() {
        terraform workspace select "$1" || terraform workspace new "$1"
      }
      
      # Docker cleanup
      alias docker-cleanup="docker system prune -a -f && docker volume prune -f"
      
      # Quick homelab status check
      function homelab-status() {
        echo "=== Homelab Status Check ==="
        echo "Kubernetes contexts:"
        kubectl config get-contexts
        echo ""
        echo "Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "System resources:"
        df -h / /home
        free -h
      }
    '';
    
    # Shell aliases (duplicated from system for home-manager)
    shellAliases = {
      k = "kubectl";
      d = "docker";
      tf = "terraform";
      ll = "ls -la";
      la = "ls -la";
      grep = "grep --color=auto";
      cat = "bat";
      ls = "exa --icons";
      cd = "z";  # Using zoxide
    };
  };

  # Starship prompt configuration
  programs.starship = {
    enable = true;
    settings = {
      format = "$all$kubernetes$terraform$docker_context$character";
      
      character = {
        success_symbol = "[🦆](bold green)";
        error_symbol = "[🦆](bold red)";
      };
      
      kubernetes = {
        format = "on [⛵ $context($namespace)](dimmed green) ";
        disabled = false;
        contexts = [
          { context_pattern = "dev-.*"; style = "green"; }
          { context_pattern = "prod-.*"; style = "red"; }
        ];
      };
      
      terraform = {
        format = "[🏗️ $workspace]($style) ";
        disabled = false;
      };
      
      docker_context = {
        format = "via [🐋 $context](blue bold)";
        disabled = false;
      };
      
      aws = {
        format = "on [$symbol($profile)(\($region\))]($style) ";
        symbol = "☁️  ";
        disabled = false;
      };
    };
  };

  # Zoxide for better cd
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # fzf for fuzzy finding
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--preview 'bat --color=always --style=header,grid --line-range :300 {}'"
    ];
  };

  # Vim configuration for homelab work
  programs.vim = {
    enable = true;
    defaultEditor = true;
    
    extraConfig = ''
      set number
      set relativenumber
      set tabstop=2
      set shiftwidth=2
      set expandtab
      set autoindent
      set smartindent
      set hlsearch
      set incsearch
      set ignorecase
      set smartcase
      
      " Homelab file type associations
      autocmd BufNewFile,BufRead *.tf set filetype=terraform
      autocmd BufNewFile,BufRead *.hcl set filetype=hcl
      autocmd BufNewFile,BufRead Jenkinsfile set filetype=groovy
      autocmd BufNewFile,BufRead *.yml set filetype=yaml
      autocmd BufNewFile,BufRead *.yaml set filetype=yaml
      
      " Quick save and quit
      nnoremap <Leader>w :w<CR>
      nnoremap <Leader>q :q<CR>
      nnoremap <Leader>wq :wq<CR>
    '';
  };

  # SSH configuration for homelab access
  programs.ssh = {
    enable = true;
    
    extraConfig = ''
      # Homelab server access
      Host jenkins
        HostName jenkins.homelab.local
        User duck
        IdentityFile ~/.ssh/homelab_rsa
        ForwardAgent yes
      
      Host argocd
        HostName argocd.homelab.local
        User duck
        IdentityFile ~/.ssh/homelab_rsa
        ForwardAgent yes
      
      Host laptopB
        HostName laptopB.homelab.local
        User duck
        IdentityFile ~/.ssh/homelab_rsa
        ForwardAgent yes
      
      # AWS bastion (if using)
      Host aws-bastion
        HostName bastion.aws.homelab
        User ec2-user
        IdentityFile ~/.ssh/aws_homelab_key.pem
        ForwardAgent yes
      
      # Default settings for all hosts
      Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
        Compression yes
        ControlMaster auto
        ControlPath ~/.ssh/master-%r@%h:%p
        ControlPersist 10m
    '';
  };

  # Alacritty terminal configuration
  programs.alacritty = {
    enable = true;
    
    settings = {
      window = {
        padding = { x = 5; y = 5; };
        decorations = "full";
        startup_mode = "Windowed";
      };
      
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        italic = {
          family = "JetBrainsMono Nerd Font";
          style = "Italic";
        };
        size = 12.0;
      };
      
      colors = {
        primary = {
          background = "0x1a1b26";
          foreground = "0xa9b1d6";
        };
        normal = {
          black = "0x32344a";
          red = "0xf7768e";
          green = "0x9ece6a";
          yellow = "0xe0af68";
          blue = "0x7aa2f7";
          magenta = "0xad8ee6";
          cyan = "0x449dab";
          white = "0x787c99";
        };
        bright = {
          black = "0x444b6a";
          red = "0xff7a93";
          green = "0xb9f27c";
          yellow = "0xff9e64";
          blue = "0x7da6ff";
          magenta = "0xbb9af7";
          cyan = "0x0db9d7";
          white = "0xacb0d0";
        };
      };
    };
  };

  # XDG directories
  xdg = {
    enable = true;
    
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      videos = "$HOME/Videos";
      templates = "$HOME/Templates";
      publicShare = "$HOME/Public";
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}