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
# config D1 and D2 to scratch drives -- 2 is ideal (for i/o speed) but can also be the same
export D1=/Volumes/bff-bup/star
export D2=/Volumes/bff/star
export BLUR="$D1/star-wars-bluray.iso" # change to where your ripped .iso from your bluray disc lives (33GB)
export OVID="$D1/negative1-v1.6.iso"   # change to silver screen team negative1 Jun 2016 v1.6 sixth release (38GB)
#
export MD5_BLUR="bdd5495e48f6726ff25f72421f9976f2" # if you want to verify your files for 100% compatibility below
export MD5_OVID="f9556d51e8cd6647ac076d7b8284f896" # if you want to verify your files for 100% compatibility below

###################################################################################################################

# NOTE: PS3 plays this sample as file (1080p 5.1 AAC mp4) -- you can use similar to downmix 6.1 DTS to 5.1 AAC
#   ffmpeg -i FILM.ts -c:v copy -c:a libfaac -ac 6 -t 180  1080p-aac-5.1.mp4
#
# xxx may need to lead w/ a few bluray frames to avoid thinking dominant FPS is mkv?!
# xxx PS3: may need to always pull network cable *when watching mp4 or burned bluray* due to audio signature checking
#
# PS3: try small edited sample and verify as 5.1 AAC mp4.
# PS3: if use/try M2TS (AKA AVCHD) may have to downmix to 5.1 AC-3 <= 448kb/s
# PS3: may need CFR and not VFR  (DVD version played  Audio: ac3, 48000 Hz, 5.1(side), fltp, 448 kb/s)
# appleTV _should_ be able to do Dolby Digital 5.1 (AKA AC-3)...  but prolly _NOT_ at 24fps 8-(

export THISDIR=$(dirname "$0")
echo "SCRIPT DIR: $THISDIR"


function main(){
  # setup, extract GOPs (Groups Of Pictures) from bluray
  setup
  extract-BLUR
  extract-OVID

  # do the easiest stuff first -- move all GOPs we're tossing to a trash bin folder..
  cuts

  # now the fun / hard / interesting stuff -- scenes being replaced
  credits
  r2-entering-canyon
  patrol-dewbacks
  kenobi-hut
  eisley
  cantina-bagpiper
  cantina-snaggletooth
  cantina-outside
  greedo # able to just shorten the (edited) bluray GOP
  search-eisley
  jabba # some minor necessary rework around ends of removed GOPs
  stormtroopers-deadend
  falcon-arrives-yavin
  no-biggs
  xwings-leaving-yavin
  xwings-rounding-yavin
  dogfight0
  dogfight1
  dogfight2
  dogfight3
  dogfight4

  # now put it all back together into one single file
  assemble
}


###################################################################################################################
#  SETUP
###################################################################################################################

function setup(){
  # ASSUMPTIONS:
  #   mac (if not adjust to taste) -- that will include baseline terminal, zsh, php CLI and more..
  #   brew  (if not, https://brew.sh/ is great!)
  brew install ffmpeg # includes ffprobe

  # brew install mlt  # handy for editing, playback, and especially playing one frame at a time back/forth
  # brew install mpv  # mplayer fork for mac
}

function extract-BLUR(){
  DIR=/Volumes/CDROM/BDMV/STREAM/ # this is where "open" (next) will mount .iso to

  open $BLUR # mount .iso image
  sleep 10

  mkdir -p $D1/tmp
  cd       $D1/tmp

  # losslessly keep (just) the 6.1 DTS audio and video -- it comes in ~147sec first piece; then rest of film
  # (losslessly) split the official bluray film version into files -- one per GOP
  # Split/segment to a supersmall duration -- but in reality will default to never cutting up a GOP.
  # So, will start each segment with a keyframe, and have 1 keyframe and 1 GOP per segment (output file).
  cat  $DIR/00300.m2ts  $DIR/00301.m2ts | ffmpeg -f mpegts -i - -f hls -c copy -hls_time 0.1 -map 0:0 -map 0:1 -hls_segment_filename '%04d.ts' out.m3u8

  rename-clips-to-timecodes
}

