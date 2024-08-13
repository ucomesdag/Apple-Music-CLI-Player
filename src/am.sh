#!/usr/bin/env bash

# set the path to this file
basedir="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit; pwd -P )"

# download viu to the destination if it is not present
command -v viu >/dev/null || \
[ -f "$basedir"/viu ] || \
  curl -Lo "$basedir"/viu https://github.com/atanunq/viu/releases/latest/download/viu-x86_64-apple-darwin &>/dev/null && \
  chmod +x "$basedir"/viu

# alias viu if it is in the same directory
[ -f "$basedir"/viu ] && \
  shopt -s expand_aliases && \
  alias viu="$basedir"/viu

__clear_screen(){
  # move the cursor to the top of the screen
  # (instead of clearing to avoid flickering)
  printf '\033[;H'
  # Overwrite screen
  out=''
  for line in $(seq 0 $(tput lines)); do
    out="${out}$(printf '%*s\n' "$(tput col)")"
  done
  printf "$out"
  # move the cursor back the top of the screen
  printf '\033[;H'
}

# Track properties
previousTrackPoperties=''

np(){
  # clear the screen first
  clear
  # hide the cursor (as we will later use this to refresh the screen)
  printf '\e[?25l'
  init=1
  help='false'
  # get current width
  cols=$(tput cols)

  # formating
  cyan=$(echo -e '\e[00;36m')
  nocolor=$(echo -e '\033[0m')
  bold=$(echo -e '\e[1m')
  nobold=$(echo -e '\e[0m')

  while :
  do
    # move the cursor to the top of the screen
    # (instead of clearing to avoid flickering)
    printf '\033[;H'
    # Prevent error messages when nothing is playing
    trackProperties=$(osascript -e 'tell application "Music" to get properties of current track' 2>/dev/null)
    if [ $? -ne 0 ]; then
      [ -z $waiting ] || [ "$waiting" = "false" ] && __clear_screen
      waiting=true
      paste <(printf '\n\n\n%b' "        ${bold}Nothing is playing..${nobold}")
      sleep 3
    else
      waiting=false
      keybindings="Keybindings:

  p                       Play / Pause
  f                       Forward one track
  b                       Backward one track
  >                       Begin fast forwarding current track
  <                       Begin rewinding current track
  R                       Resume normal playback
  +                       Increase Music.app volume 5%
  -                       Decrease Music.app volume 5%
  s                       Toggle shuffle
  r                       Toggle song repeat
  q                       Quit np
  Q                       Quit np and Music.app
  ?                       Show / hide keybindings"

      playbackInfo=$(osascript -e 'tell application "Music" to get {player position} & {duration} of current track')
      playbackSettings=$(osascript -e 'tell application "Music" to get {sound volume, shuffle enabled, song repeat}')

      arr=(${playbackSettings})
      vol="$(cut -d , -f 1 <<< ${arr[0]})"
      shuffle="$(cut -d , -f 1 <<< ${arr[1]})"
      repeat="${arr[2]}"

      arr=(${playbackInfo})
      curr=$(cut -d . -f 1 <<< "${arr[-2]}")
      currMin=$(( curr / 60 ))
      currSec=$(( curr % 60 ))
      [ ${#currMin} = 1 ] && currMin="0$currMin"
      [ ${#currSec} = 1 ] && currSec="0$currSec"
 
      if (( curr < 2 || init == 1 )); then
        # Only retrieve track info when the track changes
        if [ "$trackProperties" != "$previousTrackPoperties" ]; then
          trackProperties=$previousTrackPoperties

          init=0
          name=$(osascript -e 'tell application "Music" to get name of current track')
          artist=$(osascript -e 'tell application "Music" to get artist of current track')
          album=$(osascript -e 'tell application "Music" to get album of current track')
          end=$(cut -d . -f 1 <<< "${arr[-1]}")
          endMin=$(( end / 60 ))
          endSec=$(( end % 60 ))

          if [ ${#endMin} = 1 ]
          then
            endMin="0$endMin"
          fi
          if [ ${#endSec} = 1 ]
          then
            endSec="0$endSec"
          fi

          if [ "$1" != "-t" ]
          then
            rm "$basedir"/tmp* &>/dev/null
            osascript "$basedir"/album-art.applescript
            if [ -f "$basedir"/tmp.png ]; then
              art=$(viu -b -w 31 -h 14 "$basedir"/tmp.png)
            else
              art=$(viu -b -w 31 -h 14 "$basedir"/tmp.jpg)
            fi
          fi
        fi
      fi

      [ $vol = 0 ] && volIcon='🔇 ' || volIcon='🔊 '
      [ $shuffle = 'false' ] && shuffleIcon='➡️ ' ||  shuffleIcon='🔀 '
      [ $repeat = 'off' ] && repeatIcon='↪️ ' 
      [ $repeat = 'one' ] && repeatIcon='🔂 ' 
      [ $repeat = 'all' ] && repeatIcon='🔁 '
      
      

      # volBars='▁▂▃▄▅▆▇█' 
      volBars='▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇'
      vol=$(printf "%.0f" "$(echo "scale=3;(${#volBars}/100)*$vol" | bc)")
      volBG=${volBars:$vol}
      vol=${volBars:0:$vol}
      
      progressBars='▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇'
      percentRemain=$(printf "%.0f" "$(echo "scale=3;(${#progressBars}/100)*((100/$end)*$curr)" | bc)")
      progBG=${progressBars:$percentRemain}
      prog=${progressBars:0:$percentRemain}

      # Reload if width changes
      new_cols=$(tput cols)
      if [ $new_cols -ne $cols ]; then
        cols=$new_cols
        exec "$0" np
      fi
     
      # Set fixed text width and add padding to clear previous text
      fixedWidth=$(( $cols - 40 ))
      padding="$(printf '%*s' "$fixedWidth")"
      name=${name:0:$fixedWidth}
      artist=${artist:0:$fixedWidth}
      album=${album:0:$fixedWidth}

      if [ $help = 'true' ]; then
        printf '%s\n' "$keybindings"
      else
        if [ "$1" = "-t" ]
        then
          paste <(printf '%b' \
                    "\n" \
                    "Title : $(printf "%b" "${bold}$name${nobold}" "${padding:${#name}}")\n" \
                    "Artist: $(printf "%b" "${bold}$artist${nobold}" "${padding:${#artist}}")\n" \
                    "Album : $(printf "%b" "${bold}$album${nobold}" "${padding:${#album}}")\n" \
                    "\n" \
                    "Time  : $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec\n" \
                    "Volume:  $volIcon   ${cyan}$vol${nocolor}$volBG ${bold}$shuffleIcon$repeatIcon${nobold}" \
                  ) 
        else
          paste <(printf %s "$art") <(printf %s "") <(printf %s "") <(printf %s "") <(printf '%b' \
                    "\n" \
                    "Title : $(printf "%b" "${bold}$name${nobold}" "${padding:${#name}}")\n" \
                    "\n" \
                    "Artist: $(printf "%b" "${bold}$artist${nobold}" "${padding:${#artist}}")\n" \
                    "\n" \
                    "Album : $(printf "%b" "${bold}$album${nobold}" "${padding:${#album}}")\n" \
                    "\n" \
                    "Time  : $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec\n" \
                    "\n" \
                    "\n" \
                    "\n" \
                    "\n" \
                    "Volume:  $volIcon  ${cyan}$vol${nocolor}$volBG ${bold}$shuffleIcon$repeatIcon${nobold}" \
                  )
        fi
      fi
      
      input=$(/bin/bash -c "read -n 1 -t 1 input; echo \$input | xargs")
      if [[ "${input}" == *"s"* ]]; then
        if $shuffle ; then
          osascript -e 'tell application "Music" to set shuffle enabled to false'
        else
          osascript -e 'tell application "Music" to set shuffle enabled to true'
        fi
      elif [[ "${input}" == *"r"* ]]; then
        if [ $repeat = 'off' ]; then
          osascript -e 'tell application "Music" to set song repeat to all'
        elif [ $repeat = 'all' ]; then
          osascript -e 'tell application "Music" to set song repeat to one'
        else
          osascript -e 'tell application "Music" to set song repeat to off'
        fi
      elif [[ "${input}" == *"+"* ]]; then
        osascript -e 'tell application "Music" to set sound volume to sound volume + 5'
      elif [[ "${input}" == *"-"* ]]; then
        osascript -e 'tell application "Music" to set sound volume to sound volume - 5'
      elif [[ "${input}" == *">"* ]]; then
        osascript -e 'tell application "Music" to fast forward'
      elif [[ "${input}" == *"<"* ]]; then
        osascript -e 'tell application "Music" to rewind'
      elif [[ "${input}" == *"R"* ]]; then
        osascript -e 'tell application "Music" to resume'
      elif [[ "${input}" == *"f"* ]]; then
        osascript -e 'tell app "Music" to play next track'
      elif [[ "${input}" == *"b"* ]]; then
        osascript -e 'tell app "Music" to back track'
      elif [[ "${input}" == *"p"* ]]; then
        osascript -e 'tell app "Music" to playpause'
      elif [[ "${input}" == *"q"* ]]; then
        # Turn the cusrsor back on
        printf '\e[?25h'
        clear
        exit
      elif [[ "${input}" == *"Q" ]]; then
        # Turn the cusrsor back on
        printf '\e[?25h'
        killall Music
        clear
        exit
      elif [[ "${input}" == *"?"* ]]; then
        if [ $help = 'false' ]; then
          help='true'
        else
          help='false'
        fi
      fi
      if [[ "${input}" ]]; then
        __clear_screen
      else
        sleep 0.1
      fi
    fi
  done
}

list(){
  usage="Usage: list [-grouping] [name]

  -s                    List all songs.
  -r                    List all albums.
  -r PATTERN            List all songs in the album PATTERN.
  -a                    List all artists.
  -a PATTERN            List all songs by the artist PATTERN.
  -p                    List all playlists.
  -p PATTERN            List all songs in the playlist PATTERN.
  -g                    List all genres.
  -g PATTERN            List all songs in the genre PATTERN."
  if [ "$#" -eq 0 ]; then
    printf '%s\n' "$usage";
  else
    if [ $1 = "-p" ]
    then
      if [ "$#" -eq 1 ]; then
        shift
        osascript -e 'tell application "Music" to get name of playlists' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      else
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get name of every track of playlist (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      fi
    elif [ $1 = "-s" ]
    then
      if [ "$#" -eq 1 ]; then
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get name of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      else
        echo $usage
      fi
    elif [ $1 = "-r" ]
    then
      if [ "$#" -eq 1 ]; then
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get album of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      else
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose album is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      fi
    elif [ $1 = "-a" ]
    then
      if [ "$#" -eq 1 ]; then
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get artist of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      else
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose artist is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      fi
    elif [ $1 = "-g" ]
    then
      if [ "$#" -eq 1 ]; then
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get genre of every track' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      else
        shift
        osascript -e 'on run args' -e 'tell application "Music" to get name of every track whose genre is (item 1 of args)' -e 'end' "$*" | tr "," "\n" | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
      fi
    else
      printf '%s\n' "$usage";
    fi
  fi
}

play() {
  usage="Usage: play [-grouping] [name]

  -s                    Fzf for a song and begin playback.
  -s PATTERN            Play the song PATTERN.
  -r                    Fzf for a album and begin playback.
  -r PATTERN            Play from the album PATTERN.
  -a                    Fzf for an artist and begin playback.
  -a PATTERN            Play from the artist PATTERN.
  -p                    Fzf for a playlist and begin playback.
  -p PATTERN            Play from the playlist PATTERN.
  -g                    Fzf for a genre and begin playback.
  -g PATTERN            Play from the genre PATTERN.
  -l                    Play from your entire library."
  if [ "$#" -eq 0 ]; then
    printf '%s\n' "$usage"
  else
    if [ $1 = "-p" ]
    then
      if [ "$#" -eq 1 ]; then
        playlist=$(osascript -e 'tell application "Music" to get name of playlists' | tr "," "\n" | fzf)
        set -- ${playlist:1}
      else
        shift
      fi
      osascript -e 'on run argv
        tell application "Music" to play playlist (item 1 of argv)
      end' "$*"
    elif [ $1 = "-s" ]
    then
      if [ "$#" -eq 1 ]; then
        song=$(osascript -e 'tell application "Music" to get name of every track' | tr "," "\n" | fzf)
        set -- ${song:1}
      else
        shift
      fi
    osascript -e 'on run argv
      tell application "Music" to play track (item 1 of argv)
    end' "$*"
    elif [ $1 = "-r" ]
    then
      if [ "$#" -eq 1 ]; then
        album=$(osascript -e 'tell application "Music" to get album of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
        set -- ${album:1}
      else
        shift
      fi
      osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose album is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
    elif [ $1 = "-a" ]
    then
      if [ "$#" -eq 1 ]; then
        artist=$(osascript -e 'tell application "Music" to get artist of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
        set -- ${artist:1}
      else
        shift
      fi
      osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose artist is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
    elif [ $1 = "-g" ]
    then
      if [ "$#" -eq 1 ]; then
        genre=$(osascript -e 'tell application "Music" to get genre of every track' | tr "," "\n" | sort | awk '!seen[$0]++' | fzf)
        set -- ${genre:1}
      else
        shift
      fi
      osascript -e 'on run argv' -e 'tell application "Music"' -e 'if (exists playlist "temp_playlist") then' -e 'delete playlist "temp_playlist"' -e 'end if' -e 'set name of (make new playlist) to "temp_playlist"' -e 'set theseTracks to every track of playlist "Library" whose genre is (item 1 of argv)' -e 'repeat with thisTrack in theseTracks' -e 'duplicate thisTrack to playlist "temp_playlist"' -e 'end repeat' -e 'play playlist "temp_playlist"' -e 'end tell' -e 'end' "$*"
    elif [ $1 = "-l" ]
    then
      osascript -e 'tell application "Music"' -e 'play playlist "Library"' -e 'end tell'
    else
      printf '%s\n' "$usage";
    fi
  fi
}

usage="Usage: am.sh [function] [-grouping] [name]

  list -s              	List all songs in your library.
  list -r              	List all albums.
  list -r PATTERN       List all songs in the album PATTERN.
  list -a              	List all artists.
  list -a PATTERN       List all songs by the artist PATTERN.
  list -p              	List all playlists.
  list -p PATTERN       List all songs in the playlist PATTERN.
  list -g              	List all genres.
  list -g PATTERN       List all songs in the genre PATTERN.

  play -s               Fzf for a song and begin playback.
  play -s PATTERN       Play the song PATTERN.
  play -r              	Fzf for a album and begin playback.
  play -r PATTERN       Play from the album PATTERN.
  play -a              	Fzf for an artist and begin playback.
  play -a PATTERN       Play from the artist PATTERN.
  play -p              	Fzf for a playlist and begin playback.
  play -p PATTERN       Play from the playlist PATTERN.
  play -g              	Fzf for a genre and begin playback.
  play -g PATTERN       Play from the genre PATTERN.
  play -l              	Play from your entire library.
  
  np                    Open the \"Now Playing\" TUI widget.
                        (Music.app track must be actively
                        playing or paused)
  np -t			            Open in text mode (disables album art)
 
  np keybindings:

  p                     Play / Pause
  f                     Forward one track
  b                     Backward one track
  >                     Begin fast forwarding current track
  <                     Begin rewinding current track
  R                     Resume normal playback
  +                     Increase Music.app volume 5%
  -                     Decrease Music.app volume 5%
  s                     Toggle shuffle
  r                     Toggle song repeat
  q                     Quit np
  Q                     Quit np and Music.app
  ?                     Show / hide keybindings"

if [ "$#" -eq 0 ]; then
  printf '%s\n' "$usage";
else
  if [ $1 = "np" ]
  then
    shift
    np "$@"
  elif [ $1 = "list" ]
  then
    shift
    list "$@"
  elif [ $1 = "play" ]
  then
    shift
    play "$@"
  elif [ $1 = "install" ]
  then
    shift
    install "$@"
  else
    printf '%s\n' "$usage";
  fi
fi
