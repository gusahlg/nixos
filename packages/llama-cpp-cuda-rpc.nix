{ pkgs }:

# llama.cpp with CUDA inference and the experimental RPC worker/client.
# Both GPU hosts must use this same derivation so the RPC protocol matches.
let
  inherit (pkgs) lib;
  llamaCpp = pkgs.llama-cpp.override {
    cudaSupport = true;
    rpcSupport = true;
  };
in
llamaCpp.overrideAttrs (old: {
  postInstall =
    let
      original = old.postInstall or "";
      # nixpkgs copies `bin/rpc-server` into `llama-rpc-server`. Upstream has
      # also shipped that worker as `ggml-rpc-server`, so accept either name.
      patched = lib.replaceStrings
        [ "cp bin/rpc-server $out/bin/llama-rpc-server" ]
        [ ''
            if [ -e bin/rpc-server ]; then
              cp bin/rpc-server $out/bin/llama-rpc-server
            elif [ -e bin/ggml-rpc-server ]; then
              cp bin/ggml-rpc-server $out/bin/llama-rpc-server
            else
              echo "llama.cpp RPC worker binary was not produced by the build" >&2
              ls -la bin >&2 || true
              exit 1
            fi
          '' ]
        original;
    in
    patched
    + ''
      ln -sfn llama-rpc-server $out/bin/rpc-server
      ln -sfn llama-rpc-server $out/bin/ggml-rpc-server
    '';
})
