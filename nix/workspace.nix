{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
  pkg-config,
  python3,
  gcc,
  gnumake,
  cairo,
  pango,
  libjpeg,
  giflib,
  librsvg,
  pixman,
  src,
}:
let
  source = lib.cleanSource src;
  packageJsonPath = source + "/package.json";
  packageJson = lib.importJSON packageJsonPath;
in
buildNpmPackage {
  pname = "pi-monorepo-workspace";
  version = packageJson.version;
  src = source;

  # Set with fake hash first; nix will print the correct hash on first build.
  # Replace this with that value before upstreaming.
  # npmDepsHash = lib.fakeHash;
  npmDepsHash = "sha256-lgNI1JzfLUpktxeu7uvGF1SRGoblY7JfOQsPyMH5b+k=";

  # Build all workspace packages in repo-defined order.
  npmBuildScript = "build";

  # Keep repository sources untouched: adjust build behavior only inside derivation.
  preBuild = ''
    npm pkg set scripts.build="tsgo -p tsconfig.build.json" --workspace=packages/ai
  '';

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3
    gcc
    gnumake
  ];

  buildInputs = [
    cairo
    pango
    libjpeg
    giflib
    librsvg
    pixman
  ];

  installPhase = ''
    runHook preInstall

    root="$out/libexec/pi-mono"
    mkdir -p "$root/packages"

    cp package.json package-lock.json "$root/"
    cp -R node_modules "$root/"

    for pkg in ai agent coding-agent mom pods tui web-ui; do
      mkdir -p "$root/packages/$pkg"
      cp packages/$pkg/package.json "$root/packages/$pkg/"
      cp -R packages/$pkg/dist "$root/packages/$pkg/"
    done

    # Runtime entrypoints exported from @mariozechner/pi-ai.
    # Upstream moved oauth artifacts into dist/; keep compatibility with both layouts.
    if [ -f packages/ai/oauth.js ]; then
      cp packages/ai/oauth.js "$root/packages/ai/"
      cp packages/ai/oauth.d.ts "$root/packages/ai/"
    else
      cp packages/ai/dist/oauth.js "$root/packages/ai/dist/"
      cp packages/ai/dist/oauth.d.ts "$root/packages/ai/dist/"
    fi
    cp packages/ai/bedrock-provider.js "$root/packages/ai/"
    cp packages/ai/bedrock-provider.d.ts "$root/packages/ai/"

    # Runtime docs/assets used by coding-agent package commands.
    cp -R packages/coding-agent/docs "$root/packages/coding-agent/"
    cp -R packages/coding-agent/examples "$root/packages/coding-agent/"
    cp packages/coding-agent/CHANGELOG.md "$root/packages/coding-agent/"
    cp packages/coding-agent/README.md "$root/packages/coding-agent/"

    mkdir -p "$out/bin"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/pi" --add-flags "$root/packages/coding-agent/dist/cli.js"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/pi-ai" --add-flags "$root/packages/ai/dist/cli.js"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/pi-pods" --add-flags "$root/packages/pods/dist/cli.js"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/mom" --add-flags "$root/packages/mom/dist/main.js"

    runHook postInstall
  '';

  # This workspace contains many prebuilt/native Node artifacts;
  # fixup's ELF patching can fail on intermediate build artifacts (like .o files)
  # in node_modules, so we disable it.
  dontFixup = true;

  meta = {
    description = "Built workspace artifacts for the pi monorepo";
    mainProgram = "pi";
    platforms = lib.platforms.unix;
  };
}
