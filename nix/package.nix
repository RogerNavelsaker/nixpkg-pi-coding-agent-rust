{ bash, fetchFromGitHub, lib, makeWrapper, runCommand, rustPlatform, sqlite }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  upstreamSrc = fetchFromGitHub {
    owner = manifest.source.owner;
    repo = manifest.source.repo;
    rev = manifest.source.rev;
    hash = manifest.source.hash;
  };
  sourceRoot = runCommand "${manifest.binary.name}-${manifest.source.version}-src" { } ''
    mkdir -p "$out"
    cp ${upstreamSrc}/Cargo.toml "$out/Cargo.toml"
    cp ${upstreamSrc}/Cargo.lock "$out/Cargo.lock"
    if [ -f ${upstreamSrc}/build.rs ]; then
      cp ${upstreamSrc}/build.rs "$out/build.rs"
    fi
    cp -R ${upstreamSrc}/src/. "$out/src/"
    cp ${upstreamSrc}/CHANGELOG.md "$out/CHANGELOG.md"
    mkdir -p "$out/legacy_pi_mono_code/pi-mono/packages/ai/src"
    cp ${upstreamSrc}/legacy_pi_mono_code/pi-mono/packages/ai/src/models.generated.ts \
      "$out/legacy_pi_mono_code/pi-mono/packages/ai/src/models.generated.ts"
    mkdir -p "$out/docs/schema"
    cp ${upstreamSrc}/docs/extension-artifact-provenance.json "$out/docs/extension-artifact-provenance.json"
    cp ${upstreamSrc}/docs/provider-upstream-model-ids-snapshot.json "$out/docs/provider-upstream-model-ids-snapshot.json"
    cp ${upstreamSrc}/docs/schema/extension_protocol.json "$out/docs/schema/extension_protocol.json"
    if [ -d ${upstreamSrc}/benches ]; then
      cp -R ${upstreamSrc}/benches/. "$out/benches/"
    fi
  '';
  builtBinary = manifest.binary.upstreamName or manifest.binary.name;
  aliasOutputs = manifest.binary.aliases or [ ];
  aliasScripts = lib.concatMapStrings
    (
      alias:
      ''
        cat > "$out/bin/${alias}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" "\$@"
EOF
        chmod +x "$out/bin/${alias}"
      ''
    )
    aliasOutputs;
in
rustPlatform.buildRustPackage {
  pname = manifest.binary.name;
  version = manifest.source.version;
  src = sourceRoot;

  cargoLock = {
    lockFile = sourceRoot + "/Cargo.lock";
    outputHashes = {
      # Hash of the crates.io source archive referenced by Cargo.lock.
      "loom-0.7.2" = "sha256-qjgx6rTMWLl5ZRgWDwYJE6Q0n3qeuXdkjL1JXTW+alo=";
    };
  };

  cargoBuildFlags =
    (lib.optionals (manifest.binary ? package) [ "-p" manifest.binary.package ])
    ++ [ "--bin=${builtBinary}" ];

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ sqlite ];
  doCheck = false;

  # ftui-widgets 0.7.0 uses the still-unstable isolate_* integer methods.
  # The upstream package enables RUSTC_BOOTSTRAP, but the dependency itself
  # does not declare the corresponding feature gate.
  preBuild = ''
    ftui_widgets_src="$NIX_BUILD_TOP/cargo-vendor-dir/ftui-widgets-0.7.0/src/lib.rs"
    ftui_widgets_tmp=$(mktemp)
    printf '%s\n' '#![feature(isolate_most_least_significant_one)]' > "$ftui_widgets_tmp"
    cat "$ftui_widgets_src" >> "$ftui_widgets_tmp"
    mv "$ftui_widgets_tmp" "$ftui_widgets_src"
  '';

  env = {
    RUSTC_BOOTSTRAP = "1";
    VERGEN_IDEMPOTENT = "1";
    VERGEN_GIT_SHA = manifest.source.rev;
    VERGEN_GIT_DIRTY = "false";
  };

  postInstall = ''
    if [ "${builtBinary}" != "${manifest.binary.name}" ]; then
      mv "$out/bin/${builtBinary}" "$out/bin/${manifest.binary.name}"
    fi
    ${aliasScripts}
  '';

  meta = with lib; {
    description = manifest.meta.description;
    homepage = manifest.meta.homepage;
    license = licenses.mit;
    mainProgram = manifest.binary.name;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
