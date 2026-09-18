{
  description = "sharkshell - Quickshell desktop shell with a native output-power QML plugin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (nixpkgs.legacyPackages.${system}));

      sharkshellPkgs = pkgs: pkgs.callPackage ./packaging.nix { };

      sharkshell =
        { pkgs }:
        (sharkshellPkgs pkgs).sharkshell.overrideAttrs (prev: {
          meta = (prev.meta or { }) // {
            mainProgram = "quickshell";
            description = "Sharkshell Quickshell desktop shell (wrapped quickshell + Power plugin)";
            homepage = "https://github.com/Matko802/sharkshell";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
          };
        });
    in
    {
      packages = forAllSystems (pkgs: {
        default = sharkshell { inherit pkgs; };
        sharkshell = sharkshell { inherit pkgs; };
        sharkshell-config = (sharkshellPkgs pkgs).qsConfig;
        output-power = pkgs.callPackage ./output-power.nix { };
      });

      overlays.default = final: _prev: {
        sharkshell = sharkshell { pkgs = final; };
        sharkshell-config = (sharkshellPkgs final).qsConfig;
      };

      nixosModules.default = import ./sharkshell.nix;

      devShells = forAllSystems (pkgs:
        pkgs.mkShell {
          buildInputs = with pkgs; [
            quickshell
            cmake
            pkg-config
            wayland
            qt6.qtbase
            qt6.qtdeclarative
          ];
        });
    };
}
