<?
class Video
{

  // given a duration (in seconds), return something like "HH:MM:SS", eg:
  //  01:12:27    (for 1 hr, 12 minutes, 27 seconds)
  public static function hms($seconds, $omit00hr=false, $tenthSecond=false)
  {
    $hr = floor($seconds/3600);
    $min= floor(($seconds - ($hr*3600))/60);
    $sec= $seconds - ($hr*3600) - ($min*60);
    $secfmt = ($tenthSecond ? "%04.1f" : "%02d");
    if ($omit00hr  &&  $hr==0)
      return sprintf("%02d:$secfmt", $min, $sec);
    return sprintf("%02d:%02d:$secfmt", $hr, $min, $sec);
  }


  public static function hms2sec($hms, $fractional=false)
  {
    if ($fractional && preg_match('/^(\d+):(\d+):([\d+\.]+),(\d+)$/',$hms,$m)) //eg: "01:13:01,939"
      return $m[1]*3600 + $m[2]*60 + $m[3] + floatval(".{$m[4]}");
    else if (preg_match('/^(\d+):(\d+):([\d+\.]+)$/', $hms, $m)) //eg: "01:13:01"
      return $m[1]*3600 + $m[2]*60 + $m[3];
    else if (preg_match('/^(\d+):([\d+\.]+)$/', $hms, $m)) //eg: "13:01"
      return $m[1]*60 + $m[2];
    else if (preg_match('/^([\d+\.]+)$/', $hms, $m)) //eg: "01"
      return intval($m[1]);
    else
      return false;
  }


  public static function sec2ms($seconds)
  {
    $runtime = '';
    if ($seconds > 60){
      $runtime .= ' '.floor($seconds / 60).' minutes';
      $seconds = fmod($seconds, 60);
    }
    if ($seconds)
      $runtime .= ' '.round($seconds).' seconds';
    return trim($runtime);
  }



  private static function tofloat($rate)
  {
    if (intval($rate)==0)
      return 0;
    if (preg_match('=^([\d\.]+)/([\d\.]+)$=', $rate, $m))
      return round($m[1] / $m[2],2);
    return 0;
  }
}
