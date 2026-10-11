{ pkgs }:
let
  qsConfig = pkgs.runCommand "sharkshell-config" { src = pkgs.lib.cleanSource ./config; } ''
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

  ipcSpecs = [
    { name = "lock"; target = "lock"; action = "lock"; }
    { name = "powermenu"; target = "power"; action = "toggle"; }
    { name = "bar"; target = "bar"; action = "toggle"; }
    { name = "emojipicker"; target = "emoji"; action = "toggle"; }
    { name = "launcher"; target = "launcher"; action = "toggle"; }
    { name = "settingsmenu"; target = "settings"; action = "toggle"; }
    { name = "clipboard"; target = "clipboard"; action = "toggle"; }
    { name = "clockmenu"; target = "clock"; action = "toggle"; }
  ];

  ipcCmdsPkg = pkgs.runCommand "sharkshell-ipc-cmds" { } ''
    mkdir -p $out/bin
    ${pkgs.lib.concatMapStringsSep "\n" (s: ''
      cat > $out/bin/${s.name} <<'EOF'
      #!${pkgs.runtimeShell}
      exec ${pkgs.quickshell}/bin/quickshell ipc call ${s.target} ${s.action} "$@"
      EOF
      chmod +x $out/bin/${s.name}
    '') ipcSpecs}
  '';

  sharkshell = pkgs.symlinkJoin {
    name = "sharkshell";
    paths = [ pkgs.quickshell sharkColorsBin ipcCmdsPkg ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      mkdir -p "$out/lib/qt-6/qml/Quickshell"
      ln -sfn ${outputPower}/lib/qt-6/qml/Quickshell/Power "$out/lib/qt-6/qml/Quickshell/Power"
      wrapProgram "$out/bin/quickshell" \
        --prefix QT_PLUGIN_PATH : "${pkgs.qt6Packages.qtimageformats}/${pkgs.qt6.qtbase.qtPluginPrefix}" \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML2_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --prefix QML2_IMPORT_PATH : "${pkgs.qt6Packages.qt5compat}/${pkgs.qt6.qtbase.qtQmlPrefix}" \
        --prefix QML_IMPORT_PATH : "$out/lib/qt-6/qml" \
        --suffix QML2_IMPORT_PATH : "''${SHARKSHELL_EXTRA_QML_PATH-}" \
        --suffix QML_IMPORT_PATH : "''${SHARKSHELL_EXTRA_QML_PATH-}"
    '';
    meta = {
      mainProgram = "quickshell";
      description = "Sharkshell Quickshell desktop shell (wrapped quickshell + Power plugin)";
      homepage = "https://github.com/Matko802/sharkshell";
      license = pkgs.lib.licenses.mit;
      platforms = pkgs.lib.platforms.linux;
    };
  };
in {
  inherit qsConfig sharkshell matugenConfig sharkColorsBin;
}
