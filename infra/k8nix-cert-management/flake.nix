{
  description = "K8S on nix tool collection";
  
  inputs.nixpkgs.url = "nixpkgs/nixos-25.05";
  
  inputs.agenix.url = "github:ryantm/agenix";

  outputs = { nixpkgs, self, agenix, ...}@inputs: let
    lib = nixpkgs.lib;
  in rec {
    nixosModules.certToolkit = import ./modules/cert-toolkit.nix;
    nixosModules.kubernetesMultiYamlAddons = import ./modules/kubernetes-multi-yaml-addons.nix;
    mkRecreateCertsScript = { nixosConfigurations, caModules, system }: let
      pkgs = import nixpkgs { inherit system; };
      caCfg = (nixpkgs.lib.evalModules {
        specialArgs = {
          inherit pkgs;
          ageIntegration = false;
        };
        modules = [self.nixosModules.certToolkit] ++ caModules;
      }).config.certToolkit;
    in pkgs.writeShellScriptBin "recreate-certs" ''
      ${lib.pipe caCfg.cas [
        lib.attrsets.attrValues
        (map ({ ca, ... }: ca.createScript))
        (lib.strings.concatStringsSep "\n")
      ]}
      ${lib.pipe nixosConfigurations [
        lib.attrValues
        (map (cfg: lib.attrValues cfg.config.certToolkit.cas))
        lib.concatLists
        (map (ca: lib.attrValues ca.certs))
        lib.concatLists
        (map (cert: cert.createScript))
        (lib.strings.concatStringsSep "\n")
      ]}
    '';
    mkRecreateCertsApp = args: {
      type = "app";
      program = "${mkRecreateCertsScript args}/bin/recreate-certs";
    };
    checks."x86_64-linux" = let

      assertSubset = pattern: full:
        let
          cmp = path: pat: sup:
            let names = builtins.attrNames pat; in
            builtins.foldl' (acc: name:
              if acc != "" then acc
              else if ! builtins.hasAttr name sup
              then "${concatStringsSep "." (path ++ [ name ])}: missing"
              else
                let
                  vPat = pat.${name};
                  vSup = sup.${name};
                in
                  if builtins.isAttrs vPat && builtins.isAttrs vSup
                  then cmp (path ++ [ name ]) vPat vSup
                  else if vPat == vSup
                      then ""
                      else "${concatStringsSep "." (path ++ [ name ])}: ${toString vSup} is not ${toString vPat}"
            ) "" names;
          concatStringsSep = sep: list: builtins.concatStringsSep sep list;
        in cmp [] pattern full;


      checkCaModule = caModule: testSubSet: let
        caCfg = (nixpkgs.lib.evalModules {
          specialArgs = {
            inherit pkgs;
            ageIntegration = false;
          };
          modules = [self.nixosModules.certToolkit caModule];
        }).config;
        err = assertSubset testSubSet caCfg;
      in if err == "" then (pkgs.writeText "" "") else builtins.throw "Error checking CaModule: ${err}";
      pkgs = import nixpkgs { system ="x86_64-linux"; };
    in {
      simpleDirCheck = checkCaModule { config.certToolkit.dir = "./my-dir"; } { certToolkit.dir = "./my-dir"; };
      caDefaultsDeriveFromDefaults = checkCaModule {
        certToolkit.defaults.expiry = "42h";
      } {
        certToolkit.defaults.expiry = "42h";
        certToolkit.caDefaults.expiry = "42h";
      };
      caDefaultsWithoutDefaults = checkCaModule {
        certToolkit.caDefaults.expiry = "42h";
      } {
        certToolkit.caDefaults.expiry = "42h";
      };
      caDefaultNamesGetMergedWithDefaultNames = checkCaModule {
        certToolkit.defaults.names.L = "CH";
        certToolkit.caDefaults.names.O = "MyOrga";
      } {
        certToolkit.caDefaults.names = {
          L = "CH";
          O = "MyOrga";
        };
      };
      certDefaultNamesGetMergedWithDefaultNames = checkCaModule {
        certToolkit.defaults.names.L = "CH";
        certToolkit.certDefaults.names.O = "MyOrga";
      } {
        certToolkit.certDefaults.names = {
          L = "CH";
          O = "MyOrga";
        };
      };
      defaultsGetInheritedToCertDefaultsOnCa = checkCaModule {
        certToolkit.defaults.expiry = "42h";
        certToolkit.cas.my-ca = {};
      } {
        certToolkit.cas.my-ca.certDefaults.expiry = "42h";
      };
      caDefaultsAreUsedOnCa = checkCaModule {
        certToolkit.caDefaults.expiry = "42h";
        certToolkit.cas.my-ca.ca = {};
      } {
        certToolkit.cas.my-ca.ca.expiry = "42h";
      };
      certDefaultsOnCaAreUsedOnCerts = checkCaModule {
        certToolkit.cas.my-ca = {
          ca = {};
          certDefaults.expiry = "42h";
          certs.my-cert = {};
        };
      } {
        certToolkit.cas.my-ca.certs.my-cert.expiry = "42h";
      };
      certDefaultsGerMergedWell = checkCaModule {
        certToolkit = {
          defaults.names = {
            C = "CH";
            ST = "BAD";
            L = "BAD";
            O = "BAD";
          };
          certDefaults.names = {
            ST = "Bern";
            L = "BAD";
            O = "BAD";
          };
          cas.my-ca = {
            ca = {};
            certDefaults.names = {
              L = "Thun";
              O = "BAD";
            };
            certs.my-cert.names = {
              O = "MyOrg";
            };
          };
        };
      } {
        certToolkit.cas.my-ca.certs.my-cert.names = {
          C = "CH";
          ST = "Bern";
          L = "Thun";
          O = "MyOrg";
        };
      };
    };
  };
}