{ config, pkgs, lib, ... }:
let
  pkg = pkgs.callPackage ./packaging.nix { };
  cfgUser = config.services.sharkshell.user;
in {
  options.custom.fontName = lib.mkOption {
    type = lib.types.str;
    default = "DepartureMono Nerd Font";
    description = "Font used by sharkshell (QUICKSHELL_FONT).";
  };

  options.services.sharkshell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install sharkshell system packages and config symlinks.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "matko";
      description = "User owning the ~/.config/quickshell symlink.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.upower pkgs.wtype pkgs.adw-gtk3 pkgs.power-profiles-daemon ];
      description = "Optional companion packages for sharkshell.";
    };
    powerProfiles = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable power-profiles-daemon so the PerfMode power profiles actually change system behavior.";
    };
  };

  config = lib.mkIf config.services.sharkshell.enable {
    environment.systemPackages = [ pkg.sharkshell pkg.sharkColorsBin ] ++ config.services.sharkshell.extraPackages;
    environment.variables.QUICKSHELL_FONT = config.custom.fontName;
    qt.enable = true;

    services.power-profiles-daemon.enable = lib.mkIf config.services.sharkshell.powerProfiles (lib.mkDefault true);
    services.upower.enable = lib.mkDefault true;

    systemd.tmpfiles.rules =
      let
        user = cfgUser;
        home = config.users.users.${user}.home or "/home/${user}";
        name = config.users.users.${user}.name or user;
      in [
        "d ${home}/.config 0755 ${name} users -"
        "L+ ${home}/.config/quickshell - - - - ${pkg.qsConfig}/quickshell"
        "L+ ${home}/.config/matugen - - - - ${pkg.matugenConfig}/matugen"
      ];
  };
}
