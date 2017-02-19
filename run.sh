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
# appleTV _should_ be able to do Dolby Digital 5.1 (AKA AC-3)...  _maybe_ at 24fps ?!

export THISDIR=$(dirname "$0");
echo "SCRIPT DIR: $THISDIR";

function mp(){ /Applications/MPlayerX.app/Contents/MacOS/MPlayerX -framedrop hard "$@"; }
function line () {perl -e 'print "_"x80; print "\n\n";'; }

function setup(){
  brew install ffmpeg; # includes ffprobe
  brew install mlt;    # handy for editing, playback, and especially playing one frame at a time back/forth
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
#  ffmpeg -i nix/0.15.10.3.ts  -c copy  -frames 1 -copyts -shortest  0.15.10.3.ts
function seam(){
  rm -rf   seam/;
  mkdir -p seam;
  touch seam/concat.txt;
  for i in "$@"; do
    ln -s ../$i seam/$i;
    echo "file '$i'" >> seam/concat.txt;
  done
  cat seam/concat.txt;
  ffmpeg -y -f concat -i seam/concat.txt -codec copy -f mpegts -fflags +genpts -async 1 seam.m2ts;
}

function seamTS(){ #xxx convert _everywhere_ to this?
  rm -rf   seam/;
  mkdir -p seam;
  touch seam/concat.txt;
  for i in "$@"; do
    ln -s ../$i seam/$i;
    echo "file '$i'" >> seam/concat.txt;
  done
  cat seam/concat.txt;
  ffmpeg -y -f concat -i seam/concat.txt -codec copy -f mpegts -fflags +genpts -async 1 seam.ts;
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
  local LEFT=${1:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}
  local RITE=${2:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}

  LEFT=$(echo "$LEFT" |perl -pe 's/\.ts$//');
  RITE=$(echo "$RITE" |perl -pe 's/\.ts$//');

  if [[ $RITE =~ \\. ]]; then
    # return the filenames in the wanted time range
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts |fgrep -B10000 $RITE.ts;
  elif [[ $RITE =~ \\- ]]; then
    # eg "-10" which means return (up to) 10 clips -- the 9 clips before $LEFT and $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -B100000 $LEFT.ts |tail $RITE;
  else
    # eg "10" which means return (up to) 10 clips -- $LEFT and the 9 clips after $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts |head -$RITE;
  fi
}


function cuts(){
  # inclusive ranges
cat >| /tmp/.in <<EOF
  0.11.20.6   0.11.24.9 # fade to sky to r2 in canyon
  0.15.10.3   0.15.32.6 # patrol dewbacks #xxx
  0.42.55.0   0.43.15.4 # entering mos eisley
  0.44.00.3   0.44.04.9 # entering mos eisley2
  0.43.16.4   0.43.20.0 # entering mos eisley3 audio excess
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
    mv $(clips  $FROM.ts  $TO.ts) nix/$SLUG/
    set +x;
  done;
  rm /tmp/.in;
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
  if [ -e nix/greedo-trimmed/0.50.54.7.ts ]; then
    echo "already done and not rerunnable";
    return;
  fi

  mkdir             nix/greedo-trimmed;
  mv  0.50.54.7.ts  nix/greedo-trimmed;
  ffmpeg -i nix/greedo-trimmed/0.50.54.7.ts -c copy -frames 11 0.50.54.7.ts;
}

function test-seam(){
  LEFT=${1:?   "Usage: $0 [first clip to precede] [last clip to follow] [output name]"}
  RITE=${2:?   "Usage: $0 [first clip to precede] [last clip to follow] [output name]"}
  OUTNAME=${3:?"Usage: $0 [first clip to precede] [last clip to follow] [output name]"}

  # now test it fully seamed in, with 10 clips (~9s) before and after
  cat $(clips $LEFT -10 |fgrep -v $LEFT) >| pre.ts;
  cat $(clips $RITE  10 |fgrep -v $RITE) >| post.ts;
  seamTS pre.ts $OUTNAME.ts post.ts;
  mv seam.ts $OUTNAME-seamed.ts;
}

function replacement-audio(){
  # copies (just) the bluray audio, for the video portion we will be replacing, to audio.ts
  export LEFT=${1:?"Usage: $0 [first clip to replace] [last clip to replace] <optional ffmpeg args>"}
  export RITE=${2:?"Usage: $0 [first clip to replace] [last clip to replace] <optional ffmpeg args>"}

  typeset -a REPLACE; # array variable
  REPLACE=( $( clips $LEFT $RITE ) );
  cat $REPLACE >| blu.ts;

  # copy (just) the audio from the bluray for that time range:
  ffmpeg -y -i blu.ts -vn -c:a copy  $3 $4 $5 $6 $7 $8 $9  audio.ts;
}

function replacement-video(){
  # Copies (just)  the 1977 video for a portion we are replacing.
  # Uses $LEFT and $RITE, merging with "audio.ts", from prior "replacement-audio" step to OUTNAME.ts
  SEEK=${1:?   "Usage: $0 [seconds into 1977 film] [number of frames to grab] [output file basename]"}
  FRAMES=${2:? "Usage: $0 [seconds into 1977 film] [number of frames to grab] [output file basename]"}
  OUTNAME=${3:?"Usage: $0 [seconds into 1977 film] [number of frames to grab] [output file basename]"}

  # NOTE: using quick seek (deliberately) here since we have listed where keyframes are in $OVID
  ffmpeg -y -ss $SEEK -i $OVID  -frames $FRAMES  -an -c:v copy  video.ts;

  vpackets video.ts |tail -1 |egrep '=K_*$';
  if [ "$?" != "0" ]; then echo; echo "FATAL video.ts didnt end in keyframe"; return; fi

  # merge A/V
  # NOTE: use -shortest to drop longer audio/video
  ffmpeg -y -i video.ts -i audio.ts -c copy -shortest $OUTNAME.ts;

  test-seam $LEFT $RITE $OUTNAME;

  # cleanup
  #rm -rf blu.ts audio.ts video.ts pre.ts post.ts seam/; #xxx
}


function patrol-dewbacks(){
  replacement-audio   0.15.25.2.ts   0.15.44.8.ts; #20.5s
  replacement-video  951.758  507  $0;
}

function patrol-dewbacks-orig-video-has-issues-not-used(){

  LEFT=0.15.00.7.ts;
  RITE=0.15.39.6.ts;
  cat $( clips $LEFT        0.15.09.3.ts ) >| a.ts;
  cat $( clips 0.15.33.6.ts $RITE        ) >| b.ts;

  ffmpeg -y -i a.ts  -g 1 -q:v 0 -c:a copy -g 1 a2.ts;
  ffmpeg -y -i b.ts  -g 1 -q:v 0 -c:a copy -g 1 b2.ts;

  seam  a2.ts  b2.ts
  ( echo file 'a2.ts'; echo file 'b2.ts' ) >| concat.txt;

  # this is the most tool-friendly (mplayer, melt, QuickTime) version
  ffmpeg -y -f concat -i concat.txt -codec copy -fflags +genpts -async 1  $0.ts;

  test-seam $LEFT  $RITE  $0; # ... but still had problems here!

  rm a.ts b.ts a2.ts b2.ts concat.txt;
}


function eisley(){
  # keep part (just before; ends with) "mos eisley spaceport, you will never find..";
  # replacing (just after) from start of: speeder zips in from outskirts of mos eisley..
  #   all the way to..
  # cantina!  start of da funk!

  # Copy the bluray audio (which now has two extra CG shots in the middle removed) for this time range
  # We will break the audio into the three contiguous pieces (92.8s)
  # so we can re-seam them together with collapsed sequential PTS
  LEFT=0.42.49.1.ts; # (set for replacement-video below)
  RITE=0.44.52.3.ts; # (set for replacement-video below)
  cat $(clips $LEFT        0.42.54.1.ts) |ffmpeg -y -f mpegts -i - -vn -c:a copy a.ts;
  cat $(clips 0.43.20.5.ts 0.43.59.5.ts) |ffmpeg -y -f mpegts -i - -vn -c:a copy b.ts;
  cat $(clips 0.44.05.3.ts        $RITE) |ffmpeg -y -f mpegts -i - -vn -c:a copy c.ts;
  seam a.ts b.ts c.ts;
  ffmpeg -y -i seam.m2ts -c copy audio.ts;

  replacement-video  2587.725  2258  $0;

  rm a.ts b.ts c.ts seam.m2ts;
}

function kenobi-hut(){
  # NOTE: we need to go 1 bluray GOP backwards (than 0.32.34.6.ts) since the 1977 GOP spread is bigger
  # NOTE: go 1 bluray GOP extra (than 0.32.38.4.ts) to get A/V to seam better
  replacement-audio  0.32.33.6.ts  0.32.39.1.ts;

  # NOTE: we'll capture slightly MORE video than we want/will use to get (exactly) 7 keyframes and 6 GOP cleanly
  replacement-video  1973.779  140  $0;
}

function cantina-bagpiper(){
  # 1977 had a red-eyed "werewolf" growl directly at camera.
  # bluray repalced with a "bagpiper"-esque hookah pipe smoking CG character.
  replacement-audio  0.45.02.0.ts  0.45.04.8.ts;

  # NOTE: we'll capture slightly MORE video than we want/will use to get (exactly) 5 keyframes and 4 GOPs cleanly
  replacement-video  2690.495  93  $0;
}

function cantina-snaggletooth(){
  replacement-audio  0.46.15.3.ts  0.46.18.2.ts;

  # NOTE: we'll capture slightly LESS video than we will be replacing to get (exactly) 4 keyframes and 3 GOPs cleanly
  #       because o/w we have a rough seam/transition (and ~0.5s audio being removed ends up OK -- choices!)
  replacement-video  2764.027  70  $0;
}

function cantina-outside(){
  # CG lizards with disembarking troopers added when threepio says "I dont like the look of this" outside
  replacement-audio  0.47.35.2.ts  0.47.41.9.ts;

  # NOTE: capture slightly MORE video than will be replacing to get (exactly) 9 keyframes and 8 GOPs cleanly
  replacement-video  2844.023  185202  $0;
}

function stormtroopers-deadend(){
  # We cant have Han round corner chasing stormtroopers and run into a new CG + BG "digital painting" of an entire
  # galley of stormtroopers and such, now can we?
  # In '77 Han runs around corner, only to find the troopers hav hit a deadend and they need to fight their way out...
  replacement-audio  1.27.42.5.ts  1.27.43.5.ts; # 1.9s

  # this gets us 3 keyframes bookending 2 GOPs, from 1977 video
  replacement-video  5150.53   47  $0;
}

function falcon-arrives-yavin(){
  replacement-audio  1.38.08.2.ts  1.38.37.4.ts; #29.7s
  replacement-video  5776.453  715  $0;
}

function xwings-leaving-yavin(){
  replacement-audio  1.45.04.1.ts  1.45.08.8.ts; #5.2s

  replacement-video  6166.342  139  $0;
}

function xwings-rounding-yavin(){
  replacement-audio  1.45.22.1.ts  1.45.32.1.ts; #10.7s

  # get 12 keyframes / 11 GOPs
  replacement-video  6185.027  236  $0;
}

function dogfight0(){
  replacement-audio  1.46.21.6.ts  1.46.23.2.ts; # 2s
  replacement-video  6244.504  52  $0;
}

function dogfight1(){ # xxx there is a slight tower firing repeat here..
  replacement-audio  1.46.31.5.ts  1.46.32.3.ts; # 1.5s
  replacement-video  6253.346  47  $0;
}

function dogfight2(){
  replacement-audio  1.47.40.0.ts  1.47.41.1.ts; #1.9s
  replacement-video  6322.331  48  $0;
}

function dogfight3(){
  replacement-audio  1.48.18.8.ts  1.48.31.8.ts; #13.6s
  replacement-video  6361.329  307  $0; #12.8s
}

function dogfight4(){
  replacement-audio  1.49.08.9.ts  1.49.11.9.ts;
  replacement-video  6411.128  97  $0;
}


function options77(){
  HMS_OR_SEC=${1:?"Usage: $0 [HH:MM:SS or H:MM:SS or seconds]"}

  if [[ $HMS_OR_SEC =~ : ]]; then
    HMS=$HMS_OR_SEC;
    SEC=$(echo $HMS |php -R 'require_once(getenv("THISDIR")."/Video.inc"); echo Video::hms2sec($argn);');
  else
    SEC=$HMS_OR_SEC;
    HMS=$(echo $SEC |php -R 'require_once(getenv("THISDIR")."/Video.inc"); echo Video::hms($argn);');
  fi

  echo SEC=$SEC;
  echo HMS=$HMS;

  PTS=$(egrep 'K_*$' negative1.packets |fgrep -m1 pts_time=$SEC |cut -f5 -d'|' |cut -f2 -d=);

  # now show a bunch of options of durations and frame counts for keyframe-to-keyframe clipping
  fgrep -A1000 pts_time=$PTS negative1.packets |egrep -n 'K_*$' |cut -f1,5 -d'|' |tr : = |cut -f1,3 -d= |tr = ' '|phpR 'list($f,$sec)=explode(" ",$argn); if (!$start) $start=$sec; echo "frames=$f\tduration=".round($sec-$start,4)."\tstart=$sec\n";';
}
