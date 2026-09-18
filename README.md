# sharkshell

Quickshell desktop shell with a native `wlr-output-power-management-v1` QML plugin.

## Any distro with Nix:

```sh
nix run github:Matko802/sharkshell
```

### As flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sharkshell = {
      url = "github:Matko802/sharkshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, sharkshell, ... }: {
    packages.x86_64-linux.default = sharkshell.packages.x86_64-linux.default;
  };
}
```

### As overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sharkshell = {
      url = "github:Matko802/sharkshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, sharkshell, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            nixpkgs.overlays = [ sharkshell.overlays.default ];
            environment.systemPackages = [ sharkshell.packages.${system}.default ];
          }
        ];
      };
    };
}
```

## Outputs

- `sharkshell` (default): wrapped Quickshell with the Power plugin
- `sharkshell-config`: the QML config tree
- `output-power`: the native QML plugin alone
