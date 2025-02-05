{ lib, config, ... }:

with lib;
let
  mkRenamedAnnounceTorOption = service:
    # use mkRemovedOptionModule because mkRenamedOptionModule fails with an infinite recursion error
    mkRemovedOptionModule [ "services" service "announce-tor" ] ''
      Use option `nix-bitcoin.onionServices.${service}.public` instead.
    '';

  mkSplitEnforceTorOption = service:
    (mkRemovedOptionModule [ "services" service "enforceTor" ] ''
      The option has been split into options `tor.proxy` and `tor.enforce`.
      Set `tor.proxy = true` to proxy outgoing connections with Tor.
      Set `tor.enforce = true` to only allow connections (incoming and outgoing) through Tor.
    '');
  mkRenamedEnforceTorOption = service:
    (mkRenamedOptionModule [ "services" service "enforceTor" ] [ "services" service "tor" "enforce" ]);

in {
  imports = [
    (mkRenamedOptionModule [ "services" "bitcoind" "bind" ] [ "services" "bitcoind" "address" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcallowip" ] [ "services" "bitcoind" "rpc" "allowip" ])
    (mkRenamedOptionModule [ "services" "bitcoind" "rpcthreads" ] [ "services" "bitcoind" "rpc" "threads" ])
    (mkRenamedOptionModule [ "services" "clightning" "bind-addr" ] [ "services" "clightning" "address" ])
    (mkRenamedOptionModule [ "services" "clightning" "bindport" ] [ "services" "clightning" "port" ])
    (mkRenamedOptionModule [ "services" "spark-wallet" "host" ] [ "services" "spark-wallet" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "rpclisten" ] [ "services" "lnd" "rpcAddress" ])
    (mkRenamedOptionModule [ "services" "lnd" "listen" ] [ "services" "lnd" "address" ])
    (mkRenamedOptionModule [ "services" "lnd" "listenPort" ] [ "services" "lnd" "port" ])
    (mkRenamedOptionModule [ "services" "btcpayserver" "bind" ] [ "services" "btcpayserver" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "bind" ] [ "services" "liquidd" "address" ])
    (mkRenamedOptionModule [ "services" "liquidd" "rpcbind" ] [ "services" "liquidd" "rpc" "address" ])
    # 0.0.70
    (mkRenamedOptionModule [ "services" "rtl" "cl-rest" ] [ "services" "clightning-rest" ])

    (mkRenamedOptionModule [ "nix-bitcoin" "setup-secrets" ] [ "nix-bitcoin" "setupSecrets" ])

    (mkRenamedAnnounceTorOption "clightning")
    (mkRenamedAnnounceTorOption "lnd")

    # 0.0.53
    (mkRemovedOptionModule [ "services" "electrs" "high-memory" ] ''
      This option is no longer supported by electrs 0.9.0. Electrs now always uses
      bitcoin peer connections for syncing blocks. This performs well on low and high
      memory systems.
    '')
    # 0.0.86
    (mkRemovedOptionModule [ "services" "lnd" "restOnionService" "enable" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
    (mkRemovedOptionModule [ "services" "lnd" "lndconnectOnion" ] ''
      Set the following options instead:
      services.lnd.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
    (mkRemovedOptionModule [ "services" "clightning-rest" "lndconnectOnion" ] ''
      Set the following options instead:
      services.clightning-rest.lndconnect = {
        enable = true;
        onion = true;
      }
    '')
  ] ++
  # 0.0.59
  (map mkSplitEnforceTorOption [
    "clightning"
    "lightning-loop"
    "lightning-pool"
    "liquid"
    "lnd"
    "spark-wallet"
    "bitcoind"
  ]) ++
  (map mkRenamedEnforceTorOption [
    "btcpayserver"
    "rtl"
    "electrs"
  ]) ++
  # 0.0.77
  (
    let
      optionName = [ "services" "clightning" "plugins" "commando" ];
    in [
      (mkRemovedOptionModule (optionName ++ [ "enable" ]) ''
        clightning 0.12.0 ships with a reimplementation of the commando plugin
        that is incompatible with the commando module that existed in
        nix-bitcoin. The new built-in commando plugin is always enabled. For
        information on how to use it, run `lightning-cli help commando` and
        `lightning-cli help commando-rune`.
      '')
      (mkRemovedOptionModule (optionName ++ [ "readers" ]) "")
      (mkRemovedOptionModule (optionName ++ [ "writers" ]) "")
  ]);

  config = {
    # Migrate old clightning-rest datadir from nix-bitcoin versions < 0.0.70
    systemd.services.clightning-rest-migrate-datadir = let
      inherit (config.services) clightning-rest clightning;
    in mkIf config.services.clightning-rest.enable {
      requiredBy = [ "clightning-rest.service" ];
      before = [ "clightning-rest.service" ];
      script = ''
        if [[ -e /var/lib/cl-rest/certs ]]; then
          mv /var/lib/cl-rest/* '${clightning-rest.dataDir}'
          chown -R ${clightning.user}: '${clightning-rest.dataDir}'
          rm -r /var/lib/cl-rest
        fi
      '';
      serviceConfig.Type = "oneshot";
    };
  };
}
