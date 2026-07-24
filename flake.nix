{
  description = "Nix flake for the pi monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pi-mono = {
      url = "github:earendil-works/pi?ref=v0.82.0";
      flake = false;
    };
    # Generated model values are gitignored upstream but included in pi-ai's
    # published package. Pin that package as a separate, immutable build input.
    pi-ai-release = {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.82.0.tgz";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, flake-utils, pi-mono, pi-ai-release }@inputs:
    flake-utils.lib.eachSystem
      [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          piSrc = inputs."pi-mono";
          workspace = pkgs.callPackage ./nix/workspace.nix {
            src = piSrc;
            modelDataSrc = inputs."pi-ai-release";
          };
          packageSet = import ./nix/packages.nix {
            inherit workspace;
            inherit (pkgs) runCommand;
          };
          containerRuntimeTools = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
            pkgs.fd
            pkgs.ripgrep
          ];
          containerPath = pkgs.lib.makeBinPath containerRuntimeTools;
          mkContainerImage = imageName: drv: bin: pkgs.dockerTools.buildLayeredImage {
            name = imageName;
            tag = "latest";
            contents = [
              drv
              pkgs.cacert
            ] ++ containerRuntimeTools;
            config = {
              Entrypoint = [ "${drv}/bin/${bin}" ];
              Env = [
                "PATH=${containerPath}"
                "SHELL=${pkgs.bash}/bin/bash"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "NODE_EXTRA_CA_CERTS=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
            };
          };
          containerSet = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            "pi-container" = mkContainerImage "pi" packageSet.pi "pi";
            "pi-ai-container" = mkContainerImage "pi-ai" packageSet."pi-ai" "pi-ai";
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
          packages = packageSet // containerSet // { default = packageSet.pi; };

          apps = {
            default = mkApp packageSet.pi "pi coding agent CLI";
            pi = mkApp packageSet.pi "pi coding agent CLI";
            "pi-ai" = mkApp packageSet."pi-ai" "pi AI provider auth helper CLI";
          };

          devShells = {
            default = devShell;
          };
        }
      );
}
