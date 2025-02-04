{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:

    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;
    in
    {
      checks = forAllSystems (
        system:

        let
          pkgs = nixpkgs.legacyPackages.${system};

          mkCheck =
            name: nativeBuildInputs: script:
            pkgs.runCommand "check-${name}" { inherit nativeBuildInputs; } ''
              ${script} | tee $out
            '';
        in

        {
          clippy-sarif = pkgs.stdenv.mkDerivation {
            name = "check-clippy-sarif";
            inherit (self.packages.${system}.moyai-discord-bot) src cargoDeps;

            nativeBuildInputs = [
              pkgs.cargo
              pkgs.clippy
              pkgs.clippy-sarif
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustc
              pkgs.sarif-fmt
            ];

            buildPhase = ''
              runHook preBuild

              cargo clippy \
                --all-features \
                --all-targets \
                --tests \
                --message-format=json \
              | clippy-sarif | tee $out | sarif-fmt

              runHook postBuild
            '';
          };

          actionlint = mkCheck "actionlint" [ pkgs.actionlint ] "actionlint ${self}/.github/workflows/*";
          deadnix = mkCheck "deadnix" [ pkgs.deadnix ] "deadnix check ${self}";
          nixfmt = mkCheck "nixfmt" [
            pkgs.nixfmt-rfc-style
          ] "find ${self} -type f -name '*.nix' | xargs nixfmt --check";
          rustfmt = mkCheck "rustfmt" [ pkgs.cargo pkgs.rustfmt ] "cd ${self} && cargo fmt -- --check";
          statix = mkCheck "statix" [ pkgs.statix ] "statix check ${self}";
        }
      );

      devShells = forAllSystems (
        system:

        let
          pkgs = nixpkgs.legacyPackages.${system};
        in

        {
          default = pkgs.mkShell {
            packages = [
              # rust tools
              pkgs.clippy
              pkgs.rustfmt
              pkgs.rust-analyzer

              # nix tools
              pkgs.nil
              pkgs.statix

              # misc formatter/linters
              pkgs.actionlint
              self.formatter.${system}

              pkgs.redis
            ];

            inputsFrom = [ self.packages.${system}.moyai-discord-bot ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };

          ci = pkgs.mkShell {
            packages = [
              pkgs.clippy
              pkgs.rustfmt

              self.formatter.${system}
            ];

            inputsFrom = [ self.packages.${system}.moyai-discord-bot ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      nixosModules.default = lib.modules.importApply ./nix/module.nix { inherit self; };

      packages = forAllSystems (
        system:

        let
          pkgs = nixpkgs.legacyPackages.${system};
          packages' = self.packages.${system};

          staticWith = pkgs.callPackage ./nix/static.nix { inherit self; };
          containerize = pkgs.callPackage ./nix/containerize.nix { };
        in

        {
          container-amd64 = containerize packages'.static-x86_64;
          container-arm64 = containerize packages'.static-aarch64;

          static-x86_64 = staticWith { arch = "x86_64"; };
          static-aarch64 = staticWith { arch = "aarch64"; };

          moyai-discord-bot = pkgs.callPackage ./nix/package.nix { inherit self; };

          default = self.packages.${system}.moyai-discord-bot;
        }
      );
    };
}
