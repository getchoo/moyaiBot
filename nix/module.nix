{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    getExe
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optionals
    types
    ;
  inherit (pkgs.stdenv.hostPlatform) system;

  cfg = config.services.moyai-discord-bot;

  defaultUser = "moyai-discord-bot";
  flakePackages = self.packages.${system} or (throw "getchoo/moyai-bot: ${system} is not supported");
in

{
  options.services.moyai-discord-bot = {
    enable = mkEnableOption "moyai-discord-bot";

    package = mkPackageOption flakePackages "moyai-discord-bot" { };

    user = mkOption {
      description = ''
        User under which the service should run. If this is the default value,
        the user will be created, with the specified group as the primary
        group.
      '';
      type = types.str;
      default = defaultUser;
      example = literalExpression ''
        "bob"
      '';
    };

    group = mkOption {
      description = ''
        Group under which the service should run. If this is the default value,
        the group will be created.
      '';
      type = types.str;
      default = defaultUser;
      example = literalExpression ''
        "discordbots"
      '';
    };

    redisUrl = mkOption {
      description = ''
        Connection to a redis server. If this needs to include credentials
        that shouldn't be world-readable in the Nix store, set environmentFile
        and override the `REDIS_URL` entry.
        Pass the string `local` to setup a local Redis database.
      '';
      type = types.str;
      default = "local";
      example = literalExpression ''
        "redis://localhost/"
      '';
    };

    environmentFile = mkOption {
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`
      '';
      type = types.nullOr types.path;
      default = null;
      example = literalExpression ''
        "/run/agenix.d/1/moyaiDiscordBot"
      '';
    };
  };

  imports = [
    (lib.mkRenamedOptionModule [ "services" "teawiebot" ] [ "services" "moyai-discord-bot" ])
  ];

  config = mkIf cfg.enable {
    services.redis.servers = mkIf (cfg.redisUrl == "local") {
      moyai-discord-bot = {
        enable = true;
        inherit (cfg) user;
        port = 0; # disable tcp listener
      };
    };

    systemd.services.moyai-discord-bot = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
      ] ++ optionals (cfg.redisUrl == "local") [ "redis-moyai-discord-bot.service" ];

      script = ''
        ${getExe cfg.package}
      '';

      environment = {
        REDIS_URL =
          if cfg.redisUrl == "local" then
            "unix:${config.services.redis.servers.moyai-discord-bot.unixSocket}"
          else
            cfg.redisUrl;
      };

      serviceConfig = {
        Type = "simple";
        Restart = "always";

        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;

        User = cfg.user;
        Group = cfg.group;

        # hardening
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictNamespaces = "uts ipc pid user cgroup";
        RestrictSUIDSGID = true;
        Umask = "0007";
      };
    };

    users = {
      users = mkIf (cfg.user == defaultUser) {
        ${defaultUser} = {
          isSystemUser = true;
          inherit (cfg) group;
        };
      };

      groups = mkIf (cfg.group == defaultUser) { ${defaultUser} = { }; };
    };
  };
}
