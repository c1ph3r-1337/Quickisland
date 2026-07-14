{
  config,
  lib,
  ...
}:
let
  cfg = config.services.quickisland-shell;
in
{
  options.services.quickisland-shell = {
    enable = lib.mkEnableOption "Quickisland shell systemd service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The quickisland-shell package to use";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "The systemd target for the quickisland-shell service.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      ''
        Running quickisland-shell as a systemd service has been deprecated!
        See https://docs.quickisland.dev/getting-started/nixos/#running-the-shell for details.
      ''
    ];
    systemd.user.services.quickisland-shell = {
      description = "Quickisland Shell - Wayland desktop shell";
      documentation = [ "https://docs.quickisland.dev" ];
      after = [ cfg.target ];
      partOf = [ cfg.target ];
      wantedBy = [ cfg.target ];
      restartTriggers = [ cfg.package ];

      environment = {
        PATH = lib.mkForce null;
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
