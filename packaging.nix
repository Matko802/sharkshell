{ pkgs }:
let
  qsConfig = pkgs.runCommand "sharkshell-config" { src = ./config; } ''
    mkdir -p $out/quickshell
    cp -r $src/. $out/quickshell/
  '';

  matugenConfig = pkgs.runCommand "sharkshell-matugen-config" { src = ./matugen; } ''
    mkdir -p $out/matugen/templates
    cp $src/templates/kitty.conf $src/templates/niri-borders.kdl $out/matugen/templates/
    sed "s|@TEMPLATE_DIR@|$out/matugen/templates|g" $src/config.toml > $out/matugen/config.toml
  '';

  outputPower = pkgs.callPackage ./output-power.nix { };

  sharkColors = pkgs.python3.withPackages (ps: [ ps.materialyoucolor ps.pillow ]);
  sharkColorsBin = pkgs.writeShellScriptBin "shark-colors"
    "exec ${sharkColors}/bin/python3 ${./scripts/shark-colors} \"$@\"";

  # Named shortcuts matching the QML file names (clockmenu, powermenu, ...)
  # so keybinds show meaningful names instead of identical quickshell calls.
  ipcCmd = name: target: action: pkgs.writeShellScriptBin name
    "exec ${pkgs.quickshell}/bin/quickshell ipc call ${target} ${action}";
  ipcCmds = [
    (ipcCmd "lock" "lock" "lock")
    (ipcCmd "powermenu" "power" "toggle")
    (ipcCmd "bar" "bar" "toggle")
    (ipcCmd "emojipicker" "emoji" "toggle")
    (ipcCmd "launcher" "launcher" "toggle")
    (ipcCmd "settingsmenu" "settings" "toggle")
    (ipcCmd "clipboard" "clipboard" "toggle")
    (ipcCmd "clockmenu" "clock" "toggle")
  ];

  sharkshell = pkgs.symlinkJoin {
    name = "sharkshell";
    paths = [ pkgs.quickshell sharkColorsBin ] ++ ipcCmds;
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
  inherit qsConfig sharkshell matugenConfig sharkColorsBin;
}
