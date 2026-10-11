{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "sharkshell-output-power";
  version = "1.0.0";

  src = ./output-power;

  strictDeps = true;

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.wayland-scanner
  ];

  buildInputs = [
    pkgs.wayland
    pkgs.qt6.qtbase
    pkgs.qt6.qtdeclarative
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  dontWrapQtApps = true;

  meta = {
    description = "Native wlr-output-power-management-v1 QML plugin for Quickshell (replaces wlopm)";
  };
}
