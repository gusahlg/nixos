# Two-PC CUDA + llama.cpp RPC.
#
# sighurt (RTX 3070) is the master: it runs llama-cli / llama-server and
# offloads tensors to the worker over Ethernet.
# louise (RTX 4060) is the worker: it runs llama-rpc-server on TCP 50052.
#
# RPC is experimental and not authenticated. The worker binds only to the
# LAN IPv4 address (never Tailscale / 0.0.0.0) and the firewall accepts
# that port only from `lanCidr`. Do not port-forward 50052 on the router.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.distributedGpu;
  llamaCpp = import ../packages/llama-cpp-cuda-rpc.nix { inherit pkgs; };

  rpcStart = pkgs.writeShellScript "llama-rpc-server-start" ''
    set -euo pipefail

    # Bind the unauthenticated RPC socket to the RFC1918 Ethernet address
    # only. `trustedInterfaces = [ "tailscale0" ]` would otherwise expose
    # 0.0.0.0:50052 to the whole tailnet.
    lan_ip=""
    while read -r _dev _ _fam addr _; do
      lan_ip="''${addr%%/*}"
      break
    done < <(${pkgs.iproute2}/bin/ip -4 -o addr show to ${lib.escapeShellArg cfg.lanCidr})

    if [ -z "$lan_ip" ]; then
      echo "llama-rpc-server: no IPv4 address in ${cfg.lanCidr}; refusing to bind RPC on a non-LAN interface" >&2
      exit 1
    fi

    rpc_bin=""
    for candidate in llama-rpc-server rpc-server ggml-rpc-server; do
      if [ -x "${llamaCpp}/bin/$candidate" ]; then
        rpc_bin="${llamaCpp}/bin/$candidate"
        break
      fi
    done

    if [ -z "$rpc_bin" ]; then
      echo "llama-rpc-server: llama.cpp was built without an RPC worker binary" >&2
      exit 1
    fi

    echo "llama-rpc-server: binding $rpc_bin to $lan_ip:${toString cfg.rpcPort}" >&2
    exec "$rpc_bin" --host "$lan_ip" --port ${toString cfg.rpcPort} -c
  '';
in
{
  options.distributedGpu = {
    enable = lib.mkEnableOption "NVIDIA CUDA, llama.cpp with RPC, and LAN mDNS for the two-PC GPU setup";

    role = lib.mkOption {
      type = lib.types.enum [
        "master"
        "worker"
      ];
      description = ''
        `master` is the RTX 3070 host (sighurt): llama-cli / llama-server.
        `worker` is the RTX 4060 host (louise): llama-rpc-server on the LAN.
      '';
    };

    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 50052;
      description = "TCP port for llama.cpp RPC. Keep this off the public Internet.";
    };

    lanCidr = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
      description = "IPv4 subnet that may open the RPC port and that the worker will bind on.";
    };

    workerHost = lib.mkOption {
      type = lib.types.str;
      default = "louise.local";
      description = "mDNS hostname of the RPC worker, used by the master via $LLAMA_RPC_WORKER.";
    };

    autoStartWorker = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start llama-rpc-server at boot on the worker. No effect on the master.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Build CUDA kernels only for these two cards: 3070 is 8.6, 4060 is 8.9.
    nixpkgs.config.cudaCapabilities = [
      "8.6"
      "8.9"
    ];

    # CUDA packages are unfree and not on cache.nixos.org.
    nix.settings = {
      substituters = [ "https://cache.nixos-cuda.org" ];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
    };

    hardware.nvidia.nvidiaPersistenced = true;
    hardware.nvidia.nvidiaSettings = lib.mkDefault true;

    # Keep CUDA usable after the display manager has not yet started (worker
    # at boot) and for compute jobs generally.
    boot.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    services.openssh.enable = true;

    # Stable LAN names without DHCP reservations: sighurt.local / louise.local.
    # RPC must use these (or a 192.168.1.x address), not Tailscale, because
    # the current link is 1 GbE and the tailnet would add latency.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    users.users.gusahlg.extraGroups = [
      "video"
      "render"
    ];

    users.users.gusahlg.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjkDOw36d9LqkJ6luwXicOou/zBniUHNZNoRH4OycrY nixos-pc"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII3n+0ub5N5WkzhLOq0ZPZcjeDVBMrjIFDyruOEwSEcm gustav@Fredriks-Air.localdomain"
    ];

    programs.ssh.extraConfig = ''
      Host louise-lan
        HostName louise.local
        User gusahlg
        IdentityFile ~/.ssh/id_ed25519

      Host sighurt-lan
        HostName sighurt.local
        User gusahlg
        IdentityFile ~/.ssh/id_ed25519
    '';

    environment.variables = lib.mkIf (cfg.role == "master") {
      LLAMA_RPC_WORKER = "${cfg.workerHost}:${toString cfg.rpcPort}";
    };

    # If Ollama is enabled on this host, use the same NVIDIA stack. It is
    # independent of llama.cpp RPC and must not be mixed with mining.
    services.ollama.package = lib.mkIf config.services.ollama.enable (
      lib.mkDefault pkgs.ollama-cuda
    );

    environment.systemPackages = [
      llamaCpp
      pkgs.nvtopPackages.full
      pkgs.pciutils
      pkgs.iperf3
      pkgs.cudatoolkit
      pkgs.cudaPackages.libcublas
      pkgs.git
      pkgs.cmake
      pkgs.ninja
      pkgs.gnumake
      pkgs.pkg-config
    ];

    users.users.llama-rpc = lib.mkIf (cfg.role == "worker") {
      isSystemUser = true;
      group = "llama-rpc";
      extraGroups = [
        "video"
        "render"
      ];
      home = "/var/lib/llama-rpc";
    };

    users.groups.llama-rpc = lib.mkIf (cfg.role == "worker") { };

    systemd.services.llama-rpc-server = lib.mkIf (cfg.role == "worker") {
      description = "llama.cpp RPC worker (LAN-only, experimental, unauthenticated)";
      documentation = [ "https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md" ];
      after = [
        "network-online.target"
        "nvidia-persistenced.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = lib.optionals cfg.autoStartWorker [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = rpcStart;
        Restart = "on-failure";
        RestartSec = "5s";
        StartLimitBurst = 5;
        User = "llama-rpc";
        Group = "llama-rpc";
        SupplementaryGroups = [
          "video"
          "render"
        ];
        StateDirectory = "llama-rpc";
        CacheDirectory = "llama-rpc";
        Environment = [
          "HOME=/var/lib/llama-rpc"
          "LLAMA_CACHE=/var/cache/llama-rpc"
        ];
        # CUDA maps executable pages; MDWE would abort kernel launch.
        MemoryDenyWriteExecute = false;
        PrivateDevices = false;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        NoNewPrivileges = true;
      };
    };

    # Accept RPC only from the LAN. Not listed in allowedTCPPorts, so WAN
    # and (because of the bind address) Tailscale never reach the worker.
    networking.firewall.extraCommands = lib.mkIf (cfg.role == "worker") ''
      iptables -A nixos-fw -p tcp --dport ${toString cfg.rpcPort} -s ${cfg.lanCidr} -j nixos-fw-accept
    '';
    networking.firewall.extraStopCommands = lib.mkIf (cfg.role == "worker") ''
      iptables -D nixos-fw -p tcp --dport ${toString cfg.rpcPort} -s ${cfg.lanCidr} -j nixos-fw-accept || true
    '';
  };
}
