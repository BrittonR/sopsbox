{
  description = "sopsbox";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , crane
    , rust-overlay
    , ...
    }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        craneLib = crane.lib.${system};

        pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };


        nativeBuildInputs = with pkgs; [
          pkg-config
          cmake
          makeWrapper
        ];

        buildInputs = [
        ] ++ nixpkgs.lib.optionals pkgs.stdenv.isDarwin [
          # Additional darwin specific inputs can be set here
          pkgs.libiconv
        ];
        cargoArtifacts = craneLib.buildDepsOnly ({
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          inherit buildInputs nativeBuildInputs;
          pname = "sopbox";
        });
      in
      with pkgs; {
        packages = rec {
          sopsbox = craneLib.buildPackage {
            src = craneLib.path ./.;

            inherit buildInputs nativeBuildInputs cargoArtifacts;


            GIT_HASH = self.rev or self.dirtyRev;
          };

          default = sopsbox;
        };

        devShell = mkShell {
          inherit buildInputs nativeBuildInputs;

          packages = with pkgs; [
            (rust-bin.stable.latest.default.override {
              extensions = [ "rust-src" "rust-analyzer" ];
            })
            cargo-watch
          ];
          LD_LIBRARY_PATH = "${libPath}";
        };
      }) // {
      overlay = final: prev: {
        inherit (self.packages.${final.system}) sopsbox;
      };
    };
}
