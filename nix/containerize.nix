{ lib, dockerTools }:

let
  containerize =
    moyai-discord-bot:

    let
      inherit (moyai-discord-bot.passthru) crossPkgs;
      architecture = crossPkgs.go.GOARCH;
    in

    dockerTools.buildLayeredImage {
      name = "moyai-discord-bot";
      tag = "latest-${architecture}";
      contents = [ dockerTools.caCertificates ];
      config.Cmd = [ (lib.getExe moyai-discord-bot) ];
      inherit architecture;
    };
in

containerize
