{
  description = "Nix flake for the pi monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pi-mono = {
      url = "github:badlogic/pi-mono?ref=v0.54.2";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, flake-utils, pi-mono }@inputs:
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          piSrc = inputs."pi-mono";
          workspace = pkgs.callPackage ./nix/workspace.nix {
            src = piSrc;
          };
          packageSet = import ./nix/packages.nix {
            inherit workspace;
            inherit (pkgs) runCommand;
          };
          devShell = import ./nix/devshell.nix {
            inherit (pkgs)
              lib
              stdenv
              mkShell
              nodejs_22
              git
              ripgrep
              fd
              bun
              pkg-config
              python3
              gcc
              gnumake
              cairo
              pango
              libjpeg
              giflib
              librsvg
              pixman
              ;
          };
          mkApp =
            drv: description:
            {
              type = "app";
              program = "${drv}/bin/${drv.meta.mainProgram or drv.pname}";
              meta = (drv.meta or { }) // { inherit description; };
            };
        in
        {
          packages = packageSet // { default = packageSet.pi; };

          apps = {
            default = mkApp packageSet.pi "pi coding agent CLI";
            pi = mkApp packageSet.pi "pi coding agent CLI";
            "pi-ai" = mkApp packageSet."pi-ai" "pi AI provider auth helper CLI";
            "pi-pods" = mkApp packageSet."pi-pods" "pi GPU pod management CLI";
            mom = mkApp packageSet."pi-mom" "mom multi-agent orchestrator CLI";
          };

          devShells = {
            default = devShell;
          };
        }
      );
}
