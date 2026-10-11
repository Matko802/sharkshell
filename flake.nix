{
  description = "sharkshell - Quickshell desktop shell with a native output-power QML plugin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs:
        let
          sharkshellPkgs = pkgs.callPackage ./packaging.nix { };
          outputPower = pkgs.callPackage ./output-power.nix { };
        in {
          default = sharkshellPkgs.sharkshell;
          sharkshell = sharkshellPkgs.sharkshell;
          sharkshell-config = sharkshellPkgs.qsConfig;
          shark-colors = sharkshellPkgs.sharkColorsBin;
          output-power = outputPower;
        });

      overlays.default = final: _prev:
        let sharkshellPkgs = final.callPackage ./packaging.nix { };
        in {
          sharkshell = sharkshellPkgs.sharkshell;
          sharkshell-config = sharkshellPkgs.qsConfig;
        };

      nixosModules.default = import ./sharkshell.nix;

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            quickshell
            cmake
            ninja
            pkg-config
            wayland
            wayland-scanner
            qt6.qtbase
            qt6.qtdeclarative
          ];
        };
      });
    };
}
