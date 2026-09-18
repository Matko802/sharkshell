{ config, pkgs, ... }:
let
  pkg = pkgs.callPackage ./packaging.nix { };
in {
  environment.systemPackages = with pkgs; [ pkg.sharkshell upower wtype matugen ];
  environment.variables.QUICKSHELL_FONT = config.custom.fontName;
  qt.enable = true;

  systemd.tmpfiles.rules = [
    "d ${config.users.users.matko.home}/.config 0755 ${config.users.users.matko.name} users -"
    "L+ ${config.users.users.matko.home}/.config/quickshell - - - - ${pkg.qsConfig}/quickshell"
    "L+ ${config.users.users.matko.home}/.config/matugen - - - - ${pkg.matugenConfig}/matugen"
  ];
}
