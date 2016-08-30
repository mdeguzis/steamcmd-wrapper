#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/steamcmd-wrapper
# Scipt name:	steamcmd-utility.sh
# Script Ver:	0.9.7
# Description:	Wrapper around steamcmd for common functions
#		Ex. Downloads a game from Steam, based on it's AppID, useful for
#               for on-the-go situations, or free-to-play when you can't 
#               load the client.
#
# Usage:	./steamcmd-utility.sh [options]
#		./steamcmd-utility.sh [-h|--help]
# -------------------------------------------------------------------------------

# Set initial vars
DOWNLOAD_FILES="false"

# source options
while :; do
	case $1 in

		--get|-g
			DOWNLOAD_FILES="true"

		--appid|-a)
			if [[ -n "$2" ]]; then
				GAME_APP_ID=$2
				# echo "INSTALL PATH: $DIRECTORY"
				shift
			else
				echo -e "ERROR: --appid|-a requires an argument.\n" >&2
				exit 1
			fi
			;;

		--directory|-d)       # Takes an option argument, ensuring it has been specified.
			if [[ -n "$2" ]]; then
				CUSTOM_DATA_PATH="true"
				DIRECTORY=$2
				# echo "INSTALL PATH: $DIRECTORY"
				shift
			else
				echo -e "ERROR: --directory|-d requires an argument.\n" >&2
				exit 1
			fi
			;;

		--platform|-p)       # Takes an option argument, ensuring it has been specified.
			if [[ -n "$2" ]]; then
				PLATFORM=$2
				# echo "PLATFORM: $PLATFORM"
				shift
			else
				echo -e "ERROR: --platform|-p requires an argument.\n" >&2
				exit 1
			fi
			;;
		
		--reset-steamcmd|-r)
			# Very useful if you restore SteamoS.
			# Cleans out metadata cruft
			echo -e "\n==> Reinstalling steamcmd" && sleep 2s
			rm -rf "$HOME/Steam/" "$HOME/steamcmd" "$HOME/.steam" "$HOME/steamcmd_tmp"
			;;
		
		--steamcmd-commands)
			show_steamcmd_commands
			break
			;;

		--help|-h) 
			cat<<-EOF
			
			Usage:	 ./steamcmd-utility.sh [options]
			Options:
				-h|--help		Help text
				--get|-g		[download a game]
				--appid|-a 		[AppID] 
				--platform|-p		[Platform] 
				--directory|-d 		[TARGET_DIR]
				--steamcmd-commands	steamcmd command list
			
			EOF
			break
			;;

		--)
		# End of all options.
		shift
		break
		;;

		-?*)
		printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
		;;

		*)  
		# Default case: If no more options then break out of the loop.
		break

	esac

	# shift args
	shift
done

install_steamcmd()
{
	
	# install steamcmd
	echo -e "\n==> Installing steamcmd\n"
	mkdir -p "${STEAMCMD_ROOT}"
	sudo apt-get install -y lib32gcc1 
	wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -q -nc --show-progress
	sudo tar -xf "steamcmd_linux.tar.gz" -C "${STEAMCMD_ROOT}"
	rm -f "steamcmd_linux.tar.gz"

	
}

show_steamcmd_commands()
{
	# Show existing list if already generated
	if [[ -f "${STEAMCMD_ROOT}/steamcmdcommands.txt" ]]; then
		less "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	else
		generate_steamcmd_cmd_list
		less "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	fi
}

