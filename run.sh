#!/bin/zsh -ex
###################################################################################################################
#
#                                         No Blu Hope
#                               AKA "No New Hope" Bluray Edition
#                            AKA "No New Hope" 2K carat gold edition
#
# This is the 1080p lossless recut from "official version" bluray back to 1977 version.
# This is the bluray version of "No New Hope" https://archive.org/details/reremaster (created from DVDs in 2010)
#
# by a dual CS degree 20+ year pro coder -- who saw it summer when she was 6 -- my secrets, find you can, inside.
#
###################################################################################################################
#
# Assumes you have an .iso burned from your bluray, located here:
export ISO=Star.Wars.Episode.4.A.New.Hope.1977.BluRay.1080p.AVC.DTS-HD.MA6.1-CHDBits.iso;
# config D1 and D2 to scratch drives -- 2 is ideal (for i/o speed) but can be same
export D1=/Volumes/bff-bup;
export D2=/Volumes/bff;
export OVID="$D1/tmp/negative1.mkv"; # siver screen negative1 Jan 11,2016 first release
#
###################################################################################################################

# xxx for PS3 -- M2TS (AKA AVCHD) may have to downmix to 5.1 AC-3 <= 448kb/s
# PS3: 1080p 5.1 AAC mp4 works -- ffmpeg -i orig.m2ts -c:v copy -c:a libfaac -ac 6  1080p-aac-5.1.mp4
# xxx may need CFR and not VFR  (DVD version played  Audio: ac3, 48000 Hz, 5.1(side), fltp, 448 kb/s)
# xxx may need to always pull PS3 network cable *when watching mp4 or burned bluray* due to audio signature checking

export THISDIR=$(dirname "$0");
echo "SCRIPT DIR: $THISDIR";

function mp(){ /Applications/MPlayerX.app/Contents/MacOS/MPlayerX "$@"; }

function setup(){
  brew install ffmpeg; # includes ffprobe
}

function extraction(){
  DIR=/Volumes/CDROM/BDMV/STREAM/; # this is where "open" (next) will mount .iso to

  open $ISO; # mount .iso image

  # losslessly keep (just) the 6.1 DTS audio and video -- it comes in ~147sec first piece; then rest of film
  ffmpeg -y -i $DIR/00300.m2ts -c copy -map 0:0 -map 0:1 $D2/starwars-1080p-A.m2ts;
  ffmpeg -y -i $DIR/00301.m2ts -c copy -map 0:0 -map 0:1 $D2/starwars-1080p-B.m2ts;

  # losslessly concat -- and nicely reset PTS/DTS in 2nd piece (to come right after 1st piece)
  cd $D2;
  ( echo "file 'starwars-1080p-A.m2ts'";
    echo "file 'starwars-1080p-B.m2ts'" ) >| concat.txt;
  ffmpeg -y -f concat -i concat.txt -codec copy -f mpegts $D1/starwars-1080p.m2ts;
  rm concat.txt;
  chmod ugo-wx $D1/starwars-1080p.m2ts;
}

# xxx try small edited sample and PS3 verify as mp4...
# xxx once done
#   identify all groups of sequential untouched segments and "cat" them into
#   final # groups (for maximal A/V seaming), then "rebase" each group PTS to 0
#   then ffmpeg concat them.  that should mean _at most_ that many pops/seam oddities...

# xxx to avoid "bloops" when doing REMOVE and REPLACE operations, try keeping REMOVED keyframe and merge into the _prior_ GOP since B-frames, eg:
#  ffmpeg -i nix/0.15.10.3.ts  -c copy  -vframes 1 -copyts -shortest  0.15.10.3.ts
function seam(){
  rm -rfv  seam;
  mkdir -p seam;
  touch seam/concat.txt;
  for i in "$@"; do
    ln -s ../$i seam/$i;
    echo "file '$i'" >> seam/concat.txt;
  done
  cat seam/concat.txt;
  ffmpeg -y -f concat -i seam/concat.txt -codec copy -f mpegts -fflags +genpts -async 1 seam.m2ts;
}

