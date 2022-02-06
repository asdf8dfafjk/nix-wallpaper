let 
	pkgs=(import <nixpkgs>{});


	# wallpaperOpts should have the following format:

	#{
	#	settings = 
	#	{
	#		setterProgram = {
	#			executable = "${pkgs.feh}/bin/feh";
	#			arguments  = [ "--bg-max" "--no-xinerama" ];
	#		};

	#       # This is the output hash for fixed output derivation
	#		hash = "0000000000000000000000000000000000000000000000000000000000000000";
	#	};
	#	wallpapers = {
	#		urls = [ 
	#			"url 1"
	#			"url 2"
	#			# Mentioning hash prevents redownload of 
	#			# all wallpapers everytime a 
	#			# single is added or deleted
	#			{ url = "url3"; hash = "hash3";}
	#		];
	#		localFiles = [ ... ] ;
	#		localDirs  = [ ... ] ;
	#	};
	#}


	addNullHashtoUrls = 
		urlWithOptionalHash:
			if
				( builtins.typeOf urlWithOptionalHash == "string" )
			then
				{ 
					url =  urlWithOptionalHash; 
					hash = "";
				}
			else
				urlWithOptionalHash
	;

	imageFileFilter = imageFileName:
		(
			pkgs.lib.hasSuffix "png" imageFileName
			|| pkgs.lib.hasSuffix "jpg" imageFileName
		)
	;


	wallpaperOpts = (import ./WallpaperOpts.nix { inherit pkgs; } );

	backgroundSetterProgram   = wallpaperOpts.settings.setterProgram.executable;
	backgroundSetterArguments = wallpaperOpts.settings.setterProgram.arguments;
	backgroundSetterArgumentsSingleString = pkgs.lib.concatStringsSep " " backgroundSetterArguments;


	allWallpapers = wallpaperOpts.wallpapers;
	allUrlWallpapers = 
		builtins.map
			addNullHashtoUrls
			allWallpapers.urls
	;


	singleDirectoryWallpapers = 
		dirName:
			(
				builtins.filter 
					imageFileFilter 
					( 
						pkgs.lib.mapAttrsToList 
							( name: value: name )
							( builtins.readDir dirName )
					)
			)
		;
	
	allDirectoryWallpapers = 
		pkgs.lib.flatten
			(
				map
					singleDirectoryWallpapers
					allWallpapers.localDirs 
			)
	;
			

	nix_code_prologue = ''
		echo "pkgs: " > $1
		echo "[" >> $1
	'';

	nix_code_generator_script  = 
		pkgs.lib.concatStringsSep
			"\n"
			(
					map
					( 
						{
							url,
							hash
						}:
							''
								if [ -z "${hash}" ]
								then
									${pkgs.wget}/bin/wget --no-check-certificate ${url} -O blah 2>/dev/null
									hash=$(${pkgs.nix}/bin/nix-hash --type sha256 --flat --base32 blah)
									echo ${url}
									echo $hash
								else
									#echo "hash ${hash} already known for ${url}"
									hash="${hash}"
								fi

								if [ ! -z $hash ]
								then
									cat << XJK  >> $1
									( 
										pkgs.fetchurl{
											url = "${url}";
											sha256="$hash";
										}
									)
XJK
								else
									echo "========hash FAILED for ${url}============="
								fi
							''
					)
					allUrlWallpapers
			)
	;

	nix_code_epilogue = '' 
		echo "]" >> $1 
		echo "" >> $1
	'';
	bashCreatorOfWallpaperFetcherNixScript = (
		pkgs.writeShellScript
		
			"BashCreatorOfWallpaperFetcherNixScript"
			(nix_code_prologue + nix_code_generator_script + nix_code_epilogue)
	);

	wallpaperFetcherNixScript = (
		pkgs.stdenv.mkDerivation
			(
				{
					name = "wallpaper-fetcher.nix";
					buildCommand = 
						''
							${bashCreatorOfWallpaperFetcherNixScript} $out
						''
					;
				}
				// 
					(
						if (
							builtins.all ( url: (builtins.typeOf url) != "string" ) wallpaperOpts.wallpapers.urls
						)
						then
							{}
						else
							{
								outputHashAlgo = "sha256";
								outputHashMode = "recursive";
								outputHash = wallpaperOpts.settings.hash; 
							}
					)
			)
	);
	downloadedOnlineWallpapers = (import wallpaperFetcherNixScript pkgs);
	allWallpapersLocalized     = downloadedOnlineWallpapers ++ allWallpapers.localFiles ++ allDirectoryWallpapers;

	numWallpapers = 
		builtins.toString
			(
				builtins.length 
					allWallpapersLocalized 
			)
	;

	wallpaperBashArray = 
		"wallpaperArray=(\n" + 
		( 
			pkgs.lib.concatStringsSep 
				"\n" 
				allWallpapersLocalized 
		) +
		"\n)"
	;
in
		pkgs.writeShellScript
			"RandomWallpaperSetter"
			( 
				wallpaperBashArray + "\n" + 
				"chosenWallpaper=$" + "{wallpaperArray[$(( $RANDOM % ${numWallpapers} ))]}\n" + 
				"echo $chosenWallpaper\n" +
				"${backgroundSetterProgram} ${backgroundSetterArgumentsSingleString} $chosenWallpaper\n"
			)
