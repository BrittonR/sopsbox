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

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    crane,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        craneLib = crane.lib.${system};

        pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };

        # libPath =  with pkgs; lib.makeLibraryPath [
        # ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          cmake
          makeWrapper
        ];

        buildInputs = with pkgs; [
        ];

        cargoArtifacts = craneLib.buildDepsOnly ({
          src = craneLib.cleanCargoSource (craneLib.path ./.);
          inherit buildInputs nativeBuildInputs;
          pname = "sopbxo";
        });
      in with pkgs; {
        packages = rec {
          sopsbox= craneLib.buildPackage {
            src = craneLib.path ./.;

            inherit buildInputs nativeBuildInputs cargoArtifacts;

            postInstall = ''
              # for _size in "16x16" "32x32" "48x48" "64x64" "128x128" "256x256"; do
              #     echo $src
              #     install -Dm644 "$src/data/icons/$_size/apps/ytdlp-gui.png" "$out/share/icons/hicolor/$_size/apps/ytdlp-gui.png"
              # done
              # install -Dm644 "$src/data/applications/ytdlp-gui.desktop" -t "$out/share/applications/"

              patchelf --set-rpath ${libPath} $out/bin/sopsbox

              # wrapProgram $out/bin/ytdlp-gui \
              #   --prefix PATH : ${lib.makeBinPath [ pkgs.gnome.zenity pkgs.libsForQt5.kdialog]}\
            '';

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