function pts(){
  line; ffmpeg -i "$1" 2>&1 |egrep 'Duration:|start:';
  line; vpackets "$1" 2>/dev/null|head -2|cut -f5 -d'|';
  line; apackets "$1" 2>/dev/null|head -2|cut -f5 -d'|';
}


function packets(){
  ffprobe -v 0 -hide_banner -select_streams $PTYPE -show_packets -print_format compact "$@";
}
function vpackets(){ PTYPE=v; packets "$@"; }
function apackets(){ PTYPE=a; packets "$@"; }


# (losslessly) split the official bluray film version into files -- one per GOP
function segment(){
  cd $D1;
  mkdir -p tmp;
  cd tmp;

  # Split/segment to a supersmall duration -- but in reality will default to never cutting up a GOP.
  # So, will start each segment with a keyframe, and have 1 keyframe and 1 GOP per segment (output file).
  ffmpeg -i ../starwars-1080p.m2ts -c copy -f hls -c copy -hls_time 0.1 -hls_segment_filename '%04d.ts' out.m3u8

  # Display/manually check segment times -- optional
  # NOTE: for vpackets output, we use column 5, which is PTS.   (DTS, column 7, is _Decode_ TimeStamp)
  # Adjacent PTS go negative when B-frames, but PTS are always monotonic between keyframes.
  vpackets *ts |egrep 'K$'|cut -d'|' -f5|cut -f2 -d=|php -R 'echo number_format($argn,1,".","")."\n";';


  # Convert each segment to seconds into the film for easier editing/grokking
  # Extract PTS of (1st/only) keyframe from sources, eg: "13.092351"
  # First, make like "0013.1" (round, 1 decimal, 0-padded 4 digits lead).
  # Then transform to like "0.50.56.2.ts"   (which is like timecode:  00:50:56.2  )
  # This also keeps the filename sortable.
    php -- "$@" <<\
"EOF"
  <?
    require_once(getenv("THISDIR")."/Video.inc");

    echo "Renaming files: ";
    foreach (glob("????.ts") as $fi){
      $PTS = `printf '%06.1f' $(vpackets $fi 2>/dev/null |egrep -m1 'flags=K_*$'|cut -d'|' -f5|cut -f2 -d=)`;
      if (!preg_match("/^(\d\d\d\d\.\d)$/", $PTS, $mat))
        throw new Exception("uho bad $PTS");
      $TO = preg_replace("/^0/","",str_replace(":",".",Video::hms($mat[1],0,1)));

      if (file_exists("$TO.ts"))
        throw new Exception("UHO LOOKS LIKE NEED ANOTHER FLOAT POINT PRECISION FOR PTS DUE TO TWO GOPS TOO CLOSE?");

      rename($fi, "$TO.ts");
      echo ".";
    }
    echo "\n";
EOF
}


# handy debugging function
function seam-across-cuts(){
  if [ ! -d nix ]; then echo "FATAL: WRONG SUBDIR?"; return; fi;

  # array variables
  typeset -a A;
  typeset -a B;

  for i in nix/[a-z]*; do
    FIRST=$(/bin/ls $i/?.??.??.?.ts |head -1 |cut -f3 -d/);
     LAST=$(/bin/ls $i/?.??.??.?.ts |tail -1 |cut -f3 -d/);
    echo "SEAMING: [$i] [$FIRST .. $LAST]";
    A=($(php -r 'echo join("\n", array_slice(array_filter(glob("?.??.??.?.ts"), function($e){ return $e<="'$FIRST'"; }),-10,10));'));
    B=($(php -r 'echo join("\n", array_slice(array_filter(glob("?.??.??.?.ts"), function($e){ return $e>="'$LAST'" ; }),0,10));'));
    set -x;
    cat $A >| a.ts;
    cat $B >| b.ts;
    set +x;
    seam a.ts b.ts;
    mplayer -framedrop seam.m2ts >/dev/null 2>&1;
    open seam.m2ts;
    line;
    echo -n "Continue? [RETURN or CTL-C] ";
    read cont;
  done
}


