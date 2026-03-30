{
  pkgs ? let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    nixpkgs = fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    };
  in
    import nixpkgs {overlays = [];},
  crane,
  ...
}: let
  # Manifest via Cargo.toml
  manifest = (pkgs.lib.importTOML ./Cargo.toml).package;

  craneLib = crane.mkLib pkgs;

  commonBuildInputs = with pkgs; [
    gtk4
    libadwaita
    desktop-file-utils
    glib
    openssl
    rustPlatform.bindgenHook
  ];

  commonNativeBuildInputs = with pkgs; [
    appstream-glib
    desktop-file-utils
    gettext
    git
    meson
    ninja
    pkg-config
    polkit
    wrapGAppsHook4
    openssl
    libxml2
  ];

  cargoArtifacts = craneLib.buildDepsOnly {
    src = craneLib.cleanCargoSource ./.;
    strictDeps = true;

    nativeBuildInputs = commonNativeBuildInputs;
    buildInputs = commonBuildInputs;
  };
in
  craneLib.buildPackage {
    pname = manifest.name;
    version = manifest.version;
    strictDeps = true;

    src = pkgs.lib.cleanSource ./.;
    # src = craneLib.cleanCargoSource ./.;

    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
    };

    inherit cargoArtifacts;

    nativeBuildInputs = commonNativeBuildInputs;
    buildInputs = commonBuildInputs;

    mesonFlags = [
        "-Denable_cargo_build=false"
    ];

    configurePhase = ''
      mesonConfigurePhase
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      ninjaBuildPhase
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mesonInstallPhase

      # ninjaInstallPhase

      runHook postInstall
    '';

    # buildPhaseCargoCommand = "cargo build --release";
    # installPhaseCommand = "";
    doNotPostBuildInstallCargoBinaries = true;
    checkPhase = false;
  }
