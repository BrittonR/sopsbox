{
  description = "sopsbox";

  inputs = {
    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.91.tar.gz";
    crane.url = "https://flakehub.com/f/ipetkov/crane/0.16.2.tar.gz";
    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*.tar.gz";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-schemas, nixpkgs, rust-overlay, crane, flake-utils, ... }@inputs:
    let
      overlays = [
        rust-overlay.overlays.default
        (final: prev: {
          rustToolchain = final.rust-bin.stable.latest.default.override { extensions = [ "rust-src" ]; };
        })
      ];

      supportedSystems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit overlays system; };
        craneLib = crane.lib.${system};
      });
    in {
      schemas = flake-schemas.schemas;

      packages = forEachSupportedSystem ({ pkgs, craneLib, ... }: {
        default = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          buildInputs = with pkgs; [ libiconv ];

          # Add any additional crate settings here
          # Example: doCheck = true;
        };
      });

      devShells = forEachSupportedSystem ({ pkgs, ... }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            rustToolchain
            cargo-bloat
            cargo-edit
            cargo-outdated
            cargo-udeps
            cargo-watch
            rust-analyzer
            curl
            git
            jq
            wget
            nixpkgs-fmt
          ];
          env = {
            RUST_BACKTRACE = "1";
            RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
          };
        };
      });
    };
}