function credits(){
  # we'll be replacing the VIDEO (keep AUDIO) of this range of clips (inclusive)
  cat $(clips 0.00.01.4.ts 0.01.54.7.ts) > creditsNIX.ts;
  ffmpeg -i creditsNIX.ts -vn -c:a copy creditsA.ts;
  rm creditsNIX.ts;

  # start of 42s was observed from manually watching $OVID
  # however!  bluray has a 1.4s offset, so updated a bit
  # 114.1s was found via dumping A/V packets in creditsNIX.ts and summing
  ffmpeg -i "$OVID" -ss 41 -t 114.1 -an -c:v copy creditsV.ts;

  ffmpeg -i creditsA.ts -i creditsV.ts -c copy creditsNEW.ts;
}


function clips(){
  LEFT=${1:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}
  RITE=${2:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}

  LEFT=$(echo "$LEFT" |perl -pe 's/\.ts$//');
  RITE=$(echo "$RITE" |perl -pe 's/\.ts$//');

  if [[ $RITE =~ \\. ]]; then
    # return the filenames in the wanted time range
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts | fgrep -B10000 $RITE.ts;
  elif [[ $RITE =~ \\- ]]; then
    # eg "-10" which means return (up to) 10 clips -- the 9 clips before $LEFT and $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -B100000 $LEFT.ts | tail $RITE;
  else
    # eg "10" which means return (up to) 10 clips -- $LEFT and the 9 clips after $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts | head -$RITE;
  fi
}


function cuts(){
  # inclusive ranges
cat >| /tmp/.in <<EOF
  0.11.20.6   0.11.24.9 # fade to sky to r2 in canyon
  0.15.10.3   0.15.32.6 # patrol dewbacks
  0.42.55.9   0.43.15.4 # entering mos eisley
  0.44.00.3   0.44.04.9 # entering mos eisley2
  0.52.41.7   0.54.13.8 # jabba
  0.55.37.5   0.55.40.3 # falcon takeoff mos eisley
  1.43.15.3   1.43.44.2 # biggs
EOF
  if [ ! -f out.m3u8 ]; then echo "FATAL: WRONG SUBDIR?"; return; fi;
  mkdir -p nix;
  for i in $(cat /tmp/.in | tr ' ' '_'); do
    FROM=$(echo "$i" |tr -s '_' ' ' |cut -f2  -d' ');
      TO=$(echo "$i" |tr -s '_' ' ' |cut -f3  -d' ');
    SLUG=$(echo "$i" |tr -s '_' ' ' |cut -f4- -d' ' |tr -d '#' |tr ' ' - |perl -pe 's/^\-*//');

    set -x;
    mkdir -p nix/$SLUG;
    mv $(ls |fgrep -A100000 $FROM.ts | fgrep -B10000 $TO.ts) nix/$SLUG/
    set +x;
  done;
  rm /tmp/.in;
}


function replacements(){
cat >| /tmp/.in <<EOF
Minimum Viable Product fixxxmes:

-cantina: bagpiper
-cantina: snaggletooth

?-sandcrawler day shot (would need to dissolve from "look sir, droids!")
?-falcon landing in yavin
?-xwings emgerging around planet to face death star
?-dogfighting?
EOF
}

function stormtroopers-deadend(){
  # We cant have Han round corner chasing stormtroopers and run into a new CG + BG "digital painting" of an entire
  # galley of stormtroopers and such, now can we?
  # In '77 Han runs around corner, only to find the troopers hav hit a deadend and they need to fight their way out...

  # keep the new audio
  cat 1.27.42.5.ts  1.27.43.5.ts >| new.ts; # 1.9s
  ffmpeg -y -i new.ts -c copy -vn newA.ts;

  # this gets us 3 keyframes bookending 2 GOPs, for 1977 video
  ffmpeg -y -ss 5150.53 -i negative1.mkv -shortest -t 1.0 -an -c copy 1977V.ts;

  # merge new audio and 1977 video
  ffmpeg -y -i newA.ts -i 1977V.ts -c copy merged.ts;

  seam  1.27.41*  merged.ts  1.27.4[4-9]ts;

  mv seam.m2ts  stormtroopers-deadend.m2ts;
  rm -f new.ts newA.ts 1977V.ts merged.ts;
}

