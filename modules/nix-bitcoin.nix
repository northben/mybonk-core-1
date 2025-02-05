{ config, options, pkgs, lib, ... }:

with lib;
{
  options = {
    nix-bitcoin = {
      pkgs = mkOption {
        type = types.attrs;
        default = (import ../pkgs { inherit pkgs; }).modulesPkgs;
        defaultText = "nix-bitcoin/pkgs.modulesPkgs";
        apply = base:
          let
            final = foldl (prev: overlay:
              prev // (overlay prev final)
            ) base options.nix-bitcoin.pkgOverlays.definitions;
          in
            final;
      };

      pkgOverlays = mkOption {
        internal = true;
        type = with types; functionTo attrs;
      };

      lib = mkOption {
        readOnly = true;
        default = import ../pkgs/lib.nix lib pkgs config;
        defaultText = "nix-bitcoin/pkgs/lib.nix";
      };

      torClientAddressWithPort = mkOption {
        readOnly = true;
        default = with config.services.tor.client.socksListenAddress;
          "${addr}:${toString port}";
        defaultText = "(See source)";
      };

      # Torify binary that works with custom Tor SOCKS addresses
      # Related issue: https://github.com/NixOS/nixpkgs/issues/94236
      torify = mkOption {
        readOnly = true;
        default = pkgs.writers.writeBashBin "torify" ''
          ${pkgs.tor}/bin/torify \
            --address ${config.services.tor.client.socksListenAddress.addr} \
            "$@"
        '';
        defaultText = "(See source)";
      };

      # A helper for using doas instead of sudo when doas is enabled
      runAsUserCmd = mkOption {
        readOnly = true;
        default = if config.security.doas.enable
                  then "doas -u"
                  else "sudo -u";
        defaultText = "(See source)";
      };
    };
  };
}
