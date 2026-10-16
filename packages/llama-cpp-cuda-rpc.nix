{ pkgs }:

# llama.cpp with CUDA inference and the experimental RPC worker/client.
# Both GPU hosts must use this same derivation so the RPC protocol matches.
let
  llamaCpp = pkgs.llama-cpp.override {
    cudaSupport = true;
    rpcSupport = true;
  };
in
llamaCpp.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # Recent releases install ggml-rpc-server directly. Preserve the actual
    # executable under our stable name before replacing either alias.
    if [ ! -x "$out/bin/llama-rpc-server" ]; then
      for candidate in ggml-rpc-server rpc-server; do
        if [ -x "$out/bin/$candidate" ]; then
          cp -L "$out/bin/$candidate" "$out/bin/llama-rpc-server"
          break
        fi
      done
    fi

    if [ ! -x "$out/bin/llama-rpc-server" ]; then
      echo "llama.cpp RPC worker executable was not installed" >&2
      exit 1
    fi

    ln -sfn llama-rpc-server "$out/bin/rpc-server"
    ln -sfn llama-rpc-server "$out/bin/ggml-rpc-server"
  '';
})