function no-biggs(){
  # when biggs' scene was removed, luke walks under an xwing [CUT] jumps to him starting up ladder to his own xwing
  # transition was too awkward for the live single take (with biggs scene removed in the middle) so they slid up
  # a (short) wide-angle hangar shot to separate the split scene.

  cat  1.43.09.2.ts  1.43.10.3.ts  1.43.10.8.ts  >| a.ts; # luke walking from leia

  echo 1.43.14.3.ts # luke touching xwing underside.  1977 film moved this out of sequence, from 2 GOPs ahead, to allow smoother biggs deletion

  cat  1.43.11.3.ts  1.43.12.4.ts  1.43.13.4.ts  >| b.ts; # hangar. biggs removed from here to next

  echo 1.43.45.2.ts # luke climbs up xwing ladder

  seam  a.ts  1.43.14.3.ts  b.ts  1.43.45.2.ts;
  mv seam.m2ts no-biggs.m2ts;
}
function greedo(){
  ffmpeg -i 0.50.54.7.ts -c copy -vframes 11 trimmed.ts;
  mv  0.50.54.7.ts  nix/;
  mv  trimmed.ts  0.50.54.7.ts;
}
function dewbacks(){ #xxx still may have some issues?  xxx do want to "hold" first keyframe of "b.ts" a bit??

  # 0.15.10.3.ts  # dissolve wipe just barely "leaks" clipped dewback scene -- so removed
  cat $( clips 0.15.00.7.ts 0.15.09.3.ts ) >| a.ts;
  cat $( clips 0.15.33.6.ts 0.15.39.6.ts ) >| b.ts;
  seam  a.ts  b.ts;
  rm a.ts b.ts;
  mv  seam.m2ts  dewbacks.m2ts;
}
function eisley(){
  # replace starting with and including the endpoints (inclusive)
  # keeping part (just before; ends with) "mos eisley spaceport, you will never find..";
  # replacing (just after) from start of: speeder zips in from outskirts of mos eisley..
  #   all the way to..
  # cantina!  start of da funk!

  typeset -a NIX;   # array variable
  NIX=( 0.42.55.0.ts  0.43.16.4.ts  0.43.17.4.ts  0.43.18.4.ts  0.43.19.4.ts  0.43.20.0.ts ); #xxx 5.1 seconds more omitted


  # copy the bluray (which now has extra CG shots removed) for that time range to a temp file:
  typeset -a REPLACE;   # array variable
  REPLACE=( $(clips  0.42.49.1.ts  0.44.52.3.ts) );
  cat $REPLACE >| blu.ts;

  # copy (just) the audio from the bluray for that time range:
  ffmpeg -y -i blu.ts -vn -c:a copy  audio.ts;

  # copy (just) the video from 1977 for corresponding time range:
  # [ 0.43.07.5.ts   0:44:40.5.ts ]
  # (takes awhile by using frame-accurate seeking)
  ffmpeg -y -i $OVID  -ss 00:43:07.5  -to 00:44:40.5  -an -c:v copy  video.ts;

  # merge A/V
  ffmpeg -y -i video.ts -i audio.ts -c copy $0.ts;
  rm -f blu.ts audio.ts video.ts;
}
function kenobi-hut(){
  # copy the bluray for video we will replace to temp file:
  typeset -a REPLACE; # array variable
  LEFT=0.32.33.6.ts;#  NOTE: we need to go 1 bluray GOP backwards (than 0.32.34.6.ts) since the 1977 GOP spread is bigger
  RITE=0.32.39.1.ts;#  NOTE: go 1 bluray GOP extra (than 0.32.38.4.ts) to get A/V to seam better
  REPLACE=( $( clips $LEFT $RITE ) );
  cat $REPLACE >| blu.ts;

  # copy (just) the audio from the bluray for that time range:
  ffmpeg -y -i blu.ts -vn -c:a copy  audio.ts;

  # copy (just) the video from 1977 for corresponding time range:
  # NOTE: using quick seek (deliberately) here since we have listed where keyframes are in $OVID
  ffmpeg -y -ss 1973.779 -i $OVID  -t 4.6  -an -c:v copy  video.ts;

  # merge A/V
  ffmpeg -y -i video.ts -i audio.ts -c copy $0.ts;

  # now test it fully seamed in, with 10 clips (~9s) before and after
  cat $(clips $LEFT -10 |fgrep -v $LEFT) >| pre.ts;
  cat $(clips $RITE  10 |fgrep -v $RITE) >| post.ts;
  seam pre.ts $0.ts post.ts;
  mv seam.m2ts $0-seamed.ts;

  # cleanup
  rm -f blu.ts audio.ts video.ts;
  rm -f pre.ts post.ts;
}

