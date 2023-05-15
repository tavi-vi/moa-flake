{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    mach-nix.url = "github:DavHau/mach-nix";
    moa-src = {
      url = "gitlab:fedstoa/moa";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, moa-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = mach-nix.lib.${system}.mkPython {
          requirements = builtins.readFile ./requirements.txt;
        };
        dataDir = "/var/lib/moa";
        moaPrelude = configPrefix: ''
          export PYTHONPATH="${self.packages.${system}.moa-src-patched}:''${PYTHONPATH:+:$PYTHONPATH}"
          export MOA_CONFIG="${configPrefix}ProductionConfig"
          cd ${dataDir}
        '';
      in {
        packages = rec {
          default = moa;
          moa = pkgs.writeScriptBin "moa" ''
            #!${pkgs.bash}/bin/bash
            ${moaPrelude "config."}
            ${python}/bin/gunicorn "$@" app:app
          '';
          moa-worker = pkgs.writeScriptBin "moa-worker" ''
            #!${pkgs.bash}/bin/bash
            ${moaPrelude ""}
            ${python}/bin/python -m moa.worker
          '';
          moa-models = pkgs.writeScriptBin "moa-models" ''
            #!${pkgs.bash}/bin/bash
            ${moaPrelude ""}
            ${python}/bin/python -m moa.models
          '';
          moa-src-patched = pkgs.runCommand "moa" {} ''
            cp -r ${moa-src} $out
            chmod -R u+w $out
            ln -s /etc/moa.conf "$out"/config.py
            patch -p2 -d $out <"${self}"/postgres.patch
          '';
        };
      }
    ) // {
      nixosModules."moa" = { config, lib, pkgs, ... }:
      with lib;
      let
        system = pkgs.hostPlatform.system;
        cfg = config.services.moa;
      in {
        options.services.moa = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Enables the Moa crossposter webserver.
            '';
          };
          listenAddress = mkOption {
            type = types.str;
            default = "127.0.0.1:8000";
            description = ''
              Address the server will listen on. Accepts any address accepted by gunicorn.
            '';
          };
          frequency = mkOption {
            type = types.int;
            default = 60;
            description = ''
              How frequently to run the worker that automatically makes pending posts, in seconds.
            '';
          };
          timeout = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = ''
              How long to wait before killing the woker, in seconds. If unset, it is four times the time specified for frequency.
            '';
          };
        };
        config = {
          systemd.services.moa = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              User = "moa";
              ExecStart = lib.escapeShellArgs [ "${self.packages.${system}.moa}/bin/moa" "-b" cfg.listenAddress ];
              RestartSec = "2s";
              Restart = "on-failure";
            };
          };
          systemd.services.moa-worker = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "moa";
              ExecStart = lib.escapeShellArgs [ "${self.packages.${system}.moa-worker}/bin/moa-worker" ];
              TimeoutSec = if !(isNull cfg.timeout)
                then (toString cfg.timeout)
                else (toString (cfg.frequency * 4));
            };
          };
          systemd.timers.moa-worker = {
            wantedBy = [ "timers.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            timerConfig = {
              OnUnitActiveSec = builtins.toString cfg.frequency;
              Unit = "moa-worker.service";
            };
          };
          users.users.moa = {
            isSystemUser = true;
            group = "moa";
          };
          users.groups.moa = {};
        };
      };
    };
}
