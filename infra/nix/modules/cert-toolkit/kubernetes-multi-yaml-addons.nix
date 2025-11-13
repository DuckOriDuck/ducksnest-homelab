{ config, lib, pkgs, ... }@args:
{
  options.services.kubernetes.addonManager.multiYamlAddons = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          version = lib.mkOption { type = lib.types.str; };
          src = lib.mkOption { type = lib.types.path; };
        };
      }
    );
  };
  config = {
    services.kubernetes.addonManager.addons = lib.pipe config.services.kubernetes.addonManager.multiYamlAddons [
      lib.attrsets.attrValues
      (map (args: args // {
        dontUnpack = true;
        buildPhase = ''
          cat ${args.src} \
            | ${pkgs.yq-go}/bin/yq e 'select(length > 0)' \
            | ${pkgs.yq-go}/bin/yq ea '[.]' -oj \
            > ${args.name}.json
        '';
        installPhase = ''
          install ${args.name}.json $out
        '';
      }))
      (map pkgs.stdenv.mkDerivation)
      (map builtins.readFile)
      (map builtins.fromJSON)
      lib.concatLists
      (map (value: {
        value = lib.attrsets.recursiveUpdate value {
          metadata.labels."addonmanager.kubernetes.io/mode" = "Reconcile";
        };
        name = "${value.kind}_${value.metadata.name}";
      }))
      builtins.listToAttrs
    ];
  };
}