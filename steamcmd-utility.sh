#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/steamcmd-wrapper
# Scipt name:	steamcmd-utility.sh
# Script Ver:	0.9.8
# Description:	Wrapper around steamcmd for common functions
#		Ex. Downloads a game from Steam, based on it's AppID, useful for
#               for on-the-go situations, or free-to-play when you can't 
#               load the client.
#
# Usage:	./steamcmd-utility.sh [options]
#		./steamcmd-utility.sh [-h|--help]

# Set initial vars
DOWNLOAD_FILES="false"
STEAMCMD_CMD_UPDATE_LIST="false"
STEAMCMD_REQUIRED="false"
GAME_SERVER="false"
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)

detect_steamcmd()
{

	# Set root dirs
	STEAMCMD_ROOT="${HOME}/steamcmd"
	SERVER_ROOT="${STEAMCMD_ROOT}/servers"

	if [[ ! -f "${STEAMCMD_ROOT}/steamcmd.sh" ]]; then

		install_steamcmd

	fi
}

install_steamcmd()
{
	
	# Check Distro
	# Use lsb_release and /etc/*-release as a backup
	DISTRO_CHECK=$(lsb_release -si)

	if [[ "${DISTRO_CHECK}" == "" ]]; then

		# try /etc/*-release
		DISTRO_CHECK=$(cat /etc/*-release | awk -F"=" '/DISTRIB_ID/{print $2}')

	fi

	# Check for multilib
	if [[ "${DISTRO_CHECK}" == "Debian" || "${DISTRO_CHECK}" == "SteamOS" ]]; then

		MULTIARCH=$(dpkg --print-foreign-architectures | grep i386)
		if [[ "${MULTIARCH}" == "" ]]; then

			echo -e "\nMultiarch not found!\n"
			sudo dpkg --add-architecture i386
			echo -e "Updating for multiarch\n" 
			sleep 2s
			sudo apt-get update

		fi

	elif [[ "${DISTRO_CHECK}" == "Arch" ]]; then

		MULTIARCH=$(grep '\[multilib\]' /etc/pacman.conf)
		if [[ "${MULTIARCH}" == "" ]]; then

			echo -e "\nMultiarch not found!\n"
			echo "[multilib]" | sudo tee -a "/etc/pacman.conf"
			echo "Include = /etc/pacman.d/mirrorlist"  | "sudo tee -a /etc/pacman.conf"
			echo -e "Updating for multiarch\n" 
			sleep 2s
			pacman -Syy

		fi

	else

		# Catch non supported distros
		echo -e "\nDistribution not currently supported!\n"
		exit 1

	fi

	# Install needed packages
	if [[ "${DISTRO_CHECK}" == "Debian" || "${DISTRO_CHECK}" == "SteamOS" ]]; then

		sudo apt-get install -y --force-yes lib32gcc1 libc6-i386 wget tar

	elif [[ "${DISTRO_CHECK}" == "Arch" ]]; then

		pacman -S wget tar grep lib32-gcc-libs
		
	elif [[ "${DISTRO_CHECK}" == "Fedora" ]]; then

		sudo yum install wget tar glibc.i686 libstdc++.i686

	fi
	
	# install steamcmd
	echo -e "\n==> Installing steamcmd\n"
	mkdir -p "${STEAMCMD_ROOT}"
	wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -q -nc --show-progress
	sudo tar -xf "steamcmd_linux.tar.gz" -C "${STEAMCMD_ROOT}"
	rm -f "steamcmd_linux.tar.gz"

	
}

reset_steamcmd()
{

	# Cleans out metadata cruft
	echo -e "\n==> Reinstalling steamcmd" && sleep 2s
	# Backup
	cp -r "${HOME}/.steam" "${HOME}/.steam.bak"
	# Remove
	rm -rf "${STEAMCMD_ROOT}/Steam/" "$HOME/.steam" "${STEAMCMD_ROOT}/steamcmd_tmp"
	# Reinstall
	install_steamcmd

}

show_steamcmd_commands()
{
	# Show existing list if already generated
	if [[ -f "${STEAMCMD_ROOT}/steamcmdcommands.txt" ]]; then
		less "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	else
		echo -e "\nERROR: SteamCMD command list file not found. Generating...\n"
		sleep 2s
		generate_steamcmd_cmd_list
		less "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	fi
	
	# Update root listing if requested
	if [[ "${STEAMCMD_UPDATE_CMD_LIST}" == "true" ]]; then

		cp "${STEAMCMD_ROOT}/steamcmdcommands.txt" "${PWD}"
		echo -e "\n==>Updating GitHub command listing\n"
		git add steamcmdcommands.txt
		git commit -m "Update steamcmd command list"
		git push origin master

	fi
}

generate_steamcmd_cmd_list()
{
	
	# Imported code from https://github.com/dgibbs64/SteamCMD-Commands-List
	# Credit:github.com/dgibbs64/
	# Updated: 20160830
	
	# Detect steacmd (required)
	detect_steamcmd
	
	cat<<-EOF
	
	====================================
	Getting SteamCMD Commands/Convars
	====================================

	EOF

	mkdir -p "${STEAMCMD_ROOT}/tmp"
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
	
	# Time stamp list
	echo "List generated on:" > "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	echo "${DATE_LONG}" >> "${STEAMCMD_ROOT}/steamcmdcommands.txt"
	echo "ConVars:" >> "${STEAMCMD_ROOT}/steamcmdcommands.txt"
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

download_game_files()
{
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

	# run steamcmd
	# +app_license_request works around downloading free to play games

	if ${STEAMCMD_ROOT}/steamcmd.sh +@sSteamCmdForcePlatformType \
	${PLATFORM} +login ${STEAM_LOGIN_NAME} +force_install_dir ${TEMP_DIRECTORY} \
	+app_license_request ${GAME_APP_ID} +app_update ${GAME_APP_ID} validate +quit; then

		# Move files to actual directory
		sudo cp -r ${TEMP_DIRECTORY}/* "${DIRECTORY}"
		echo "\nGame successfully downloaded to ${DIRECTORY}"

	else
	
		"Game download failed! Trying resetting steamcmd"

	fi

	# cleanup
	rm -rf "${TEMP_DIRECTORY}"

}

install_game_server()
{

	# Main input prompt
	cat<<-EOF
	Please enter the game that you want to make the server of.
	WARNING. you might have to install #7 multiple times to get the server to work

	1) Team Fortress 2"
	2) Counter-Strike: Source"
	3) CS:GO"
	4) Garry's Mod"
	5) Left 4 Dead 2"
	6) DOD:S"
	7) Half-Life (also cs 1.6, dod, etc...)"
	8) Other server (need steam id)"
	
	EOF

	# Simple loop to get input (if they enter it incorrectly)
	while true
	do 
		read erp "Choice: " GAME_SERVER

		# Case statement to check the input var

		case ${GAME_SERVER} in

			1) echo "Now installing Team Fortress 2 server."
			SERVER_GAME="Team Fortress 2"
			SERVER_ID=232250
			break
			;;

			2) echo "Now installing Counter Strike Source server."
			SERVER_GAME="Counter-Strike Source"
			SERVER_ID=232330
			break
			;;

			3) echo "Now installing CS:GO server."
			SERVER_GAME="CS:GO"
			SERVER_ID=740
			break
			;;

			4) echo "Now installing Garry's Mod server."
			SERVER_GAME="Garry's Mod"
			SERVER_ID=4020
			break
			;;

			5) echo "Now installing Left 4 Dead 2 server."
			SERVER_GAME="Left 4 Dead 2"
			SERVER_ID=222860
			break
			;;

			6) echo "Now installing DOD:S server."
			SERVER_GAME="DOD:S"
			SERVER_ID=232290
			break
			;;

			7) echo "Now installing Half-Life server."
			SERVER_GAME="Half-Life"
			SERVER_ID=90
			break
			;;

			8) echo "Now installing other server."
			read -erp "Please enter a server ID: " SERVER_ID
			break
			;;

			*) echo "Please enter a valid option."
			continue
			;;
		esac
		
	done

	if ${STEAMCMD_ROOT}/steamcmd.sh +login anonymous +force_install_dir ${SERVER_ROOT} \
	+app_update ${SERVER_ID} validate +quit; then

		echo -e "\nRequested server has been installed to ${SERVER_ROOT}\n"

	else

		echo -e "\nServer installation failed!"

	fi
}

########################################
# source options
########################################

while :; do
	case $1 in

		--reset-steamcmd|-r)
			# Very useful if you restore SteamoS.
			reset_steamcmd
			;;

		--get|-g)
			STEAMCMD_REQUIRED="true"
			DOWNLOAD_FILES="true"
			;;

		--game-server|s)
			STEAMCMD_REQUIRED="true"
			GAME_SERVER="true"
			;;

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

		--steamcmd-commands)
			# Internal use only
			if [[ "$2" == "--update-list" ]]; then
				STEAMCMD_UPDATE_CMD_LIST="true"
			fi

			show_steamcmd_commands
			break
			;;

		--help|-h)
			cat<<-EOF

			Usage:	 ./steamcmd-utility.sh [options]
			Options:
				-h|--help		Help text
				--get|-g		downloads a game
				--game-server|s		Installs a game server
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

main()
{

	#################################################
	# steamcmd wrapper fucnctions
	#################################################

	# Execute steamcmd for outlined functions
	
	if [[ ${DOWNLOAD_FILES} == "true " ]]; then

		detect_steamcmd
		download_game_files

	elif [[ ${GAME_SERVER} == "true" ]]; then

		detect_steamcmd
		install_game_server

	fi

}
