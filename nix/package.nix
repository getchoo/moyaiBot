{
  lib,
  rustPlatform,
  self ? { },
  lto ? true,
  optimizeSize ? false,
}:

let
  fs = lib.fileset;
in

rustPlatform.buildRustPackage {
  pname = "moyai-discord-bot";
  version = (lib.importTOML ../Cargo.toml).package.version or "unknown";

  src = fs.toSource {
    root = ../.;
    fileset = fs.intersection (fs.gitTracked ../.) (
      lib.fileset.unions [
        ../src
        ../Cargo.toml
        ../Cargo.lock
      ]
    );
  };

  cargoLock.lockFile = ../Cargo.lock;

  # `-C panic="abort"` breaks checks
  doCheck = !optimizeSize;

  RUSTFLAGS =
    lib.optionals lto [
      "-C"
      "embed-bitcode=yes"
      "-C"
      "lto=thin"
    ]
    ++ lib.optionals optimizeSize [
      "-C"
      "codegen-units=1"
      "-C"
      "opt-level=s"
      "-C"
      "panic=abort"
      "-C"
      "strip=symbols"
    ];

  GIT_SHA = self.shortRev or self.dirtyShortRev or "unknown";

  meta = {
    description = "funni bot";
    homepage = "https://github.com/getchoo/moyai-bot";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ getchoo ];
    mainProgram = "moyai-bot";
  };
}
