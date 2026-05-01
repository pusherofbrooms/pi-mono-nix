{
  runCommand,
  workspace,
}:
let
  root = "${workspace}/libexec/pi-mono/packages";
  mkCliOutput =
    name: bin:
    runCommand name {
      meta.mainProgram = bin;
    } ''
      mkdir -p "$out/bin"
      ln -s "${workspace}/bin/${bin}" "$out/bin/${bin}"
    '';
  mkDistOutput =
    name: pkg:
    runCommand name { } ''
      mkdir -p "$out"
      ln -s "${root}/${pkg}/dist" "$out/dist"
    '';
in
{
  workspace = workspace;

  pi = mkCliOutput "pi" "pi";
  "pi-ai" = mkCliOutput "pi-ai" "pi-ai";
  "pi-ai-lib" = mkDistOutput "pi-ai-lib" "ai";
  "pi-agent-core" = mkDistOutput "pi-agent-core" "agent";
  "pi-coding-agent" = mkDistOutput "pi-coding-agent" "coding-agent";
  "pi-tui" = mkDistOutput "pi-tui" "tui";
  "pi-web-ui" = mkDistOutput "pi-web-ui" "web-ui";
}
