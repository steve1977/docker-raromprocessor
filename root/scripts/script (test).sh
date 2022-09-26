#!/usr/bin/env bash
version="1.0.07"
# Debugging settings
#ScrapeMetadata=false
#keepBackupsOfImportedRoms=false

echo "----------------------------------------------------------------"
echo "           |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
echo "           |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
echo "              Presents: RA ROM Processor ($version)"
echo "                 May the cheevos be with you!"
echo "----------------------------------------------------------------"
echo "Donate: https://github.com/sponsors/RandomNinjaAtk"
echo "Project: https://github.com/RandomNinjaAtk/docker-raromprocessor"
echo "Support: https://discord.gg/JumQXDc"
echo "----------------------------------------------------------------"
sleep 5
echo ""
echo "Lift off in..."; sleep 0.5
echo "5"; sleep 1
echo "4"; sleep 1
echo "3"; sleep 1
echo "2"; sleep 1
echo "1"; sleep 1

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: "$1
}

CreateRomFolders () {
	# Create ROM folders
	log "Creating ROM Folders..."
	if [ ! -d "/input/ps2" ]; then
		log "Created: /input/ps2"
		mkdir -p /input/ps2
	fi	

	log "All ROM Folders created, setting permissions and ownership"
	
	# Set Permissions and Ownership
	chmod 777 /input/*
	chown abc:abc /input/*
}

Process_Roms () {
	Region="$1"
	RegionGrep="$1"
	# Process ROMs with RAHasher
	if [ "$Region" = "Other" ]; then
		RegionGrep="."
	fi
	find /input/$folder -type f | grep -i "$RegionGrep" | sort -r | while read LINE;
	do
		Rom="$LINE"
		if [ -d "/tmp/rom_storage" ]; then
			rm -rf "/tmp/rom_storage"
		fi
		TMP_DIR="/tmp/rom_storage"
		mkdir -p "$TMP_DIR"
		rom="$Rom"

		RomFilename="${rom##*/}"
		RomExtension="${filename##*.}"

		log "$ConsoleName :: $RomFilename :: $Region :: Processing..."
		RaHash=""
		if [ "$SkipUnpackForHash" = "false" ]; then
			case "$rom" in
				*.zip|*.ZIP)
					uncompressed_rom="$TMP_DIR/$(unzip -Z1 "$rom" | head -1)"
					unzip -o -d "$TMP_DIR" "$rom" >/dev/null
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$uncompressed_rom") || ret=1
					fi
					;;
				*.7z|*.7Z)
					uncompressed_rom="$TMP_DIR/$(7z l -slt "$rom" | sed -n 's/^Path = //p' | sed '2q;d')"
					7z e -y -bd -o"$TMP_DIR" "$rom" >/dev/null
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$uncompressed_rom") || ret=1
					fi
					;;
				*.chd|*.CHD)
					if [ "$SkipRahasher" = "false" ]; then
						if [ "$folder" = "dreamcast" ]; then
							ExtractedExtension=gdi
						elif [ "$folder" = "segacd" ]; then
							ExtractedExtension=gdi
						else
							ExtractedExtension=cue
						fi
						log "$ConsoleName :: $RomFilename :: CHD Detected"
						log "$ConsoleName :: $RomFilename :: Extracting CHD for Hashing"
						chdman extractcd -i "$rom" -o "$TMP_DIR/game.$ExtractedExtension"
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$TMP_DIR/game.$ExtractedExtension") || ret=1
					fi
					;;
				*)
					if [ "$SkipRahasher" = "false" ]; then
						RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$rom") || ret=1
					fi
					;;
			esac

		    if [[ $ret -ne 0 ]]; then
				rm -f "$uncompressed_rom"
		    fi
		else
			RaHash=$(/usr/local/RALibretro/bin64/RAHasher $ConsoleId "$rom")
		fi

		
		if [ "$SkipRahasher" = "false" ]; then
			log "$ConsoleName :: $RomFilename :: Hash Found :: $RaHash"
			log "$ConsoleName :: $RomFilename :: Matching To RetroAchievements.org DB"
			if cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | jq -r .[] | grep -i "\"$RaHash\"" | read; then
				GameId=$(cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | jq -r .[] | grep -i "\"$RaHash\"" | cut -d ":" -f 2 | sed "s/\ //g" | sed "s/,//g")
				log "$ConsoleName :: $RomFilename :: Match Found :: Game ID :: $GameId"
				Skip="false"
				if [ "$DeDupe" = "true" ]; then
					if [ -f "/output/$ConsoleDirectory/$RomFilename" ]; then
						log "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
						Skip="true"
					elif [ -f "/config/logs/matched_games/$ConsoleDirectory/$GameId" ]; then
						log "$ConsoleName :: $RomFilename :: Duplicate Found, skipping..."
						Skip="true"
					fi
				else
					log "$ConsoleName :: DeDuping process disabled..."
				fi
				if [ "$Skip" = "false" ]; then
					if [ ! -d /output/$ConsoleDirectory ]; then
						log "$ConsoleName :: $RomFilename :: Creating Console Directory \"/output/$ConsoleDirectory\""
						mkdir -p /output/$ConsoleDirectory
						chmod 777 /output/$ConsoleDirectory
						chown abc:abc /output/$ConsoleDirectory
					fi
					if [ ! -f "/output/$ConsoleDirectory/$RomFilename" ]; then
						log "$ConsoleName :: $RomFilename :: Copying ROM to \"/output/$ConsoleDirectory\""
						cp "$rom" "/output/$ConsoleDirectory"/
					else
						log "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
					fi
				fi
				if [ ! -d "/config/logs/matched_games/$ConsoleDirectory" ]; then 
					mkdir -p "/config/logs/matched_games/$ConsoleDirectory"
					chown abc:abc "/config/logs/matched_games/$ConsoleDirectory"
				fi
				touch "/config/logs/matched_games/$ConsoleDirectory/$GameId"
			else
				log "$ConsoleName :: $RomFilename :: ERROR :: Not Found on RetroAchievements.org DB"
			fi
		else
			if [ ! -d /output/$ConsoleDirectory ]; then
				log "$ConsoleName :: $RomFilename :: Creating Console Directory \"/output/$ConsoleDirectory\""
				mkdir -p /output/$ConsoleDirectory
				chmod 777 /output/$ConsoleDirectory
				chown abc:abc /output/$ConsoleDirectory
			fi
			if [ ! -f "/output/$ConsoleDirectory/$RomFilename" ]; then
				log "$ConsoleName :: $RomFilename :: Copying ROM to \"/output/$ConsoleDirectory\""
				cp "$rom" "/output/$ConsoleDirectory"/
			else
				log "$ConsoleName :: $RomFilename :: Previously Imported, skipping..."
			fi
		fi
		# backup processed ROM to /backup
		# create backup directories/path that matches input path
		if [ ! -d "/backup/$(dirname "${Rom:7}")" ]; then
			log "$ConsoleName :: $RomFilename :: Creating Missing Backup Folder :: /backup/$(dirname "${Rom:7}")"
			mkdir -p "/backup/$(dirname "${Rom:7}")"
			chmod 777 "/backup/$(dirname "${Rom:7}")"
			chown abc:abc "/backup/$(dirname "${Rom:7}")"
		fi
		# copy ROM from /input to /backup
		if [ ! -f "/backup/${Rom:7}" ]; then
			log "$ConsoleName :: $RomFilename :: Backing up ROM to: /backup/$(dirname "${Rom:7}")"
			cp "$Rom" "/backup/${Rom:7}"
			chmod 666 "/backup/${Rom:7}"
			chown abc:abc "/backup/${Rom:7}"
		fi
		# remove ROM from input
		log "$ConsoleName :: $RomFilename :: Removing ROM from /input"
		rm "$Rom"
		
	done
}

