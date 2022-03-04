#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/steamcmd-wrapper
# Scipt name:	steamcmd-wrapper.sh
# Script Ver:	0.3.9
# Description:	Wrapper around steamcmd for common functions
#		Ex. Downloads a game from Steam, based on it's AppID, useful for
#               for on-the-go situations, or free-to-play when you can't 
#               load the client.
#
# Usage:	./steamcmd-wrapper.sh [options]
#		./steamcmd-wrapper.sh [-h|--help]

set -e

# Set initial vars
STEAMCMD_ROOT="/opt/steamcmd"
TEMP_DIRECTORY="${STEAMCMD_ROOT}/steamcmd_tmp"
SERVER_ROOT="${STEAMCMD_ROOT}/servers"
DOWNLOAD_FILES="false"
STEAMCMD_CMD_UPDATE_LIST="false"
GAME_SERVER="false"
DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)
OS=$(cat /etc/os-release | awk -F'=' '/^ID=/ {print $2}')

detect_steamcmd()
{
	# A stub for now
	if [[ ! -f "${STEAMCMD_ROOT}/steamcmd.sh" ]]; then

		install_steamcmd

	fi

}

get_appid_info()
{

	# TODO - parse JSON
	${STEAMCMD_ROOT}/steamcmd.sh +app_info_print ${GAME_APP_ID} +quit | less

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

	elif [[ "${DISTRO_CHECK}" == "Arch" || "${DISTRO_CHECK}" == "chimeraos" ]]; then

		MULTIARCH=$(grep '\[multilib\]' /etc/pacman.conf)
		if [[ "${MULTIARCH}" == "" ]]; then

			echo -e "\nMultiarch not found!\n"
			echo "[multilib]" | sudo tee -a "/etc/pacman.conf"
			echo "Include = /etc/pacman.d/mirrorlist"  | "sudo tee -a /etc/pacman.conf"
			echo -e "Updating for multiarch\n" 
			sleep 2s
			sudo pacman -Syy

		fi

	else

		# Catch non supported distros
		echo -e "\nDistribution not currently supported!\n"
		exit 1

	fi

	# Install needed packages
	if [[ "${DISTRO_CHECK}" == "Debian" || "${DISTRO_CHECK}" == "SteamOS" ]]; then

		sudo apt-get install -y --force-yes lib32gcc1 libc6-i386 wget tar

	elif [[ "${DISTRO_CHECK}" == "Arch" || "${DISTRO_CHECK}" == "chimeraos" ]]; then

		if [[ "${DISTRO_CHECK}" == "chimeraos" ]]; then
			echo "Need to unlock system files for ChimeraOS first with frzr-unlock..."
			sudo frzr-unlock
		fi
		sudo pacman -S wget tar grep lib32-gcc-libs
		
	elif [[ "${DISTRO_CHECK}" == "Fedora" ]]; then

		sudo yum install wget tar glibc.i686 libstdc++.i686

	fi
	
	# install steamcmd
	echo -e "\n==> Installing/Updating steamcmd\n"
	sudo mkdir -p "${STEAMCMD_ROOT}"
	# Update perms on folder to user
	sudo chown ${USER}:${USER} "${STEAMCMD_ROOT}"
	wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -q -nc --show-progress
	tar -xf "steamcmd_linux.tar.gz" -C "${STEAMCMD_ROOT}"
	rm -f "steamcmd_linux.tar.gz"

	# Add steam to group for SteamOS (runs as steam)
	if [[ "${OS}" == "steamos" ]]; then
		echo "Updating group owner to steam (SteamOS)"
		sudo chgrp -R steam "${STEAMCMD_ROOT}"
		sudo chmod -R g+rwx "${STEAMCMD_ROOT}"
	fi
	
}

reset_steamcmd()
{

	# Cleans out metadata cruft
	echo -e "\n==> Reinstalling steamcmd\n" && sleep 2s
	# Backup (suppress output if it doesn't exist)
	cp -r "${HOME}/.steam" "${HOME}/.steam.bak" &> /dev/null
	# Remove
	rm -rf "${STEAMCMD_ROOT}/Steam/" "$HOME/.steam" "${STEAMCMD_ROOT}/steamcmd_tmp"
	# Reinstall
	install_steamcmd

}

