{ config, lib, pkgs, ... }:
let 
  timedRandomWallpaperSetter =  pkgs.writeShellScriptBin
    "timed-random-wallpaper-setter"
    ''
      # XDG_CONFIG_HOME is not recognized in the environment here.
      if [ -f /home/BLAHUSER/.config/WallpaperOpts.nix ]
      then
		echo "Building wallpaper setter ..."
		WPS=$(${pkgs.nix}/bin/nix-build /home/BLAHUSER/.config//WallpaperManager.nix)
		echo "Wallpaper setter is $WPS, display is $DISPLAY"
		while true
		do
			$WPS
			sleep 60
		done
      fi
    ''
  ;
in
{
    systemd.user.services.timed-random-wallpaper-setter = {
      wantedBy = [ "default.target" ];
      serviceConfig = {
		Description = "Timed random wallpaper setter service";
        Type = "simple";
        ExecStart = "${timedRandomWallpaperSetter}/bin/timed-random-wallpaper-setter";

        Restart="on-failure";
        RestartSec=3;
        RestartPreventExitStatus=3;
      };
    };
}