function extract-OVID(){
  DIR=/Volumes/Star_Wars_SSE_TN1_v1_6/BDMV/STREAM/ # this is where "open" (next) will mount .iso to

  open $OVID # mount .iso image
  sleep 10

  mkdir -p $D1/tmp/o
  cd       $D1/tmp/o

  # NOTE: losslessly concat-ing the two main pieces into single stream fed into segmenter
  # (losslessly video; recode audio -- audio wont be used in final product)) split the film into files -- one per GOP
  # Split/segment to a supersmall duration -- but in reality will default to never cutting up a GOP.
  # So, will start each segment with a keyframe, and have 1 keyframe and 1 GOP per segment (output file).
  cat  $DIR/00000.m2ts $DIR/00004.m2ts | ffmpeg -f mpegts -i - -f hls -c copy -hls_time 0.1 -map 0:0 -map 0:1 -hls_segment_filename '%04d.ts' -c:a ac3 out.m3u8;

  rename-clips-to-timecodes

  cd -
}

function rename-clips-to-timecodes(){
  # Convert each segment to seconds into the film for easier editing/grokking
  # Extract PTS of (1st/only) keyframe from sources, eg: "13.092351"
  # First, make like "0013.1" (round, 1 decimal, 0-padded 4 digits lead).
  # Then transform to like "0.50.56.2.ts"   (which is like timecode:  00:50:56.2  )
  # This also keeps the filename sortable.
    php -- "$@" <<\
"EOF"
<?require_once(getenv("THISDIR")."/Video.inc");

  echo "Renaming files: ";
  foreach (glob("????.ts") as $fi){
    $PTS = `printf '%06.1f' $(ffprobe -v 0 -hide_banner -select_streams v -show_packets -print_format compact $fi 2>/dev/null |egrep -m1 'flags=K_*$'|cut -d'|' -f5|cut -f2 -d=)`;
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
\ # <-- lame, but makes VSCode parsing/colors happy


###################################################################################################################
#  UTILITY METHODS
###################################################################################################################


# handy for testing:
function mp(){ /Applications/MPlayerX.app/Contents/MacOS/MPlayerX -framedrop hard "$@" 2>&1 |fgrep -v 'Fallingback to pbuffer. FBO status is' | perl -ne '$|=1; next unless m/\S/; print' |uniq; }

function line () {perl -e 'print "_"x80; print "\n\n";'; }

function packets(){
  ffprobe -v 0 -hide_banner -select_streams $PTYPE -show_packets -print_format compact "$@"
  # other specific-entries options:
  # ffprobe -hide_banner  -select_streams v -show_frames -print_format compact  -show_entries 'frame=pkt_pts_time,pkt_pts,pkt_dts_time,pkt_dts,pict_type,key_frame'
}
function vpackets(){ PTYPE=v; packets "$@"; }
function apackets(){ PTYPE=a; packets "$@"; }

function pts(){
  line; ffmpeg -i "$1" 2>&1 |egrep 'Duration:|start:'
  line; vpackets "$1" 2>/dev/null|head -2|cut -f5 -d'|'
  line; apackets "$1" 2>/dev/null|head -2|cut -f5 -d'|'
}


function clips(){
  set +x
  local LEFT=${1:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}
  local RITE=${2:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}

  LEFT=$(echo "$LEFT" |perl -pe 's/\.ts$//')
  RITE=$(echo "$RITE" |perl -pe 's/\.ts$//')

  if [[ $RITE =~ \\. ]]; then
    # return the filenames in the wanted time range
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts |fgrep -B10000 $RITE.ts
  elif [[ $RITE =~ \\- ]]; then
    # eg "-10" which means return (up to) 10 clips -- the 9 clips before $LEFT and $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -B100000 $LEFT.ts |tail $RITE
  else
    # eg "10" which means return (up to) 10 clips -- $LEFT and the 9 clips after $LEFT
    /bin/ls ?.??.??.?.ts |fgrep -A100000 $LEFT.ts |head -$RITE
  fi
}

function oclips(){
  set +x
  local LEFT=${1:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}
  local RITE=${2:?"Usage: clips [start .ts clip] [end .ts clip OR -[INT] OR [INT]]  Returns range of clips (inclusive) between them"}

  LEFT=$(echo "$LEFT" |perl -pe 's/\.ts$//')
  RITE=$(echo "$RITE" |perl -pe 's/\.ts$//')

  if [[ $RITE =~ \\. ]]; then
    # return the filenames in the wanted time range
    /bin/ls o/?.??.??.?.ts |fgrep -A100000 o/$LEFT.ts |fgrep -B10000 o/$RITE.ts
  elif [[ $RITE =~ \\- ]]; then
    # eg "-10" which means return (up to) 10 clips -- the 9 clips before $LEFT and $LEFT
    /bin/ls o/?.??.??.?.ts |fgrep -B100000 o/$LEFT.ts |tail  $RITE
  else
    # eg "10" which means return (up to) 10 clips -- $LEFT and the 9 clips after $LEFT
    /bin/ls o/?.??.??.?.ts |fgrep -A100000 o/$LEFT.ts |head -$RITE
  fi
}

function seamTS(){
  # takes a list of clips and rebases each clip's timestamps with a lossless "concat" operation
  rm -rf   seam/
  mkdir -p seam
  touch seam/concat.txt
  for i in "$@"; do
    if [ -s $i ]; then
      ln -s ../$i seam/$i
      echo "file '$i'" >> seam/concat.txt
    fi
  done
  cat seam/concat.txt
  ffmpeg -y -f concat -i seam/concat.txt -codec copy -f mpegts -fflags +genpts -async 1 seam.ts
}

function test-seam(){
  # helps verify that results of "seamTS" will allow a decent replacment into the rest of the film
  local LEFT=${1:?   "Usage: $0 [first clip to precede] [last clip to follow] [output name]"}
  local RITE=${2:?   "Usage: $0 [first clip to precede] [last clip to follow] [output name]"}
  local OUTNAME=${3:?"Usage: $0 [first clip to precede] [last clip to follow] [output name]"}

  # now test it fully seamed in, with 10 clips (~9s) before and after
  # (cat nothing as final arg, in case there are no clips that match (eg: credits has nothing prior, etc.))
  cat $(clips $LEFT -10 |fgrep -v $LEFT) /dev/null >| pre.ts
  cat $(clips $RITE  15 |fgrep -v $RITE) /dev/null >| post.ts
  seamTS  pre.ts  $OUTNAME.ts  post.ts
  mv seam.ts $OUTNAME-seamed.ts
}

function track-replacements(){
  # keeps track of this range of clips that will be omitted from the final film (later)
  local LEFT=${1:? "Usage: $0 [first clip to track] [last clip to track] [label]"}
  local RITE=${2:? "Usage: $0 [first clip to track] [last clip to track] [label]"}
  local LABEL=${3:?"Usage: $0 [first clip to track] [last clip to track] [label]"}

  touch                            $THISDIR/REPLACED.txt
  for TS in $(clips $LEFT $RITE); do
    echo "$TS $LABEL"  >>          $THISDIR/REPLACED.txt
  done
  sort $THISDIR/REPLACED.txt -u -o $THISDIR/REPLACED.txt
}

function replacement-audio(){
  # copies (just) the bluray audio, for the video portion we will be replacing, to audio.ts
  export LEFT=${1:? "Usage: $0 [first clip to replace] [last clip to replace] [label]"}
  export RITE=${2:? "Usage: $0 [first clip to replace] [last clip to replace] [label]"}
  export LABEL=${3:?"Usage: $0 [first clip to replace] [last clip to replace] [label]"}

  cat $( clips $LEFT $RITE ) >| blu.ts

  track-replacements $LEFT $RITE $LABEL

  # copy (just) the audio from the bluray for that time range:
  ffmpeg -y -i blu.ts -vn -c:a copy  audio.ts
}

function replacement-video(){
  # Copies (just)  the 1977 video for a portion we are replacing.
  # Uses $LEFT and $RITE, merging with "audio.ts", from prior "replacement-audio" step to OUTNAME.ts
  LEFTV=${1:?  "Usage: $0 [first clip to replace] [last clip to replace] [output file basename]"}
  RITEV=${2:?  "Usage: $0 [first clip to replace] [last clip to replace] [output file basename]"}
  OUTNAME=${3:?"Usage: $0 [first clip to replace] [last clip to replace] [output file basename]"}
  # To avoid "bloops" when doing REMOVE and REPLACE operations, could try keeping the REMOVED keyframe and merge into
  # the _prior_ GOP due to B-frames, etc.  eg:
  #   ffmpeg -i nix/0.15.10.3.ts  -c copy  -frames 1 -copyts -shortest  0.15.10.3.ts

  cat $( oclips $LEFTV $RITEV ) | ffmpeg -y -f mpegts -i -  -an -c:v copy  video.ts

  # merge A/V
  # NOTE: use -shortest to drop longer audio/video
  ffmpeg -y -i video.ts -i audio.ts -c copy -shortest $OUTNAME.ts

  test-seam $LEFT $RITE $OUTNAME

  # cleanup
  rm -rf blu.ts audio.ts video.ts pre.ts post.ts seam/
}



###################################################################################################################
#  LETS (RE)MAKE A FILM!
###################################################################################################################


# move away groups of clips that are being wholesale removed
function cuts(){
  # inclusive ranges
cat >| /tmp/.in <<EOF
  0.15.10.3   0.15.24.2   # patrol dewbacks1
  0.15.45.8   0.15.51.3   # patrol dewbacks2
  0.42.55.0   0.43.15.4   # entering mos eisley
  0.44.00.3   0.44.04.9   # entering mos eisley2
  0.43.16.4   0.43.20.0   # entering mos eisley3 audio excess
  0.52.41.7   0.54.13.3   # jabba
  0.55.37.5   0.55.40.3   # falcon takeoff mos eisley
  1.43.15.3   1.43.45.2   # biggs
EOF
  if [ ! -f out.m3u8 ]; then echo "FATAL: WRONG SUBDIR?"; return; fi
  mkdir -p nix
  for i in $(cat /tmp/.in | tr ' ' '_'); do
    FROM=$(echo "$i" |tr -s '_' ' ' |cut -f2  -d' ')
      TO=$(echo "$i" |tr -s '_' ' ' |cut -f3  -d' ')
    SLUG=$(echo "$i" |tr -s '_' ' ' |cut -f4- -d' ' |tr -d '#' |tr ' ' - |perl -pe 's/^\-*//')

    set -x
    mkdir -p nix/$SLUG
    mv $(clips  $FROM.ts  $TO.ts) nix/$SLUG/
    set +x
  done
  rm /tmp/.in
}


function credits(){ # xxx imperfect for now..
  # ideal -but- busted
  #replacement-audio  0.00.01.4.ts  0.01.54.7.ts  $0
  #replacement-video  0.00.01.4.ts  0.01.54.3.ts  $0

  # works, but cuts v early
  replacement-audio  0.00.01.4.ts  0.01.52.0.ts  $0
  replacement-video  0.00.01.4.ts  0.01.52.3.ts  $0
}

function r2-entering-canyon(){
  replacement-audio  0.11.20.6.ts  0.11.26.6.ts  $0  #6.7s
  replacement-video  0.11.20.8.ts  0.11.25.7.ts  $0
}

function patrol-dewbacks(){
  replacement-audio  0.15.25.2.ts  0.15.44.8.ts  $0 #20.5s
  replacement-video  0.15.10.5.ts  0.15.30.3.ts  $0
}

function kenobi-hut(){
  replacement-audio  0.32.34.6.ts  0.32.38.4.ts  $0
  replacement-video  0.32.14.1.ts  0.32.17.9.ts  $0
}

function eisley(){
  # keep part (just before; ends with) "mos eisley spaceport, you will never find..";
  # replacing (just after) from start of: speeder zips in from outskirts of mos eisley..
  #   all the way to..
  # cantina!  start of da funk!

  # Copy the bluray audio (which now has two extra CG shots in the middle removed) for this time range
  # We will break the audio into the three contiguous pieces (92.8s)
  # so we can re-seam them together with collapsed sequential PTS
  replacement-audio  0.42.49.1.ts  0.42.54.1.ts  $0;   mv  audio.ts  a.ts;  LEFTSAVE=$LEFT #(save for replacement-video)
  replacement-audio  0.43.20.5.ts  0.43.59.5.ts  $0;   mv  audio.ts  b.ts
  replacement-audio  0.44.05.3.ts  0.44.52.3.ts  $0;   mv  audio.ts  c.ts

  seamTS  a.ts b.ts c.ts
  mv  seam.ts  audio.ts

  export LEFT=$LEFTSAVE # this allows seam preview to be made with correct preceding clips
  replacement-video  0.42.27.7.ts  0.44.00.2.ts  $0

  rm a.ts b.ts c.ts
}

function cantina-bagpiper(){
  # 1977 had a red-eyed "werewolf" growl directly at camera.
  # bluray repalced with a "bagpiper"-esque hookah pipe smoking CG character.
  replacement-audio  0.45.02.0.ts  0.45.04.8.ts  $0
  replacement-video  0.44.10.0.ts  0.44.12.0.ts  $0
}

function cantina-snaggletooth(){
  # NOTE: we'll capture slightly LESS video than we will be replacing to get (exactly) 4 keyframes and 3 GOPs cleanly
  #       because o/w we have a rough seam/transition (and ~0.5s audio being removed ends up OK -- choices!)
  replacement-audio  0.46.15.3.ts  0.46.18.2.ts  $0
  replacement-video  0.45.23.3.ts  0.45.26.1.ts  $0
}

function cantina-outside(){
  # CG lizards with disembarking troopers added when threepio says "I dont like the look of this" outside
  # NOTE: cut slightly early with a slight jump (pre-outside scene) due to very picky open GOPs..
  replacement-audio  0.47.33.2.ts  0.47.41.9.ts  $0
  replacement-video  0.46.42.7.ts  0.46.49.6.ts  $0
}


function greedo(){
  # clip of controversy -- SPOILER ALERT -- we never see shots in 1977 at all!
  LEFT=0.50.54.7.ts
  RITE=0.50.55.5.ts # **VERY** weird -- next clip PTS are *before* TRIM for the most part -- so "seam" it special-ly

  if [ ! -e $LEFT.ORIG ]; then
    # only do this step once -- not rerunnable (without manually reversing ;-)
    cp  $LEFT  $LEFT.ORIG
  fi

  # keep just the first 11 frames of this (the original part of the GOP)
  ffmpeg -y -i  $LEFT.ORIG -c copy -copyts -vframes 11 $LEFT

  # we have to VERY carefully re-splice these two (adjacent) clips back together, rebasing timestamps
  seamTS  $LEFT  $RITE
  mv  seam.ts  $0.ts

  track-replacements  $LEFT  $RITE  $0

  test-seam $LEFT  $RITE  $0
}


function search-eisley(){
  # there's an added annoying CG flying droid "helping" the troopers search.  we shall swat it.
  replacement-audio  0.51.47.7.ts  0.51.58.8.ts  $0 # 1 more GOP than ideal (open GOP issues; v. slight artifact now)
  replacement-video  0.50.55.7.ts  0.51.05.7.ts  $0
}



function jabba(){
  # "These are not the bounty hunters you are looking for."
  #
  # The GOPs are being _very_ stubborn around the range I want to remove.  Hello "open GOP" bluray (facepalm)
  # http://www.chaneru.com/Roku/HLS/X264_Settings.htm#open-gop
  # So with my current techniques, I need to retain 1 full GOP I dont want, and (just) the keyframe of another GOP
  # we _really_ dont want...
  # That means there's going to be a slightly awkward pair of (partial) scene transitions:
  #    black circle closing in around black "spy vs. spy" guy (turns in to slimey worm...)
  #    slidding door wipe right-to-left from jabba scene to ben/luke in eisley corridor
  #    (and by the way, 1977 was a single dissolve transition -- they "scribbled over" the bluray adding those!)
  # Could live with that (given the Lossless Guiding Principles of the project)
  # but the _biggest_ problem is your eye can clearly catch Boba Fett in that second GOP after 2nd transition, ugh!
  # (though he looks badass / awesome, _no doubt_, sorry he wasn't even created/around in 1977 at all...)
  # So we'll chop the "FETT" GOP down to just 1 keyframe..
  # Here's our 3 act play and GOPs:
  LEFT=0.52.41.1.ts # jabba tail _just_ barely visible in last 2 frames -- acceptable
  FETT=0.54.13.8.ts # fett _clearly_ visible, dead center of screen, first 1/3 GOP -- unacceptable
  RITE=0.54.14.9.ts # no fett visible

  # Well this stinks, but copy (just) the keyframe from the FETT GOP
  # since the LEFT and RITE clips get _very_ unhappy without it.
  # And, while they're not 100% _happy_  and perfect _with_ it
  # (it's _not_ the correct GOP for LEFT to be borrowing open-gop B-frame info from!)
  # the 1-frame of boba is nearly imperceptible _and_ the movie export won't sputter and cough blood/errors up...
  #
  # "You can go about your business.  Move along."
  ffmpeg -y -i  $FETT  -c copy -vframes 1  1.ts

  seamTS  $LEFT  1.ts  $RITE
  mv  seam.ts  $0.ts

  test-seam   $LEFT  $RITE  $0

  track-replacements  $LEFT  $RITE  $0

  rm -f 1.ts
  return  # remaining not done but left as was 2nd best solution


  # Alternate solution?  "scribble on the film" (sigh, like they did) and draw fully 10 black frames over Boba Fett,
  # which also makes the awkward "two transitions" less visible/obvious, too.
  # (However, abandoned this after preceding and following GOPS to _these_ GOPS weren't 100% happy w/ the GOP change!
  LEFT=0.52.41.1.ts # tip of jabba CG tail is _just barely_ visible in last 3 frames here (but at 24fps cant see)
  RITE=0.54.13.8.ts # boba fett is _clearly visible_ for 8 frames here -- we need to disappear!

  seamTS $LEFT $RITE
  convert -size 1920x1080  xc:black black.png
  ffmpeg -y -i seam.ts -i black.png -copyts -q:v 0 -filter_complex "[0:v][1:v]overlay=enable='between(n,8,19)'[out]" -map "[out]" -map 0:a:0 -c:a:0 copy  $0.ts
}


function stormtroopers-deadend(){
  # We cant have Han round corner chasing stormtroopers and run into a new CG + BG "digital painting" of an entire
  # galley of stormtroopers and such, now can we?
  # In '77 Han runs around corner, only to find the troopers hav hit a deadend and they need to fight their way out...
  replacement-audio  1.27.42.5.ts  1.27.43.5.ts  $0 # 1.9s
  replacement-video  1.25.13.3.ts  1.25.14.4.ts  $0
}

function falcon-arrives-yavin(){
  replacement-audio  1.38.08.2.ts  1.38.37.4.ts  $0 #29.7s
  replacement-video  1.35.39.1.ts  1.36.08.2.ts  $0
}

function no-biggs(){
  # When biggs' scene was removed, luke walks under an xwing [CUT] jumps to him starting up ladder to his own xwing
  # transition was too awkward for the live single take (with biggs scene removed in the middle) so they slid up
  # a (short) wide-angle hangar shot to separate the split scene.
  # Easier to explain with "pictures" of GOPs, represented as timeline here in named [GOP] boxes.
  # There are 31 previously deleted Biggs GOPs, we'll call them: NIX1 NIX2 .. NIX31.
  # So our film is like this:
  #  .. [LEFT] [HANGAR2] [HANGAR3] [RITE] [NIX1] [NIX2] .. [NIX31] ..
  # And what we are going to edit down to is:
  #  .. [RITE] [LEFT] [HANGAR2] [HANGAR3] ..

  # logical "HANGAR1"
  LEFT=1.43.11.3.ts

  # luke touching xwing underside.
  # 1977 film moved this out of sequence, from 2 GOPs ahead, to allow smoother biggs deletion
  RITE=1.43.14.3.ts
  # we dont need to name between LEFT and RITE -- but they are logical HANGAR2 and HANGAR3

  cat $(clips  $LEFT  $RITE |fgrep -v $RITE) >| hangar.ts # hangar. biggs clips removed after this range in "cuts()"

  # move the right most clip first, followed by first/other 3 clips
  seamTS  $RITE  hangar.ts
  mv  seam.ts  $0.ts
  test-seam  $LEFT  $RITE  $0

  track-replacements $LEFT $RITE  $0

  rm hangar.ts
}

function xwings-leaving-yavin(){
  replacement-audio  1.45.04.1.ts  1.45.08.8.ts  $0 #5.2s
  replacement-video  1.42.09.1.ts  1.42.13.9.ts  $0
}

function xwings-rounding-yavin(){
  replacement-audio  1.45.22.1.ts  1.45.32.1.ts  $0 #10.7s
  replacement-video  1.42.27.2.ts  1.42.37.4.ts  $0
}

function dogfight0(){
  replacement-audio  1.46.21.6.ts  1.46.23.2.ts  $0 # 2s
  # could go either way here -- pick former (scene cut slightly early) if grief! xxx
# replacement-video  1.43.27.7.ts  1.43.27.7.ts  $0
  replacement-video  1.43.26.8.ts  1.43.27.7.ts  $0
}

function dogfight1(){
  replacement-audio  1.46.31.5.ts  1.46.32.3.ts  $0 # 1.5s
  replacement-video  1.43.36.6.ts  1.43.37.4.ts  $0
}

function dogfight2(){
  replacement-audio  1.47.40.0.ts  1.47.41.1.ts  $0 #1.9s
  replacement-video  1.44.45.1.ts  1.44.46.1.ts  $0
}

function dogfight3(){
  replacement-audio  1.48.18.8.ts  1.48.31.1.ts  $0
  replacement-video  1.45.23.9.ts  1.45.35.3.ts  $0
}

function dogfight4(){
  replacement-audio  1.49.08.9.ts  1.49.11.9.ts  $0
  replacement-video  1.46.14.0.ts  1.46.17.0.ts  $0
}

function NOT-USED-patrol-dewbacks-using-bluray-video(){ # had issues

  LEFT=0.15.00.7.ts
  RITE=0.15.39.6.ts
  cat $( clips $LEFT        0.15.09.3.ts ) >| a.ts
  cat $( clips 0.15.33.6.ts $RITE        ) >| b.ts

  ffmpeg -y -i a.ts  -g 1 -q:v 0 -c:a copy -g 1 a2.ts
  ffmpeg -y -i b.ts  -g 1 -q:v 0 -c:a copy -g 1 b2.ts

  ( echo file 'a2.ts'; echo file 'b2.ts' ) >| concat.txt

  # this is the most tool-friendly (mplayer, melt, QuickTime) version
  ffmpeg -y -f concat -i concat.txt -codec copy -fflags +genpts -async 1  $0.ts

  test-seam $LEFT  $RITE  $0 # ... but still had problems here!

  rm a.ts b.ts a2.ts b2.ts concat.txt
}


###################################################################################################################
#  "WALK IN A SINGLE FILE" -- ASSEMBLE THE PIECES BACK TO 1 FILE!
###################################################################################################################

function assemble(){
  mkdir -p $D2/tmp

  php -- "$@" <<\
"EOF"
<?define('DEBUG',0);
  # get list of all clips that were 100% tossed out
  $NIXED=[];
  foreach(explode("\n", trim(`find nix -type f`)) as $file){
    list(, $slug, $file) = explode('/', $file);
    $NIXED[$file] = "NIXED: $slug";
  }

  # get list of all clips that have been replaced with 1977 video
  $FIXED=[];
  foreach (file(getenv('THISDIR').'/REPLACED.txt',FILE_IGNORE_NEW_LINES|FILE_SKIP_EMPTY_LINES) as $line){
    list($k,$v) = explode(' ', $line);
    $FIXED[$k] = "FIXED: $v";
  }

  # get current list of clips
  $FILES = array_flip(glob("?.??.??.?.ts"));
  $FILES[key($FILES)]=1; # so dont have to use isset() later

  # complete unified list
  $CLIPS = array_merge($NIXED, $FIXED, $FILES);

  ksort($NIXED);
  ksort($FIXED);
  ksort($FILES);
  ksort($CLIPS);

  # do some basic checking
  $tmp = array_intersect_key($NIXED, $FILES);
  if (count($tmp)){ print_r($tmp); die('uho -- some clips in "nix" subdir are in main dir'); }
  $tmp = array_intersect_key($FILES, $NIXED);
  if (count($tmp)){ print_r($tmp); die('uho -- some clips in "nix" subdir are in main dir'); }
  $tmp = array_intersect_key($FIXED, $FILES);
  if (count($tmp) != count($FIXED)){ print_r($tmp); die('uho -- some replaced clips are missing from main dir'); }
  $tmp = array_intersect_key($FILES, $FIXED);
  if (count($tmp) != count($FIXED)){ print_r($tmp); die('uho -- some replaced clips are missing from main dir'); }

  if (DEBUG){
    # sample info
    print_r(array_slice($NIXED, 0, 10));
    print_r(array_slice($FIXED, 0, 10));
    print_r(array_slice($FILES, 0, 10));
    print_r(array_slice($CLIPS, 0, 10));
  }

  # assign a state to every clip (that the movie was initially split into)
  foreach ($CLIPS as $ts => &$state){
    if      (@$NIXED[$ts]) $state = $NIXED[$ts];
    else if (@$FIXED[$ts]) $state = $FIXED[$ts];
    else                   $state = '';
  }
  unset($state);

  if (DEBUG) print_r($CLIPS);

  # group adjacent state ranges of clips together
  $groups = [];
  $clips = '';
  $prev = '';
  foreach ($CLIPS as $ts => $state){
    if ($state==$prev){
      $clips .= " $ts";
    }
    else {
      if ($clips)
        $groups[] = [$clips, $prev];
      $clips = $ts;
    }
    $prev = $state;
  }
  if ($clips) # _should_ always be the case..
    $groups[] = [$clips, $prev];


  # "You may _fire_ when ready"
  #
  # now concat/copy adjacent "clean" clips to new (sometimes monster big) files
  # so we can do a final single "concat" with the clean clips and replaced clips
  # (and blow up this place and all go home)
  $EDL = ltrim("
###############################################################################################
# Edit Decision List -- when all is said and done, this is what we've done from run.sh script:
###############################################################################################
");
  $seams = [];
  foreach ($groups as $group){
    list($clips, $state) = $group;
    $clips = trim($clips);
    $left = strtok($clips, " ");
    $rite = strrev(strtok(strrev($clips), " "));
    $EDL .= "[ $left .. $rite ]\t$state\n";

    if (strpos($state, 'NIXED: ')!==FALSE)
      continue; // throwing out

    if (preg_match('/FIXED: (.*)/', $state, $mat)){
      $file = "{$mat[1]}.ts";
      # concat only allows local-qualified filenames so copy the ready-to-go replacement video over there
      $cmd = "rsync -Pav $file " . getenv('D2')."/tmp/$file";
      echo "$cmd\n";
      passthru($cmd);
      if (end($seams) !== $file) # avoids "eisley" showing up 3x in a row (due to two deleted clips in between!)
        $seams[] = $file;
      continue;
    }

    if ($state!=='')
      die("bad state $state");

    $file = getenv('D2')."/tmp/$left--$rite";
    if (!file_exists($file)){
      $cmd = "cat $clips > $file...  &&  mv $file... $file";
      echo "$cmd\n";
      flush();
      `$cmd`;
    }
    $seams[] = basename($file);
  }
  file_put_contents(getenv("THISDIR")."/CONCATS.txt", "file '" . join("'\nfile '", $seams)."'\n");
  file_put_contents(getenv("THISDIR")."/EDL.txt", $EDL);
EOF
\ # <-- lame, but makes VSCode parsing/colors happy


  # NOW CONCAT EVERYTHING TOGETHER!
  cd $D2/tmp/
  cp $THISDIR/CONCATS.txt .
  ffmpeg -f concat -i CONCATS.txt -codec copy -f mpegts -fflags +genpts -async 1 $D1/tmp/FILM.ts
  cd -

  echo; echo; echo; echo; echo
  echo "EDITED MOVIE IS NOW AT: $D1/tmp/FILM.ts"
  echo; echo; echo; echo; echo
}

if [ "$#" = 0 ]; then
  main
fi