show_steamcmd_commands()
{
	# Show existing list if already generated
	if [[ -f "${STEAMCMD_ROOT}/steamcmdcommands.txt" ]]; then
		echo "Existing list found at ${STEAMCMD_ROOT}/steamcmdcommands.txt"
	else
		echo -e "\nERROR: SteamCMD command list file not found. Generating...\n"
		sleep 2s
		generate_steamcmd_cmd_list
		echo "List generated to: ${STEAMCMD_ROOT}/steamcmdcommands.txt"
	fi
	
	# Update root listing if requested
	if [[ "${STEAMCMD_UPDATE_CMD_LIST}" == "true" ]]; then

		generate_steamcmd_cmd_list
		echo "List generated to: ${STEAMCMD_ROOT}/steamcmdcommands.txt"

		if [[ "${GIT_PUSH}" == "true" ]]; then
			cp "${STEAMCMD_ROOT}/steamcmdcommands.txt" "${PWD}"
			echo -e "\n==>Updating GitHub command listing\n"
			git add steamcmdcommands.txt
			git commit -m "Update steamcmd command list"
			git push origin master
		fi

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

	# get proper install dir
	INSTALL_DIR=$(${STEAMCMD_ROOT}/steamcmd.sh +app_info_print ${GAME_APP_ID} +quit | awk -F'"' '/installdir/ {print $4}')
	if [[ -z ${INSTALL_DIR} ]]; then
		echo "Could not detect game installation directory!"
		exit 1
	fi

	# Download
	# steam cmd likes to put the files in the same directory as the script
	# Set default based on SteamOS or standard-Linux
	if [[ "${CUSTOM_DATA_PATH}" != "true" ]]; then

		if [[ "${OS}" == "steamos" ]]; then
			STEAM_ROOT="/home/steam"
			MANIFEST_DIRECTORY="${STEAM_ROOT}/.local/share/Steam/steamapps"
			FINAL_DIRECTORY="${STEAM_ROOT}/.local/share/Steam/steamapps/common/${INSTALL_DIR}"
			echo "Provisioning directory"
			sudo mkdir -p "${FINAL_DIRECTORY}"

		else
			STEAM_ROOT="${HOME}"
			MANIFEST_DIRECTORY="${STEAM_ROOT}/.local/share/Steam/steamapps"
			FINAL_DIRECTORY="${STEAM_ROOT}/.local/share/Steam/steamapps/common/${INSTALL_DIR}"
			mkdir -p "${FINAL_DIRECTORY}"

		fi

	fi

	rm -rf "${TEMP_DIRECTORY}"
	mkdir -p "${TEMP_DIRECTORY}"

	# run steamcmd
	# +app_license_request works around downloading free to play games
	cat <<- _EOF_
	
	Steam login: ${STEAM_LOGIN_NAME}
	TEMP_DIRECTORY: ${TEMP_DIRECTORY}
	FINAL_DIRECTORY: ${FINAL_DIRECTORY}
	MANIFEST_DIRECTORY: ${MANIFEST_DIRECTORY}
	_EOF_

	read -erp "Press ENTER to continue..."
	echo -e "\n==> Downloading game files to: ${TEMP_DIRECTORY}\n"

	if ${STEAMCMD_ROOT}/steamcmd.sh +@sSteamCmdForcePlatformType \
	${PLATFORM} +login ${STEAM_LOGIN_NAME} +force_install_dir ${TEMP_DIRECTORY} \
	+app_license_request ${GAME_APP_ID} +app_update ${GAME_APP_ID} validate +quit; then

		echo "Temp directory contents:"
		ls -la "${TEMP_DIRECTORY}"
		# Move files to actual directory
		echo "Moving finished files..."
		if [[ "${OS}" == "steamos" ]]; then
			sudo rsync -ra ${TEMP_DIRECTORY}/* "${FINAL_DIRECTORY}" --exclude "steamapps"
			echo "Copying over app manifest..."
			sudo find "${TEMP_DIRECTORY}/steamapps" -name "*.acf" -exec cp -v {} ${MANIFEST_DIRECTORY} \;"
		else
			rsync -ra ${TEMP_DIRECTORY}/* "${FINAL_DIRECTORY}" --exclude "steamapps"
			echo "Copying over app manifest..."
			find "${TEMP_DIRECTORY}/steamapps" -name "*.acf" -exec cp -v {} ${MANIFEST_DIRECTORY} {} \;"
		fi
		echo -e "\nGame successfully downloaded to ${FINAL_DIRECTORY}"
		echo "If your game did not appear, check you are in online mode and/or restart Steam"

	else
		"Game download failed! Trying resetting steamcmd"
		exit 1

	fi

	# chown files
	if [[ "${OS}" == "steamos" ]]; then
		echo "Correcting permissions for SteamOS"
		sudo chown -R steam:steam "${FINAL_DIRECTORY}"
	fi

	# Validate game files to slap Steam out of a daze and realize it has a new game
	# The app manifest should be enough, but the idea here is to avoid having to 
	# click install or restart steam
	if ${STEAMCMD_ROOT}/steamcmd.sh +@sSteamCmdForcePlatformType \
	${PLATFORM} +login ${STEAM_LOGIN_NAME} +app_update ${GAME_APP_ID} \
	-validate +quit; then
		echo "Game validated"
	else
		echo "Game cold not be validated!"
		exit 1
	fi

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

		--directory|-d)       # Takes an option argument, ensuring it has been specified.
			if [[ -n "$2" ]]; then
				CUSTOM_DATA_PATH="true"
				FINAL_DIRECTORY=$2
				# echo "INSTALL PATH: $FINAL_DIRECTORY"
				shift
			else
				echo -e "ERROR: --directory|-d requires an argument.\n" >&2
				exit 1
			fi
			;;

		--get|-g)
			if [[ -n "$2" ]]; then
				GAME_APP_ID=$2
				# echo "INSTALL PATH: $FINAL_DIRECTORY"
				shift
			else
				echo -e "ERROR: --get|-g requires the AppID an argument.\n" >&2
				exit 1
			fi

			TYPE="download"
			ACTION="download-files"
			;;

		--game-server|-s)
			TYPE="game-server"
			ACTION="setup"
			;;

		--info|-i)
			if [[ -n "$2" ]]; then
				GAME_APP_ID=$2
				# echo "INSTALL PATH: $FINAL_DIRECTORY"
				shift
			else
				echo -e "ERROR: --info|-i requires the AppID an argument.\n" >&2
				exit 1
			fi
			TYPE="info"
			ACTION="fetch"
			;;

		--platform|-p)
			# Takes an option argument, ensuring it has been specified.
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
			reset_steamcmd
			;;

		--update|-u)
			if [[ -n "$2" ]]; then
				GAME_APP_ID=$2
				# echo "INSTALL PATH: $FINAL_DIRECTORY"
				shift
			else
				echo -e "ERROR: --update|-u requires the AppID an argument.\n" >&2
				exit 1
			fi
			;;

		--steamcmd-cmds)
			# Internal use only
			if [[ "$2" == "--update-list" ]]; then
				STEAMCMD_UPDATE_CMD_LIST="true"
			fi
			
			if [[ "$2" == "--git-push" || "$3" == "--git-push" ]]; then
				GIT_PUSH="true"
			fi

			show_steamcmd_commands
			break
			;;

		--help|-h)
			cat<<-EOF

			Usage:	 ./steamcmd-wrapper.sh [options]
			Options:
				-h|--help		This help text
				--info|-i		Fetch appid info
				--status|-s		Fetch appid status info
				--get|-g		downloads a game
				--game-server|s		Installs a game server
				--platform|-p		[Platform] 
				--directory|-d 		[TARGET_DIR]
				--steamcmd-cmds		steamcmd command list
				--reset-steamcmd|-r	Resinstall SteamCMD
				--update|-u		Update SteamCMD

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

	if [[ "${STEAMCMD_ROOT}/steam.sh" ]]; then
		INSTALLED="yes"
	else
		INSTALLED="no"
	fi

	cat<<- _EOF_
	#################################################
	# steamcmd-wrapper
	# Running on: ${OS}
	# Installed?: ${INSTALLED}
	#################################################

	_EOF_

	# Execute steamcmd for outlined functions
	if [[ ${TYPE} == "download" && ${ACTION} == "download-files" ]]; then

		detect_steamcmd
		download_game_files

	elif [[ ${TYPE} == "info" && ${ACTION} == "fetch" ]]; then

		detect_steamcmd
		get_appid_info

	elif [[ ${TYPE} == "status" && ${ACTION} == "fetch" ]]; then

		read -erp "    Steam username: " STEAM_LOGIN_NAME
		detect_steamcmd
		get_appid_status

	elif [[ ${TYPE} == "game-server" && ${ACTION} == "setup" ]]; then

		detect_steamcmd
		install_game_server

	fi

}

# start main
main