function no-new-hope-DVD-EDL(){
cat<<EOF
REPLACE i[25b-3544p]i WITH [0i-3521p] NEWAUDIO # credits
REMOVE  p[16312b-16465p]i  # r2d2 tatooine sky
REPLACE p[18922i-19083p]i WITH [18884i-19040p] NEWAUDIO  # sandcrawler1 (night)
REPLACE p[21462i-21831p]i WITH [21422i-21789p] NEWAUDIO  # crawler night shot
REMOVE  p[21832b-22221p]i  # middle lizards added stuff
REPLACE p[22221b-22810p]i WITH [21800i-22289p] OLDAUDIO   # snipping out lizards to final crawler shot
REPLACE p[46855b-46967p]i WITH [46334i-46445p] NEWAUDIO  # kenobi hut
REPLACE p[61599b-61646p]i WITH [61076i-61123p] NEWAUDIO  # speeding into mos eisley
REMOVE p[61646b-62280p]i
REPLACE p[62281b-63299p]i WITH [61123i-62141p] NEWAUDIO # to "move along"
REMOVE p[63300i-63420i]i
REPLACE p[63421i-64567p]i WITH [62142i-63287p] NEWAUDIO # speeder moving thru city after "move along" TO enter cantina
REPLACE p[64785b-64861p]i WITH [63506i-63581p] NEWAUDIO  # replace bagpiper back w/ werewolf
REPLACE p[66538i-66622p]i WITH [65270i-65342i] NEWAUDIO  # replace new snaggletooth w/ old
REPLACE p[68458b-68627p]i WITH [67178i-67346p] NEWAUDIO  # outside cantina: before meet solo
REMOVE  p[73247i-73265i]i  # greedo shoots first
REMOVE  p[75802b-78039b]i  # jabba
REMOVE  p[80028i-80110p]i  # falcon takeoff
REPLACE p[126181b-126227p]i WITH [122564i-122609p] NEWAUDIO # stormtroopers dead end
REPLACE i[141175b-141896p]i WITH [137558i-138278i] NEWAUDIO # falcon flying into yavin (plus pyramid shot)
REMOVE  p[148544b-149259b]i  # biggs
REPLACE p[151153b-151280p]i WITH [146918i-147044i] NEWAUDIO # xwings/ywings launching from yavin/ground
REPLACE p[151587i-151844p]i WITH [147350i-147608p] NEWAUDIO # xwings/ywings shortly after rounding planet
REPLACE p[152198b-152302p]i WITH [147962i-148067p] NEWAUDIO # deathstar dogfighting
REPLACE p[152919b-153285p]i WITH [148682i-149051p] NEWAUDIO # deathstar dogfighting
REPLACE p[153675b-153758p]i WITH [149438i-149522p] NEWAUDIO # deathstar dogfighting
REPLACE p[154893i-154939p]i WITH [150662i-150704p] NEWAUDIO # deathstar dogfighting
REPLACE p[155565b-155626b]i WITH [151328i-151391p] NEWAUDIO # deathstar dogfighting
REPLACE p[155816b-156133p]i WITH [151580i-151898i] NEWAUDIO # deathstar dogfighting
REPLACE p[157022p-157183p]i WITH [152786i-152948i] NEWAUDIO # deathstar dogfighting
REPLACE p[157274i-157416p]i WITH [153038i-153176p] NEWAUDIO # deathstar dogfighting
REPLACE p[160836i-160926p]i WITH [156602i-156692i] NEWAUDIO # deathstar dogfighting
REPLACE p[168344p-168391p]i WITH [164108i-164156p] NEWAUDIO # deathstar dogfighting
REPLACE i[168668b-168727p]i WITH [164432i-164489p] NEWAUDIO # racing away from deathstar
REPLACE p[173004b-179471i]i WITH [168770i-174252p] OLDAUDIO # credits
EOF
}
