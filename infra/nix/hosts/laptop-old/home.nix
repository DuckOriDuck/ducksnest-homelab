# Home Manager configuration for duck user on laptopB (server-focused)
{ config, pkgs, ... }:

{
  # Home Manager settings
  home.username = "duck";
  home.homeDirectory = "/home/duck";
  home.stateVersion = "23.11";

  # Server-focused packages
  home.packages = with pkgs; [
    # Server administration tools
    htop
    btop
    iftop
    nethogs
    iotop
    
    # System monitoring
    neofetch
    lshw
    hwinfo
    lscpu
    lsblk
    
    # Network diagnostics
    mtr
    nmap
    traceroute
    dig
    whois
    
    # Log analysis
    lnav
    multitail
    ccze
    
    # Backup and sync
    rsync
    rclone
    
    # Security tools
    lynis  # Security auditing
    chkrootkit
    
    # Database clients
    postgresql
    redis
    
    # Development tools (minimal set)
    git
    vim
    tmux
    screen
    
    # Container and K8s tools (server versions)
    kubectl
    k9s
    stern
    dive
    
    # Infrastructure tools
    terraform
    ansible
    
    # Monitoring clients
    prometheus
    grafana-cli
    
    # Text processing for server logs
    jq
    yq
    xmlstarlet
    
    # Archive tools
    unzip
    p7zip
    
    # Certificate management
    openssl
    cfssl
  ];

  # Git configuration (same as laptopA but with server focus)
  programs.git = {
    enable = true;
    userName = "Duck Server";
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
      
      # Server-specific aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        
        # Server deployment aliases
        deploy-prod = "!git checkout main && git pull origin main";
        hotfix = "checkout -b hotfix/";
        release = "checkout -b release/";
        
        # Server maintenance
        cleanup = "!git branch --merged | grep -v '\\*\\|main\\|develop' | xargs -n 1 git branch -d";
      };
    };
  };

  # Bash configuration optimized for server management
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    bashrcExtra = ''
      # Server environment setup
      export HOMELAB_ENV="laptopB"
      export HOMELAB_ROLE="server"
      export KUBECONFIG="$HOME/.kube/config"
      export EDITOR="vim"
      export PAGER="less"
      
      # Server-specific paths
      export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
      
      # History settings for server auditing
      export HISTSIZE=50000
      export HISTFILESIZE=50000
      export HISTCONTROL=ignoredups:erasedups
      shopt -s histappend
      
      # Color support for server terminals
      if [ -x /usr/bin/dircolors ]; then
          test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
      fi
      
      # Server management functions
      function server-status() {
        echo "=== Server Status Overview ==="
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime)"
        echo "Load: $(cat /proc/loadavg)"
        echo "Memory: $(free -h | grep Mem)"
        echo "Disk: $(df -h / | tail -1)"
        echo ""
        echo "Active Services:"
        systemctl --type=service --state=running | head -10
        echo ""
        echo "Docker Containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running"
        echo ""
        echo "Network Connections:"
        ss -tuln | head -10
      }
      
      function server-logs() {
        echo "=== Recent System Logs ==="
        journalctl --since "1 hour ago" --no-pager | tail -20
      }
      
      function docker-stats() {
        echo "=== Docker Resource Usage ==="
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Docker not running"
      }
      
      function k8s-status() {
        if command -v kubectl >/dev/null 2>&1; then
          echo "=== Kubernetes Status ==="
          kubectl get nodes 2>/dev/null && echo "" && kubectl get pods --all-namespaces 2>/dev/null | head -10
        else
          echo "Kubernetes tools not available"
        fi
      }
      
      function backup-config() {
        local backup_dir="$HOME/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        echo "Creating backup in $backup_dir..."
        
        # Backup important configs
        sudo cp -r /etc/nixos "$backup_dir/"
        cp -r ~/.config "$backup_dir/"
        cp ~/.bashrc "$backup_dir/"
        
        # Backup Docker configs if available
        if [ -d /etc/docker ]; then
          sudo cp -r /etc/docker "$backup_dir/"
        fi
        
        echo "Backup completed: $backup_dir"
      }
      
      function monitor-process() {
        local process="$1"
        if [ -z "$process" ]; then
          echo "Usage: monitor-process <process_name>"
          return 1
        fi
        
        echo "Monitoring process: $process"
        while true; do
          clear
          echo "=== $(date) ==="
          ps aux | grep "$process" | grep -v grep
          echo ""
          top -b -n 1 -p $(pgrep "$process" | tr '\n' ',' | sed 's/,$//')
          sleep 5
        done
      }
      
      # Quick service management
      alias sstart="sudo systemctl start"
      alias sstop="sudo systemctl stop"
      alias srestart="sudo systemctl restart"
      alias sstatus="sudo systemctl status"
      alias senable="sudo systemctl enable"
      alias sdisable="sudo systemctl disable"
      
      # Log viewing shortcuts
      alias logs="journalctl -f"
      alias syslog="journalctl -u"
      alias nginx-log="sudo tail -f /var/log/nginx/access.log"
      alias nginx-error="sudo tail -f /var/log/nginx/error.log"
      
      # Docker shortcuts for server management
      alias dps="docker ps"
      alias dimg="docker images"
      alias dlog="docker logs -f"
      alias dexec="docker exec -it"
      alias dstats="docker stats"
      alias dclean="docker system prune -af"
      
      # Network diagnostics
      alias ports="ss -tulpn"
      alias listening="ss -tuln"
      alias connections="ss -tun"
      alias netstat="ss -rn"
      
      # System monitoring shortcuts
      alias cpu="grep 'cpu ' /proc/stat | awk '{usage=(\$2+\$4)*100/(\$2+\$3+\$4+\$5)} END {print usage}' | cut -d. -f1"
      alias mem="free -m | awk 'NR==2{printf \"%.1f%%\", \$3*100/\$2 }'"
      alias disk="df -h | awk '\$NF==\"/\"{printf \"%s\", \$5}'"
      
      # Security shortcuts
      alias lastlog="last -n 20"
      alias authlog="sudo journalctl -u ssh -f"
      alias faillog="sudo journalctl -u fail2ban -f"
    '';
    
    # Server-focused shell aliases
    shellAliases = {
      # System monitoring
      ll = "ls -la";
      la = "ls -la";
      lt = "ls -ltr";  # Sort by time
      
      # Process management  
      psg = "ps aux | grep";
      topcpu = "ps aux --sort=-%cpu | head";
      topmem = "ps aux --sort=-%mem | head";
      
      # Disk usage
      du1 = "du -h --max-depth=1";
      df = "df -h";
      
      # Network
      ping = "ping -c 4";
      wget = "wget -c";  # Continue downloads
      
      # File operations
      cp = "cp -i";  # Interactive copy
      mv = "mv -i";  # Interactive move
      rm = "rm -i";  # Interactive remove
      
      # Grep with colors
      grep = "grep --color=auto";
      egrep = "egrep --color=auto";
      fgrep = "fgrep --color=auto";
      
      # Quick edits
      vi = "vim";
      
      # Server management
      reboot = "sudo systemctl reboot";
      shutdown = "sudo systemctl poweroff";
      
      # Homelab specific
      homelab-backup = "backup-config";
      homelab-status = "server-status";
      homelab-logs = "server-logs";
    };
  };

  # Starship prompt for server (simpler than laptopA)
  programs.starship = {
    enable = true;
    settings = {
      format = "$username$hostname$directory$git_branch$kubernetes$docker_context$character";
      
      character = {
        success_symbol = "[🖥️ ](bold green)";
        error_symbol = "[🖥️ ](bold red)";
      };
      
      username = {
        show_always = true;
        format = "[$user]($style)@";
        style_user = "bold yellow";
      };
      
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style):";
        style = "bold blue";
      };
      
      kubernetes = {
        format = "[⛵ $context]($style) ";
        disabled = false;
        style = "bold cyan";
      };
      
      docker_context = {
        format = "[🐋 $context]($style) ";
        disabled = false;
        style = "blue bold";
      };
      
      git_branch = {
        format = "on [$symbol$branch]($style) ";
        symbol = "🌱 ";
        style = "bold purple";
      };
      
      directory = {
        truncation_length = 3;
        format = "[$path]($style) ";
        style = "bold cyan";
      };
    };
  };

  # Vim configuration for server administration
  programs.vim = {
    enable = true;
    defaultEditor = true;
    
    extraConfig = ''
      set number
      set tabstop=2
      set shiftwidth=2
      set expandtab
      set autoindent
      set hlsearch
      set incsearch
      set ignorecase
      set smartcase
      
      " Server log highlighting
      autocmd BufRead /var/log/* setfiletype messages
      
      " Configuration file syntax
      autocmd BufNewFile,BufRead *.conf set filetype=conf
      autocmd BufNewFile,BufRead *.cfg set filetype=cfg
      autocmd BufNewFile,BufRead *.service set filetype=systemd
      
      " Docker and Kubernetes files
      autocmd BufNewFile,BufRead Dockerfile* set filetype=dockerfile
      autocmd BufNewFile,BufRead *.yml set filetype=yaml
      autocmd BufNewFile,BufRead *.yaml set filetype=yaml
      
      " Infrastructure as code
      autocmd BufNewFile,BufRead *.tf set filetype=terraform
      autocmd BufNewFile,BufRead *.hcl set filetype=hcl
      
      " Quick save and system commands
      nnoremap <Leader>w :w<CR>
      nnoremap <Leader>q :q<CR>
      nnoremap <Leader>s :!systemctl status 
      nnoremap <Leader>r :!systemctl restart 
    '';
  };

  # SSH configuration for server management
  programs.ssh = {
    enable = true;
    
    extraConfig = ''
      # Server-to-server connections
      Host laptopA
        HostName laptopA.homelab.local
        User duck
        IdentityFile ~/.ssh/homelab_rsa
        ForwardAgent yes
      
      # Jenkins server
      Host jenkins
        HostName jenkins.homelab.local
        User duck
        IdentityFile ~/.ssh/homelab_rsa
        ServerAliveInterval 60
      
      # AWS infrastructure
      Host aws-bastion
        HostName bastion.aws.homelab
        User ec2-user
        IdentityFile ~/.ssh/aws_homelab_key.pem
        ForwardAgent yes
      
      Host aws-k8s-*
        HostName %h.compute.amazonaws.com
        User ec2-user
        IdentityFile ~/.ssh/aws_homelab_key.pem
        ProxyJump aws-bastion
      
      # Default settings optimized for server use
      Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
        Compression yes
        ControlMaster auto
        ControlPath ~/.ssh/master-%r@%h:%p
        ControlPersist 10m
        TCPKeepAlive yes
        
        # Security settings
        Protocol 2
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
    '';
  };

  # Tmux for server session management
  programs.tmux = {
    enable = true;
    
    extraConfig = ''
      # Server-friendly tmux configuration
      set -g default-terminal "screen-256color"
      
      # Status bar for server monitoring
      set -g status on
      set -g status-bg colour235
      set -g status-fg colour136
      set -g status-left '#[fg=colour166]#h #[fg=colour64]#S '
      set -g status-right '#[fg=colour166]#(uptime | cut -d, -f1) #[fg=colour64]%Y-%m-%d %H:%M'
      
      # Window management
      set -g base-index 1
      set -g pane-base-index 1
      set -g renumber-windows on
      
      # Server session names
      bind-key S command-prompt -p "New session name:" "new-session -s '%%'"
      bind-key R command-prompt -p "Rename session:" "rename-session '%%'"
      
      # Logging support
      bind-key L pipe-pane -o "cat >> ~/logs/tmux-#W.log" \; display "Logging to ~/logs/tmux-#W.log"
    '';
  };

  # Directories for server operations
  home.file = {
    # Create directories for server management
    "bin/.keep".text = "";
    "logs/.keep".text = "";
    "backups/.keep".text = "";
    "scripts/.keep".text = "";
    
    # Server monitoring script
    "scripts/server-monitor.sh" = {
      text = ''
        #!/bin/bash
        # Simple server monitoring script
        
        while true; do
          clear
          echo "=== Server Monitor - $(date) ==="
          echo "Load: $(cat /proc/loadavg)"
          echo "Memory: $(free -h | grep Mem)"
          echo "Disk: $(df -h / | tail -1)"
          echo "Top Processes:"
          ps aux --sort=-%cpu | head -5
          sleep 10
        done
      '';
      executable = true;
    };
  };

  # XDG directories (minimal for server)
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}