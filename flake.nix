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
      in {
        packages = rec {
          default = moa;
          moa = pkgs.writeScriptBin "moa" ''
            #!${pkgs.bash}/bin/bash
            cd ${pkgs.lib.escapeShellArg moa-src-conf}
            ${python}/bin/gunicorn "$@" app:app
          '';
          moa-worker = pkgs.writeScriptBin "moa-worker" ''
            #!${pkgs.bash}/bin/bash
            cd ${pkgs.lib.escapeShellArg moa-src-conf}
            ${python}/bin/python -m moa.worker
          '';
          moa-models = pkgs.writeScriptBin "moa-models" ''
            #!${pkgs.bash}/bin/bash
            cd ${pkgs.lib.escapeShellArg moa-src-conf}
            ${python}/bin/python -m moa.models
          '';
          moa-src-conf = pkgs.runCommand "moa" {} ''
            cp -r ${pkgs.lib.escapeShellArg moa-src} "$out"
            chmod u+w "$out"
            chmod -R +w "$out"/logs
            rm -r "$out"/logs
            ln -s /etc/moa.conf "$out"/config.py
            ln -s /var/lib/moa/logs "$out"/logs
          '';
        };
      }
    ) // {
      nixosModules."moa" = { config, lib, pkgs, ... }:
      with lib;
      let
        system = pkgs.hostPlatform.config;
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
            type = types.string;
            default = "127.0.0.1:8000";
            description = ''
              Address the server will listen on. Accepts any address accepted by gunicorn.
            '';
          };
          frequency = mkOption {
            type = types.int;
            default = 60;
            description = ''
              How frequently to run the worker that automatically makes pending posts.
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
            serviceConfig = {
              Type = "oneshot";
              User = "moa";
              ExecStart = lib.escapeShellArgs [ "${self.packages.${system}.moa-worker}/bin/moa-worker" ];
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
        };
      };
    };
}