CreateRomFolders

for folder in $(ls /input); do
	ConsoleId=""
	ConsoleName=""
	ArchiveUrl=""
	SkipUnpackForHash="false"
	
	if echo "$folder" | grep "^ps2" | read; then
		ConsoleId=21
		ConsoleName="PlayStation2"
		ConsoleDirectory="ps2"
		ArchiveUrl="$(curl -s "https://archive.org/download/ps2usaredump1" | grep ".7z" | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' | sed 's/\///g' | sort -u | sed 's|^|https://archive.org/download/ps2usaredump1/|')"
		keepCompressed=false
	fi
	
	if [ "$AquireRomSets" = "true" ]; then
		log "$ConsoleName :: Getting ROMs"
		if [ ! -z "$ArchiveUrl" ]; then
			
			log "$ConsoleName :: Downloading ROMs :: Please wait..."
			
			DlCount="$(echo "$ArchiveUrl" | wc -l)"
			OLDIFS="$IFS"
			IFS=$'\n'
			ArchiveUrls=($(echo "$ArchiveUrl"))
			IFS="$OLDIFS"
			for Url in ${!ArchiveUrls[@]}; do
				currentsubprocessid=$(( $Url + 1 ))
				DlUrl="${ArchiveUrls[$Url]}"
				romFile="$(echo $(basename "$DlUrl") | sed -e "s/%\([0-9A-F][0-9A-F]\)/\\\\\x\1/g" | xargs -0 echo -e)"
				romFile="$(echo $(basename "$romFile"))"
				romFileNoExt="$(echo "${romFile%.*}")"
				DownloadOutput="/input/$folder/temp/$romFile"
				
				if [ -d "/input/$folder/temp/" ]; then
					rm -rf "/input/$folder/temp/"
				fi				
												
				if [ -f "/config/logs/downloaded/$folder/$romFileNoExt" ]; then
					log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: ROM previously downloaded (/config/logs/downloaded/$folder/$romFileNoExt) :: Skipping..."
					continue
				elif [ -f "/input/$folder/$romFile" ]; then
					log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: ROM previously downloaded (/input/$folder/$romFile) :: Skipping..."
					continue
				elif [ -f "/output/$folder/$romFile" ]; then
					log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: ROM previously downloaded (/output/$folder/$romFile) :: Skipping..."
					continue
				elif [ -f "/backup/$folder/$romFile" ]; then
					log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: ROM previously downloaded (/backup/$folder/$romFile) :: Skipping..."
					continue
				fi 
				
				case "$DlUrl" in
					*.zip|*.ZIP)
						Type=zip
						;;
					*.rar|*.RAR)
						Type=rar
						;;
					*.chd|*.CHD)
						Type=chd
						;;
					*.iso|*.ISO)
						Type=iso
						;;
					*.7z|*.7Z)
						Type=7z
						;;
				esac
				
				log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Downloading..."
			
				if [ -d /input/$folder/temp ]; then
					rm -rf /input/$folder/temp
				fi
				mkdir -p /input/$folder/temp
				axel -q -n $ConcurrentDownloadThreads --output="$DownloadOutput" "$DlUrl"
			
				if [ -f "$DownloadOutput" ]; then
					if [ "$Type" = "zip" ]; then
						DownloadVerification="$(unzip -t "$DownloadOutput" &>/dev/null; echo $?)"
					elif [ "$Type" = "rar" ]; then
						DownloadVerification="$(unrar t "$DownloadOutput" &>/dev/null; echo $?)"
					elif [ "$Type" = "chd" ]; then
						DownloadVerification="$(chdman verify -i "$DownloadOutput" &>/dev/null; echo $?)"
					elif [ "$Type" = "iso" ]; then
						DownloadVerification="0"
					elif [ "$Type" = "7z" ]; then
						DownloadVerification="$(7z t "$DownloadOutput" &>/dev/null; echo $?)"
					fi
					if [ "$DownloadVerification" = "0" ]; then
						log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Download Complete!"
						if [ "$Type" = "zip" ]; then
							if [ $keepCompressed = false ]; then
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Unpacking to /input/$folder"
								unzip -o -d "/input/$folder" "$DownloadOutput" >/dev/null
							else
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Moving to /input/$folder"
								mv "$DownloadOutput" "/input/$folder"
							fi
						elif [ "$Type" = "rar" ]; then
							if [ $keepCompressed = false ]; then
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Unpacking to /input/$folder"
								unrar x "$DownloadOutput" "/input/$folder" &>/dev/null
							else
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Moving to /input/$folder"
								mv "$DownloadOutput" "/input/$folder"
							fi
						elif [ "$Type" = "7z" ]; then
							if [ $keepCompressed = false ]; then
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Unpacking to /input/$folder"
								7z x "$DownloadOutput" "/input/$folder" &>/dev/null
							else
								log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Moving to /input/$folder"
								mv "$DownloadOutput" "/input/$folder"
							fi
						elif [ "$Type" = "chd" ]; then
							log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Moving to /input/$folder"
							mv "$DownloadOutput" "/input/$folder"
						elif [ "$Type" = "iso" ]; then
							log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Moving to /input/$folder"
							mv "$DownloadOutput" "/input/$folder"
						fi
						log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Done!"
						if [ ! -d /config/logs/downloaded ]; then
							mkdir -p /config/logs/downloaded
							chown abc:abc /config/logs/downloaded
						fi
						if [ -f /config/logs/downloaded/$folder ]; then
							rm /config/logs/downloaded/$folder
						fi
						if [ ! -d /config/logs/downloaded/$folder ]; then
							mkdir /config/logs/downloaded/$folder
							chmod 777 /config/logs/downloaded/$folder
							chown abc:abc /config/logs/downloaded/$folder
						fi
						if [ -d /input/$folder/temp ]; then
							rm -rf /input/$folder/temp
						fi
						touch "/config/logs/downloaded/$folder/$romFileNoExt"
						chmod 666 "/config/logs/downloaded/$folder/$romFileNoExt"
						chown abc:abc "/config/logs/downloaded/$folder/$romFileNoExt"
					else
						log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Download Failed!"
						if [ -d /input/$folder/temp ]; then
							rm -rf /input/$folder/temp
						fi
						continue
					fi
				else
					log "$ConsoleName :: $currentsubprocessid of $DlCount :: $romFile :: Download Failed!"
					if [ -d /input/$folder/temp ]; then
						rm -rf /input/$folder/temp
					fi
					continue
				fi
			done
		fi
	else
		log "$ConsoleName :: ERROR :: No Archive.org URL found :: Skipping..."
	fi


	if find /input/$folder -type f | read; then
		log "$ConsoleName :: Checking For ROMS in /input/$folder :: ROMs found, processing..."

		# create hash library folder
		if [ ! -d /config/ra_hash_libraries ]; then
			mkdir -p /config/ra_hash_libraries
		fi	
		
		# delete existing console hash library
		if [ -f "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" ]; then
			rm "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json"
		fi
		
		# aquire console hash library
		if [ ! -f "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" ]; then
			log "$ConsoleName :: Getting the console hash library from RetroAchievements.org..."
			curl -s "https://retroachievements.org/dorequest.php?r=hashlibrary&c=$ConsoleId" | jq '.' > "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json"
		fi

		SkipRahasher=false
		if cat "/config/ra_hash_libraries/${ConsoleDirectory}_hashes.json" | grep -i '"MD5List": \[\]' | read; then
			log "$ConsoleName :: Unsupported RA platform detected"
			if [ "$EnableUnsupportedPlatforms" = "false" ]; then
				log "$ConsoleName :: Enable Unsupported RA platforms disalbed :: Skipping... "
				continue
			else
				log "$ConsoleName :: Begin Processing Unsupported RA platform..."
				SkipRahasher=true
			fi
		fi

		Process_Roms USA
		Process_Roms Europe
		Process_Roms World
		Process_Roms Japan
		Process_Roms Other
		
		# remove empty directories
		find /input/$folder -mindepth 1 -type d -empty -exec rm -rf {} \; &>/dev/null

	else
		log "$ConsoleName :: Checking For ROMS in /input/$folder :: No ROMs found, skipping..."
	fi

	
	if [ "$ScrapeMetadata" != "true" ]; then
		log "$ConsoleName :: Metadata Scraping disabled..."
		log "$ConsoleName :: Enable by setting \"ScrapeMetadata=true\""
	else
		if Skyscraper | grep -w "$folder" | read; then
			log "$ConsoleName :: Begin Skyscraper Process..."
			if [ ! -d /output/$folder ]; then
				log "$ConsoleName :: Checking For ROMS in /output/$folder :: No ROMs found, skipping..."
				continue
			fi
			if find /output/$folder -type f | read; then
				log "$ConsoleName :: Checking For ROMS in /ouput/$folder :: ROMs found, processing..."
			else
				log "$ConsoleName :: Checking For ROMS in /output/$folder :: No ROMs found, skipping..."
				continue
			fi
			# Scrape from screenscraper
			if [ "$SkipUnpackForHash" = "false" ]; then
				Skyscraper -f emulationstation -u $ScreenscraperUsername:$ScreenscraperPassword -p $folder -d /cache/$folder -s screenscraper --lang $skyscraperLanguagePreference -i /output/$folder --flags relative,videos,unattend,nobrackets,unpack
			else
				Skyscraper -f emulationstation -u $ScreenscraperUsername:$ScreenscraperPassword -p $folder -d /cache/$folder -s screenscraper --lang $skyscraperLanguagePreference -i /output/$folder --flags relative,videos,unattend,nobrackets
			fi
			# Save scraped data to output folder
			Skyscraper -f emulationstation -p $folder -d /cache/$folder -i /output/$folder --flags relative,videos,unattend,nobrackets
			# Remove skipped roms
			if [ -f /root/.skyscraper/skipped-$folder-cache.txt ]; then
				cat /root/.skyscraper/skipped-$folder-cache.txt | while read LINE;
				do 
					rm "$LINE"
				done
			fi
		else 
			log "$ConsoleName :: Metadata Scraping :: ERROR :: Platform not supported, skipping..."
		fi 
	fi
	
	if [ -d "/backup/$folder" ]; then
		if [ $keepBackupsOfImportedRoms = false ]; then
			log "$ConsoleName :: Removing ROMs from \"/backup/$folder\" that were successfully processed"
			find /output/$folder -maxdepth 1 -type f -not -iname "*.xml" | while read LINE; do
				rom="$LINE"
				romFilename="${rom##*/}"
				if [ -f "/backup/$folder/$romFilename" ]; then
					log "$ConsoleName :: $romFilename :: Removing from /backup/$folder"
					rm "/backup/$folder/$romFilename"
				fi		
			done
			log "$ConsoleName :: Complete"
		else
			log "$ConsoleName :: ERROR :: Removing ROMs from \"/backup/$folder\" is disabled..."
			log "$ConsoleName :: ERROR :: To enable, set \"keepBackupsOfImportedRoms=false\""
		fi
	fi

	# set permissions
	if [ -d "/output/$folder" ]; then
		log "$ConsoleName :: /output/$folder :: Settting File Permissions and Ownership..."
		find /output/$folder -type d -exec chmod 777 {} \;
		find /output/$folder -type d -exec chown abc:abc {} \;
		find /output/$folder -type f -exec chmod 666 {} \;
		find /output/$folder -type f -exec chown abc:abc {} \;
	fi
	if [ -d "/backup/$folder" ]; then
		log "$ConsoleName :: /backup/$folder :: Settting File Permissions and Ownership..."
		find /backup/$folder -type d -exec chmod 777 {} \;
		find /backup/$folder -type d -exec chown abc:abc {} \;
		find /backup/$folder -type f -exec chmod 666 {} \;
		find /backup/$folder -type f -exec chown abc:abc {} \;
	fi
done

exit $?
