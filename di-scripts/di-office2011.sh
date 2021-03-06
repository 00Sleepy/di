#!/bin/zsh -f
# Purpose:
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2016-04-15


MSWORD='/Applications/Microsoft Office 2011/Microsoft Word.app'

DIR="$HOME/Downloads"

################################################################################


NAME="$0:t:r"

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

################################################################################


zmodload zsh/datetime

TIME=$(strftime "%Y-%m-%d-at-%H.%M.%S" "$EPOCHSECONDS")

HOST=`hostname -s`
HOST="$HOST:l"

LOG="$HOME/Library/Logs/$NAME.log"

[[ -d "$LOG:h" ]] || mkdir -p "$LOG:h"
[[ -e "$LOG" ]]   || touch "$LOG"

function timestamp { strftime "%Y-%m-%d at %H:%M:%S" "$EPOCHSECONDS" }
function log { echo "$NAME [`timestamp`]: $@" | tee -a "$LOG" }

################################################################################

INSTALLED_VERSION=`defaults read ${MSWORD}/Contents/Info CFBundleShortVersionString 2>/dev/null || echo 0`

if [[ "$INSTALLED_VERSION" == "0" ]]
then

log "

$NAME cannot continue because $MSWORD does not exist.

If you are trying to install Office 2011 for Mac,
download

	http://officecdn.microsoft.com/pr/MacOffice2011/en-us/MicrosoftOffice2011.dmg

and install it, then re-run this script.

"

	exit 0
fi

################################################################################

RSS='http://www.microsoft.com/mac/autoupdate/0409MSOf14.xml'

TEMPFILE="${TMPDIR-/tmp}/${NAME}.${TIME}.$$.$RANDOM.xml"

##log "NAME: Saving $RSS to \n$TEMPFILE ..."

curl -sfL "$RSS" > "$TEMPFILE"

if [ ! -s "$TEMPFILE" ]
then
	log "TEMPFILE is empty at $TEMPFILE"
	exit 1
fi


LATEST_VERSION=`fgrep -A1 '<key>Title</key>' "$TEMPFILE" | tail -1 | awk '{print $3}'`

URL=`fgrep -i .dmg  "$TEMPFILE" | tail -1 | sed 's#.*<string>##g; s#</string>##g'`

FILENAME="$URL:t"

################################################################################

if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]
then
	log "Up-To-Date (Installed/Latest Version = $INSTALLED_VERSION)"
	exit 0
fi

autoload is-at-least

is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

if [ "$?" = "0" ]
then
	log "Up-To-Date (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"
	exit 0
fi

################################################################################


log "Outdated (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"

cd "$DIR"

log "Downloading $URL to $FILENAME"

curl --continue-at - --location --fail --output "$FILENAME" "$URL"

EXIT="$?"

case "$EXIT" in
	0|22|416)
				:
	;;

	*)
		log "curl appears to have failed with exit code = $EXIT"
		exit 1
	;;

esac

if [ ! -e "$FILENAME" ]
then
	log "NAME: FILENAME not found at $FILENAME"
	exit 1
fi


MNTPNT=$(echo -n "Y" | hdid -plist "$FILENAME" 2>/dev/null | fgrep -A 1 '<key>mount-point</key>' | tail -1 | sed 's#</string>.*##g ; s#.*<string>##g')

if [[ "$MNTPNT" == "" ]]
then
	log "NAME: MNTPNT is empty"
	exit 1
fi

echo "Mounted $FILENAME at $MNTPNT"

PKG=$(find "$MNTPNT" -iname \*.pkg -maxdepth 2 -print)

if [[ "$PKG" == "" ]]
then
	log "NAME: PKG is empty"
	exit 1
fi

## Check to make sure that no Office-related process is running
## "$MSWORD:h" = the "head" aka parent directory of MSWord
## which is presumably where all other related apps are stored

RUNNING_COUNT=`ps auxwwww | fgrep -v 'fgrep' | fgrep  "$MSWORD:h" | wc -l | tr -dc '[0-9]'`

while [ "$RUNNING_COUNT" != "0" ]
do

		## Make sure the user sees this error,
		## as it prevents us from continuing
	open -a "Console" "$LOG"

	if [ "$RUNNING_COUNT" = "1" ]
	then
		log "You have 1 app or process from $MSWORD:h running. Please quit it. Waiting 30 seconds."
	else
		log "You have $RUNNING_COUNT apps or processes from $MSWORD:h running. Please quit them. Waiting 30 seconds."
	fi

	sleep 30
done

sudo installer -pkg "$PKG" -target / -lang en 2>&1 | tee -a "$LOG"


EXIT="$?"

if [ "$EXIT" = "0" ]
then

	log "NAME: Installer success"

else
	log "NAME: installer failed (\$EXIT = $EXIT)"

	exit 1
fi




diskutil eject "$MNTPNT" 2>&1 | tee -a "$LOG"

exit 0
#EOF
