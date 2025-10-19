{ self, config, lib, pkgs, ... }@args:
let
  ageIntegration = args.ageIntegration or true;
  hostName = config.networking.hostName or "";
  cfg = config.certToolkit;
  mkRecipientFile = keys: pkgs.writeText "recipients" (builtins.concatStringsSep "\n" keys);
in {
  options.certToolkit = let
    keyType = lib.types.submodule {
      options = {
        algo = lib.mkOption { type = lib.types.enum [ "ecdsa" "rsa" ]; };
        size = lib.mkOption { type = lib.types.int; };
      };
    };
    namesOptions = {
      C   = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Country (2-letter ISO code)"; };
      ST  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "State or Province"; };
      L   = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Locality / City"; };
      O   = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Organization"; };
      OU  = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Organizational Unit"; };
    };
    
    keyOption = { type = keyType; };
    expiryOption = { type = lib.types.str; example = "876000h"; };
    usagesOption = { type = lib.types.listOf lib.types.str; example = "[ \"signing\" ]"; };

    certOptions = {
      key = lib.mkOption keyOption;
      expiry = lib.mkOption expiryOption;
      usages = lib.mkOption usagesOption;
      names = lib.mkOption {
        type = lib.types.submodule {
          options = namesOptions;
          config = {};
        };
      };
      commonName = lib.mkOption { type = lib.types.str; description = "Common Name"; };
      hosts = lib.mkOption { type = lib.types.listOf lib.types.str; example = "[ \"example.com\" ]"; };
      path = lib.mkOption { type = lib.types.path; description = "The absolute store path of the certificate"; };
      keyPath = lib.mkOption { type = lib.types.str; };
      agePath = lib.mkOption { type = lib.types.path; description = "The absolute store path of age encrypted key"; };
      relativePath = lib.mkOption { type = lib.types.str; description = "The path of the certificate relative to the flake root"; };
      relativeAgePath = lib.mkOption { type = lib.types.str; description = "The path of the age encrypted key relative to the flake root"; };
      id = lib.mkOption { type = lib.types.str; description = "A unique id to identify the cert"; };
      owner = lib.mkOption { type = lib.types.str; default = ""; description = "The owner of the key file"; };
      group = lib.mkOption { type = lib.types.str; default = ""; description = "The owner of the key file"; };
      mode = lib.mkOption { type = lib.types.str; default = ""; description = "The permissions mode of the key file"; };
      csr = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
      };
      csrFile = lib.mkOption {
        type = lib.types.path;
      };
      createScript = lib.mkOption { type = lib.types.str; };
    };
    mkCsr = args: {
      CN = args.commonName;
      key = args.key;
      hosts = args.hosts;
      names = [ args.names ];
      usages = args.usages;
      expiry = args.expiry;
    };
    defaultsOptions = {
      key = lib.mkOption { type = lib.types.nullOr keyType; default = null; };
      expiry = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      names = lib.mkOption {
        type = lib.types.submodule {
          options = namesOptions;
          config = {};
        };
      };
      owner = lib.mkOption { type = lib.types.str; default = ""; description = "The owner of the key file"; };
      group = lib.mkOption { type = lib.types.str; default = ""; description = "The owner of the key file"; };
      mode = lib.mkOption { type = lib.types.str; default = ""; description = "The permissions mode of the key file"; };

      hosts = lib.mkOption { type = lib.types.listOf lib.types.str; example = "[ \"example.com\" ]"; };
      usages = lib.mkOption usagesOption;
    };
    mkDeivedCertConfig = priority: base: {
      expiry = lib.mkIf (!isNull base.expiry) (lib.mkOverride priority base.expiry);
      key = lib.mkIf (!isNull base.key) (lib.mkOverride priority base.key);
      names = lib.mkIf (!isNull base.names) (
        builtins.mapAttrs (k: v: lib.mkOverride priority v) base.names
      );
      owner = lib.mkIf (!isNull base.owner) (lib.mkOverride priority base.owner);
      mode = lib.mkIf (!isNull base.mode) (lib.mkOverride priority base.mode);
      group = lib.mkIf (!isNull base.group) (lib.mkOverride priority base.group);
      hosts = lib.mkIf (!isNull base.hosts) (lib.mkOverride priority base.hosts);
      usages = lib.mkIf (!isNull base.usages) (lib.mkOverride priority base.usages);
    };
    mkDerivedDefaults = priority: base: lib.mkOption {
      type = lib.types.submodule {
        options = defaultsOptions;
        config = mkDeivedCertConfig priority base;
      };
      default = {};
    };
  in {
    dir = lib.mkOption {
      type = lib.types.str;
    };
    userAgeKeys = lib.mkOption { type = lib.types.listOf lib.types.str; };
    userAgeIdentity = lib.mkOption { type = lib.types.str; example = "$HOME/.ssh/id_rsa"; };
    owningHostKey = lib.mkOption { type = lib.types.str; description = "The ssh host key of the target host for encryption"; };
    defaults = lib.mkOption {
      type = lib.types.submodule {
        options = defaultsOptions;
        config = {};
      };
      default = {};
    };
    caDefaults = mkDerivedDefaults 1009 cfg.defaults;
    certDefaults = mkDerivedDefaults 1009 cfg.defaults;
    cas = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule ({ name, ...}@caSubmodule: let
          caName = name;
        in {
          options = {
            certDefaults = mkDerivedDefaults 1008 cfg.certDefaults;
            certs = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule ({ name, ... }@certSubmodule: {
                  options = certOptions;
                  config = let
                    scfg = certSubmodule.config;
                  in rec {
                    names = lib.mkDefault {};
                    id = "derived-${config.networking.hostName}-${caName}-${name}";
                    relativePath    = "${cfg.dir}/derived/${config.networking.hostName}/${caName}-${name}.crt";
                    relativeAgePath = "${cfg.dir}/derived/${config.networking.hostName}/${caName}-${name}.key.age";
                    path = builtins.path { path = "${self.outPath}/${cfg.dir}/derived/${config.networking.hostName}/${caName}-${name}.crt"; };
                    agePath = builtins.path { path = "${self.outPath}/${cfg.dir}/derived/${config.networking.hostName}/${caName}-${name}.key.age"; };
                    csr = mkCsr scfg;
                    csrFile = builtins.toFile "csr-${config.networking.hostName or ""}-${caName}-${name}.json" (builtins.toJSON scfg.csr);
                    keyPath = config.age.secrets."certtoolkit-${id}".path;

                    createScript = ''
                      echo "create ${scfg.id}"
                      keyfile=$(${pkgs.mktemp}/bin/mktemp)
                      cat ${caSubmodule.config.ca.relativeAgePath} \
                        | ${pkgs.rage}/bin/rage -i ${cfg.userAgeIdentity} -d \
                        > $keyfile
                      
                      cert=$(${pkgs.cfssl}/bin/cfssl gencert \
                        -ca file:${caSubmodule.config.ca.relativePath} \
                        -ca-key file:$keyfile \
                        ${scfg.csrFile} 2>/dev/null)

                      mkdir -p $(dirname ${scfg.relativePath})      
                      echo $cert | ${pkgs.jq}/bin/jq -r ".key" \
                      | ${pkgs.rage}/bin/rage \
                        -R ${mkRecipientFile cfg.userAgeKeys} \
                        -R ${cfg.owningHostKey} \
                        -e \
                        -o ${scfg.relativeAgePath}

                      echo $cert | ${pkgs.jq}/bin/jq -r ".cert" \
                        > ${scfg.relativePath}
                    '';
                  } // (mkDeivedCertConfig 1007 caSubmodule.config.certDefaults);
                })
              );
              default = {};
            };
            ca = lib.mkOption {
              type = lib.types.submodule ({...}@caCertSubmodule: {
                options = certOptions;
                config = {
                  createScript = ''
                    echo ca: ${caName}
                    if [ -e "${caCertSubmodule.config.relativeAgePath}" ]; then
                      echo "cert exists, trying to reencrypt the key"
                      tmpfile=$(mktemp)
                      cat ${caCertSubmodule.config.relativeAgePath} \
                        | ${pkgs.rage}/bin/rage -i ${cfg.userAgeIdentity} -d \
                        | ${pkgs.rage}/bin/rage -R ${mkRecipientFile cfg.userAgeKeys} -e -o $tmpfile
                      mv $tmpfile ${caCertSubmodule.config.relativeAgePath}
                    else
                      echo "cert does not exist, create it"
                      mkdir -p $(dirname "${caCertSubmodule.config.relativePath}")
                      cert=$(${pkgs.cfssl}/bin/cfssl gencert -initca ${caCertSubmodule.config.csrFile} 2>/dev/null)
                      echo $cert | ${pkgs.jq}/bin/jq -r ".key" \
                      | ${pkgs.rage}/bin/rage -R ${mkRecipientFile cfg.userAgeKeys} -e -o ${caCertSubmodule.config.relativeAgePath}
                      echo $cert | ${pkgs.jq}/bin/jq -r ".cert" \
                        > ${caCertSubmodule.config.relativePath}
                    fi
                  '';
                } // (mkDeivedCertConfig 1007 cfg.caDefaults);
              });
            };
          };
          config = let
            caCfg = caSubmodule.config.ca;
          in {
            ca = {
              relativePath = "${cfg.dir}/ca/${caName}.crt";
              relativeAgePath = "${cfg.dir}/ca/${caName}.key.age";
              path = builtins.path { path = "${self.outPath}/${cfg.dir}/ca/${caName}.crt"; };
              hosts = lib.mkDefault [];
              names = lib.mkDefault {};
              csr = mkCsr caCfg;
              csrFile = builtins.toFile "csr-ca-${caName}.json" (builtins.toJSON caCfg.csr);
            };
          };
        })
      );
    };
  };
  config = if ageIntegration then {
    age.secrets = lib.pipe cfg [
      (cfg: builtins.attrValues cfg.cas)
      (map (caCfg: builtins.attrValues caCfg.certs))
      lib.concatLists
      (map (cert: {
        "certtoolkit-${cert.id}" = {
          file = cert.agePath;
          owner = lib.mkIf (cert.owner != "") cert.owner;
          group = lib.mkIf (cert.group != "") cert.group;
          mode = lib.mkIf (cert.mode != "") cert.mode;
        };
      }))
      lib.mkMerge
    ];
  } else {};
}