generate_steamcmd_cmd_list()
{
	
	# Imported code from https://github.com/dgibbs64/SteamCMD-Commands-List
	# Credit:github.com/dgibbs64/
	# Updated: 20160830
	
	cat<<-EOF
	
	====================================
	Getting SteamCMD Commands/Convars
	====================================

	EOF

	mkdir "${STEAMCMD_ROOT}/tmp"
	cd "${STEAMCMD_ROOT}"
	
	for LETTER in {a..z}
	do
		echo "./steamcmd.sh +login anonymous +find ${LETTER} +quit"
		./steamcmd.sh +login anonymous +find ${LETTER} +quit > "${STEAMCMD_ROOT}/tmp/${LETTER}"
		echo "Creating list for LETTER ${LETTER}."
		sleep 0.5
		echo ""

		# Commands List
		cat "${STEAMCMD_ROOT}/tmp/${LETTER}" > "${STEAMCMD_ROOT}/tmp/${LETTER}commands"
		sed -i '1,/Commands:/d' "${STEAMCMD_ROOT}/tmp/${LETTER}commands"
		cat "${STEAMCMD_ROOT}/tmp/${LETTER}commands" >> "${STEAMCMD_ROOT}/tmp/commandslistraw"
		
		#Convars List
		cat "${STEAMCMD_ROOT}/tmp/${LETTER}" > "${STEAMCMD_ROOT}/tmp/${LETTER}convars"
		sed -i '1,/ConVars:/d' "${STEAMCMD_ROOT}/tmp/${LETTER}convars"
		#cat "${STEAMCMD_ROOT}/tmp/${LETTER}convars > "${STEAMCMD_ROOT}/tmp/${LETTER}convarscommands
		sed -i '/Commands:/Q' "${STEAMCMD_ROOT}/tmp/${LETTER}convars"
		cat "${STEAMCMD_ROOT}/tmp/${LETTER}convars" >> "${STEAMCMD_ROOT}/tmp/convarslistraw"
	done

	echo "Sorting lists."
	cd "${STEAMCMD_ROOT}/tmp"
	sort -n commandslistraw > commandslistsort
	uniq commandslistsort > commandslisttidy
	cat commandslisttidy|tr -d '\000-\011\013\014\016-\037'| sed 's/\[0m//g'|sed 's/\[1m//g'> commandslist
	
	sort -n convarslistraw > convarslistsort
	uniq convarslistsort > convarslisttidy
	cat convarslisttidy|tr -d '\000-\011\013\014\016-\037'| sed 's/\[0m//g'|sed 's/\[1m//g'> convarslist
	
	echo "Generating output."
	echo "ConVars:" > "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	cat  "convarslist" >> "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	echo "Commands:" >> "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	cat  "commandslist" >> "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	echo "ConVars:"
	cat  "convarslist"
	echo "Commands:"
	cat  "commandslist"
	echo "Tidy up."
	rm -rf "${STEAMCMD_ROOT}/tmp"
	rm -rf "${STEAMCMD_ROOT}/steamcmd"
	
}

check_rereqs()
{

	DISTRO_CHECK=$(lsb_release -i | cut -c 17-25)

	if [[ "${DISTRO_CHECK}" == "Debian" || "${DISTRO_CHECK}" == "SteamOS" ]]; then

		sudo apt-get install -y --force-yes lib32gcc1 libc6-i386

	else

		echo -e "\nDistribution not currently supported!\n"
		exit 1

	fi

}

main()
{
	
	#################################################
	# Setup
	#################################################

	# Check for necessary items
	check_rereqs
	
	# Check for steamcmd
	STEAMCMD_ROOT="${HOME}/steamcmd"

	if [[ ! -f "${STEAMCMD_ROOT}/steamcmd.sh" ]]; then

		install_steamcmd

	fi

	#################################################
	# steamcmd wrapper fucntions
	#################################################

	# Execute steamcmd for outlined functions

	if [[ ${DOWNLOAD_FILES} == "true "]]; then

		# get game files via steam (you must own the game!)
		echo -e "\n==> Acquiring files via Steam. You must own the game!"
		read -erp "    Steam username: " STEAM_LOGIN_NAME
		echo ""

		# Download
		# steam cmd likes to put the files in the same directory as the script
	
		if [[ "${CUSTOM_DATA_PATH}" != "true" ]]; then
	
	                # let this be a default
	                # If this is not set, the path will be $HOME/Steam/steamapps/common/
	                STEAM_DATA_FILES="default directory"
	                DIRECTORY="/home/steam/.local/share/Steam/steamapps/common/"
	
	        fi

		echo -e "==> Downloading game files to: ${DIRECTORY}"
		sleep 2s
	
		TEMP_DIRECTORY="${STEAMCMD_ROOT}/steamcmd_tmp"
		mkdir -p "${TEMP_DIRECTORY}"
	
		# run as steam user
		${STEAMCMD_ROOT}/steamcmd.sh +@sSteamCmdForcePlatformType \
		${PLATFORM} +login ${STEAM_LOGIN_NAME} +force_install_dir ${TEMP_DIRECTORY} \
		+app_update ${GAME_APP_ID} validate +quit || exit 1

		# Move files to actual directory
		sudo cp -r ${TEMP_DIRECTORY}/* "${DIRECTORY}"
	
		# cleanup
		rm -rf "${TEMP_DIRECTORY}"
		
	fi
	
}

# Start wrapper
main

