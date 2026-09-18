{ pkgs }:
let
  qsConfig = pkgs.runCommand "sharkshell-config" { src = ./config; } ''
    mkdir -p $out/quickshell
    cp -r $src/. $out/quickshell/
  '';

  # Matugen template setup: input template paths are baked in at build time.
  matugenConfig = pkgs.runCommand "sharkshell-matugen-config" { src = ./matugen; } ''
    mkdir -p $out/matugen/templates
    cp $src/templates/kitty.conf $src/templates/niri-borders.kdl $out/matugen/templates/
    sed "s|@TEMPLATE_DIR@|$out/matugen/templates|g" $src/config.toml > $out/matugen/config.toml
  '';

  outputPower = pkgs.callPackage ./output-power.nix { };

  sharkshell = pkgs.symlinkJoin {
    name = "sharkshell";
    paths = [ pkgs.quickshell ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      mkdir -p "$out/lib/qt-6/qml/Quickshell"
      cp -r ${outputPower}/lib/qt-6/qml/Quickshell/Power "$out/lib/qt-6/qml/Quickshell/Power"
      chmod -R u+w "$out/lib/qt-6/qml/Quickshell/Power"
      wrapProgram "$out/bin/quickshell" \
        --prefix QT_PLUGIN_PATH : "${pkgs.qt6Packages.qtimageformats}/${pkgs.qt6.qtbase.qtPluginPrefix}" \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML2_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML2_IMPORT_PATH : "/home/matko/.local/share/qmltermwidget" \
        --prefix QML2_IMPORT_PATH : "${pkgs.qt6Packages.qt5compat}/${pkgs.qt6.qtbase.qtQmlPrefix}" \
        --prefix QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML_IMPORT_PATH : "/home/matko/.local/share/qmltermwidget"
    '';
  };
in {
  inherit qsConfig sharkshell matugenConfig;
}
