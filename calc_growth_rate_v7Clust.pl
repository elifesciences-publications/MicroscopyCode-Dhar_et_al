#!/usr/bin/perl -w


## Copyright 2018 Riddhiman Dhar BSD-3-Clause
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
## 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



## ------------------------------------------
## GOAL: CALCULATE MICROCOLONY GROWTH RATE
## ------------------------------------------

($sec,$min,$hr)=gmtime;
print "$hr:$min:$sec\n";

use lib "/users/blehner/rdhar/perl5/lib/perl5/";


## -------------------------------------------------------
## Reading PARAMETERS-*.txt file and initialize parameters
## -------------------------------------------------------

@arg=@ARGV;

$no=@arg;

$pfile="X";
$batchtime="X";
for($i=0;$i<$no;$i++)
{
  if($arg[$i] eq "-pfile") { $pfile=$arg[$i+1]; next; }
  if($arg[$i] eq "-time") { $batchtime=$arg[$i+1]; next; }
}

undef $no;

if($pfile eq "" || $pfile eq "X")
{
   print "ERROR! Give a parameter file for the program!\n";
   print "Usage: perl calc_growth_rate_v2Clust.pl -pfile <FILENAME> -time <SGE_BATCH_ID>.\n";
   exit();
}
if($batchtime eq "" || $batchtime eq "X")
{
   print "ERROR! Need a batch ID for the program!\n";
   print "Usage: perl calc_growth_rate_v2Clust.pl -pfile <FILENAME> -time <SGE_BATCH_ID>.\n";
   exit();
}
undef(@arg);

$initcolsizelim=50;
$tottime=0;
$fractinc=0;
$interval=0;
$coldeclim=0;
$dirpath="";
$magnific="X";
$alnlowlim=-50;
$alnuplim=50;
$CENTDIST=8;

open(PA,$pfile) or die;
while($pa=<PA>)
{
  chomp($pa);
  @prt=split(/\t+/,$pa);
  if($prt[0] eq "DATADIR") { $dirpath=$prt[1]; }
  if($prt[0] eq "NUMTIME") { $tottime=$prt[1]; }
  if($prt[0] eq "MAGNIFIC") { $magnific=$prt[1]; }
  if($prt[0] eq "OVERALLSIZEINCCUTOFF") { $fractinc=$prt[1]; }
  if($prt[0] eq "INDTIMESIZEINCCUTOFF") { $coldeclim=$prt[1]; }
  if($prt[0] eq "TIMEINTERVAL") { $interval=$prt[1]; }
  if($prt[0] eq "INITCOLSIZELIM") { $initcolsizelim=$prt[1]; }
  if($prt[0] eq "ALIGNVALLOWLIMIT") { $alnlowlim=$prt[1]; }
  if($prt[0] eq "ALIGNVALUPLIMIT") { $alnuplim=$prt[1]; }
  if($prt[0] eq "CENTDISTCUTOFF") { $CENTDIST=$prt[1]; }
  undef(@prt);
}
close(PA);

if($tottime==0) { print "ERROR! Number of time points can not be zero!\n"; exit(); }
if($interval==0) { print "ERROR! Interval between time points can not be zero!\n"; exit(); }
if($magnific eq "X") { print "ERROR! Specify an appropriate value for magnification!\n"; exit(); }

$finalcolsizelim=$initcolsizelim+$initcolsizelim*$fractinc;
$mintime=sprintf("%0.0f",180/$interval)+1;
@qw=split(/\//,$dirpath);
$inppath="../INPUT/INPUT_$qw[5]";
$outputpath="../OUTPUT/OUTPUT_$qw[5]";
$intervalpath="../TIME_INTERVAL/INTERVAL_$qw[5].txt";
undef(@qw);

$centinctime=180/$interval+4;


use GD;
$sizecut=$initcolsizelim;

$width=1392; #696; #1392
$height=1040; #520; #1040
if($magnific eq "10X")
{
  $neimindist=100;
  $movedist=5;
  $cutfrac=0.1;
  $centincfrac=0.1;
  $areacutoff=6000;
}
if($magnific eq "20X")
{
  $width=1392; 
  $height=1040;
  $neimindist=200;
  $movedist=10;
  $cutfrac=0.1;
  $centincfrac=0.2;
  $areacutoff=12000;
}
if($magnific eq "60X")
{
  $width=1392; 
  $height=1040;
  $neimindist=2000;
  $movedist=100;
  $cutfrac=0.3;
  $centincfrac=0.5;
  $areacutoff=50000;
}

$randflag=1; 
$gname="GRTHLIST_".$pfile."_$batchtime";
system "ls $inppath/$batchtime/ > $gname";

open(ER,$gname) or die;
while($er=<ER>)
{
chomp($er);
if($er=~/\.TIF/) { next; }
if($er=~/\_w2\.png/|| $er=~/\_w3\.png/) { next; }
#if($er!~/_s1_/ ) { next; }
@mco=split(/\./,$er);
@lco=split(/\_/,$mco[0]);
undef(@mco);
$no=@lco;
$basewrname="GROWTH_$lco[0]_$lco[1]_T";
$wrinic="$lco[0]_$lco[1]";
$baseimagefile=$lco[0]."_$lco[1]_T";

if(exists $dup{$wrinic}) { next; }

print "$wrinic\n";
$dup{$wrinic}=1;

$bsttime=$tottime;
$timeflag=0;
$prevtot=0;

$dir=$batchtime;

for($tcnt=1;$tcnt<=$tottime;$tcnt++)
{
  $wrname=$basewrname;
  $imagefile=$baseimagefile;
  if($tcnt<10) { $wrname.="0".$tcnt; }
  else { $wrname.=$tcnt; }

  if($tcnt<10) { $imagefile.="0".$tcnt; }
  else { $imagefile.=$tcnt; }
 
  if($no==3) { $imagefile.=".png"; }
  if($no==4) { $imagefile.="_$lco[3].png"; }
  

  $name[$tcnt]=$imagefile;

  if(!-e "$inppath/$dir/$imagefile") { $mem[$tcnt][0]=0; next; }

  $image=GD::Image->newFromPng("$inppath/$dir/$imagefile",0);
  $green = $image->colorAllocate(0,255,0);



## ---------------------------------------
##  Find Centroids and Mark them
## ---------------------------------------

  open(FP,"$outputpath/GROWTH_DATA/$dir/$wrname") or die;
  while($fp=<FP>)
  {
    chomp($fp);
    @arr=split(/\s+/,$fp);
    if(exists $list{$arr[2]})
    {
      $list{$arr[2]}[1]+=$arr[0];
      $list{$arr[2]}[2]+=$arr[1];
      if($arr[0]<2||$arr[0]>$width-3||$arr[1]<2||$arr[1]>$height-3) { $list{$arr[2]}[3]=1; }
      $list{$arr[2]}[0]++;
      #$image->setPixel($arr[0],$arr[1],$green);
    }
    else
    {
      $list{$arr[2]}[1]=$arr[0];
      $list{$arr[2]}[2]=$arr[1];
      $list{$arr[2]}[3]=0;
      if($arr[0]<2||$arr[0]>$width-3||$arr[1]<2||$arr[1]>$height-3) { $list{$arr[2]}[3]=1; }
      $list{$arr[2]}[0]=1;
      #$image->setPixel($arr[0],$arr[1],$green);
    } 
    undef(@arr);
  }
  close(FP);


  $ct=0;
  foreach $key (keys %list)
  {
    if($list{$key}[0]<$sizecut) { next; }
    $xc=sprintf("%0.0f",$list{$key}[1]/$list{$key}[0]);
    $yc=sprintf("%0.0f",$list{$key}[2]/$list{$key}[0]);
    #if($list{$key}[3]==1) { next; }

    $array[$tcnt][$xc][$yc][0]=$list{$key}[0];
    $array[$tcnt][$xc][$yc][1]=$list{$key}[3];
    $array[$tcnt][$xc][$yc][2]=0;
    $array[$tcnt][$xc][$yc][3]=0;

    $st1=$st2=$st3=$st4=20;
    if($xc<$st1) { $st1=$xc; }
    if($xc+$st2>$width-1) { $st2=$width-$xc-1; }
    if($yc<$st3) { $st3=$yc; }
    if($yc+$st4>$height-1) { $st4=$height-$yc-1; }

    for($i=$xc-$st1;$i<=$xc+$st2;$i++)
    {
      for($j=$yc-$st3;$j<=$yc+$st4;$j++)
      {
        if($i==$xc || $j==$yc) { next; }
        if(exists $array[$tcnt][$i][$j][0]) { next; } 
        $array[$tcnt][$i][$j][0]=0;
        $array[$tcnt][$i][$j][1]=0;
        $array[$tcnt][$i][$j][2]=0;
        $array[$tcnt][$i][$j][3]=0;
      } 
    }  
    $mem[$tcnt][1][$ct]=$xc;
    $mem[$tcnt][2][$ct]=$yc;
    $mem[$tcnt][3][$ct]=0;
    $ct++; 
  }
  $mem[$tcnt][0]=$ct;
  undef %list;
  
  if(!-e "$inppath/$dir/$name[$tcnt]") { next; } 

  $image=GD::Image->newFromPng("$inppath/$dir/$name[$tcnt]",0);
  $green = $image->colorAllocate(0,255,0);

  $tot=0;

  for($j=0;$j<$mem[$tcnt][0];$j++)
  {
    $x=$mem[$tcnt][1][$j];
    $y=$mem[$tcnt][2][$j];
    $flag=$array[$tcnt][$x][$y][1];

    if($flag==1) 
    {
      undef $x;
      undef $y;
      undef $flag;  
      next; 
    }

    if($tcnt==1)  { $first{length($x)."*$x"."*".length($y)."*$y"}=$array[$tcnt][$x][$y][0]; } 
    if($tcnt==2)  { $second{length($x)."*$x"."*".length($y)."*$y"}=1; } 
  
    if($array[$tcnt][$x][$y][0]>$initcolsizelim)
    {
      $tot++;
      $image->setPixel($x,$y,$green);
      $image->setPixel($x+1,$y+1,$green);
      $image->setPixel($x+1,$y,$green);
      $image->setPixel($x,$y+1,$green);
      $image->setPixel($x-1,$y-1,$green);
      $image->setPixel($x-1,$y,$green);
      $image->setPixel($x,$y-1,$green);
    }
    undef $x;
    undef $y;
    undef $flag;  
  }

  ##print "$tcnt: $tot $prevtot \n";
  if(($prevtot!=0) && ($bsttime==$tottime) && ($tot-$prevtot>0) && (($tot-$prevtot)/$prevtot>$centincfrac) && ($tcnt>$centinctime))
  ##if(($prevtot!=0) && ($bsttime==$tottime) && (abs(($tot-$prevtot)/$prevtot)>$centincfrac) && ($tcnt>$centinctime))
  {
    if($timeflag==0)
    {
      $timeflag=1; $tmflp=$tcnt;
      if($tcnt==$tottime) { $bsttime=$tcnt-2; $timeflag=2; }
    }
    elsif($timeflag==1)
    {
      $bsttime=$tcnt-2; $timeflag=2;
    }
  }

  if($timeflag==0)
  {
    if($prevtot==0 || abs($tot-$prevtot)/$prevtot<$centincfrac || $tcnt<=2) { $prevtot=$tot; }
    #$prevtot=$tot; 
  }

  $copy=$image->clone();

  $nrname=$name[$tcnt];
  open(NEW,">$outputpath/CENTROID_FILES/$dir/$nrname") || die;
  binmode NEW;
  print NEW $copy -> png;
  close NEW;

  #print "$tcnt $dir $wrname $imagefile\n";
  undef $wrname;
  undef $nrname;
  undef $imagefile;
}  
undef(@lco);

if($timeflag==1) { $bsttime=$tmflp-2; undef $tmflp; }

if(!-e "$outputpath/MARKED_PIXELS/$name[$bsttime]")
{
  for($mh=$bsttime;$mh>=1;$mh--)
  {
    if(-e "$outputpath/MARKED_PIXELS/$name[$mh]") { $bsttime=$mh; last; }
  }
}

undef $mh;

$iniccnt=0;
open(INIC,">$outputpath/INITIAL_CENTROIDS/$wrinic") || die;
foreach $key (keys %first)
{
  @er=split(/\*/,$key);
  if($first{$key}>$initcolsizelim) { print INIC "$er[1] $er[3]\n"; $iniccnt++; }
  undef(@er);
}
close(INIC);

undef $key;

## -------------------------------------------------------------------------
## Calculate movement of the stage  between first and second timepoints
## -------------------------------------------------------------------------
##rmsd calculation


$globmin=1000; $globminx=0; $globminy=0;
for($pr=$alnlowlim;$pr<=$alnuplim;$pr+=5)
{
for($qr=$alnlowlim;$qr<=$alnuplim;$qr+=5)
{
  $cn=0;
  $cnsumx=0; $cnsumy=0;
  foreach $key (sort keys %second)
  {
    @er=split(/\*/,$key);
    $min=1000; $minx=-1; $miny=-1; 

   foreach $newkey (sort keys %first)
   {
     @wr=split(/\*/,$newkey);
     #if(abs($er[1]-$wr[1]-$pr)+abs($er[3]-$wr[3]-$qr)<$min) { $min=abs($er[1]-$wr[1]-$pr)+abs($er[3]-$wr[3]-$qr); $minx=$wr[1]; $miny=$wr[3]; }
     $sedist=abs($er[1]-$wr[1]-$pr)+abs($er[3]-$wr[3]-$qr);
     if($sedist<$min) 
     { 
       $min=$sedist; $minx=$wr[1]; $miny=$wr[3]; 
     }
     undef(@wr);
   } 
   if($minx==-1 || $miny==-1) { next; }
 
   #print "$pr $qr || $er[1] $er[3] || $minx $miny || $min\n"; 
   if($min<10) 
   {
     $cnsumx+=abs($er[1]-$minx-$pr);
     $cnsumy+=abs($er[3]-$miny-$qr);
   }
   else
   {
     $pen=200;
     if($min>$pen) { $pen=$min; }
     $cnsumx+=$pen;
     $cnsumy+=$pen;
   } 
   $cn++;
   undef(@er);
 }
 if($cn!=0) 
 {
  $cnsumx/=$cn;
  $cnsumy/=$cn;
 }  
 
 $cnsum=$cnsumx+$cnsumy;

 if($cnsum<$globmin) { $globmin=$cnsum; $globminx=$pr; $globminy=$qr; } 
}
}

undef %first;
undef %second;

#print "$mintime $bsttime $globminx $globminy\n";
#exit();

## --------------------------------------------
## Find centroids of a micro-colony over time
## --------------------------------------------


print "Calculating growth rates...\n";

$grfile=$wrinic."_GROWTH_RATE.txt";

open(WR,">$outputpath/GROWTH_RATE/$grfile") or die;
for($i=1;$i<=$bsttime;$i++)
{
  for($j=0;$j<$mem[$i][0];$j++)
  {
   $x=$mem[$i][1][$j];
   $y=$mem[$i][2][$j];

   if($i!=1) 
   {
     $passi=$i-1;   ##
     $cord="-1*-1";
     while($cord eq "-1*-1" && $passi>=$i-4 && $passi>=1)
     #while($cord eq "-1*-1" && $passi>=0)
     {
       $adjx=0; $adjy=0;
       if($passi==1) { $adjx=$globminx; $adjy=$globminy; }
       $cord=findprevcentroid($x,$y,$passi,$i,$adjx,$adjy);
 
       if($cord ne "-1*-1")
       {
         @wr=split(/\*/,$cord);
         $inlocflag=0; ###
         if(($array[$i][$x][$y][0]-$array[$passi][$wr[0]][$wr[1]][0])>$coldeclim && $array[$i][$x][$y][0]>$initcolsizelim 
            && (($array[$i][$x][$y][0]-$array[$passi][$wr[0]][$wr[1]][0])/($array[$passi][$wr[0]][$wr[1]][0]*($i-$passi)*$interval/60))<=1.25) 
         { 
            $inlocflag=1; 
         } ### 
         #$ptp=(($array[$i][$x][$y][0]-$array[$passi][$wr[0]][$wr[1]][0])/($array[$passi][$wr[0]][$wr[1]][0]*($i-$passi)*$interval/60));
         # if($ptp>1) { print "$i $passi $x $y $array[$i][$x][$y][0] $array[$passi][$wr[0]][$wr[1]][0] $interval $ptp\n"; } 
       
   
         if($inlocflag==1) 
         {
           #if($array[$i][$x][$y][0]<$array[$passi][$wr[0]][$wr[1]][0]) { $array[$i][$x][$y][0]=$array[$passi][$wr[0]][$wr[1]][0]; }
           $array[$i][$x][$y][2]=$array[$passi][$wr[0]][$wr[1]][2];
           $mem[$i][3][$j]=$array[$passi][$wr[0]][$wr[1]][2];
           if($passi==$i-1) { $array[$passi][$wr[0]][$wr[1]][3]=1; }
	   last;
         } 
         undef(@wr);
       }
       $passi--;
     }  
     if($cord eq "-1*-1")
     {
       $mem[$i][3][$j]=$randflag;
       $array[$i][$x][$y][2]=$randflag;
       $randflag++;
     }
   }
   elsif($i==1)
   {
     $mem[$i][3][$j]=$randflag;
     $array[$i][$x][$y][2]=$randflag;
     $randflag++;
   }

   $flag1=$array[$i][$x][$y][1];
   $flag2=$array[$i][$x][$y][2];

   if($flag2!=0 && $flag1==0) 
   { 
     $id=length($flag2)."*$flag2*".length($i)."*$i";
    
     $colony{$id}[1]=$x;
     $colony{$id}[2]=$y;
     $colony{$id}[3]=$array[$i][$x][$y][0]; 
     undef $id;
   }
   #if($array[$i][$x][$y][2] <= 23 && $array[$i][$x][$y][2]!=0) { print "$i $x $y $array[$i][$x][$y][2] || $array[$i][$x][$y][0]\n"; } 
   undef $x;
   undef $y;
   undef $cord;
   undef $flag1;
   undef $flag2;
  }  
} 

foreach $key (sort keys %colony)
{
  @wr=split(/\*/,$key);

  $x=sprintf("%0.0f",$colony{$key}[1]);
  $y=sprintf("%0.0f",$colony{$key}[2]);
  $area=sprintf("%0.0f",$colony{$key}[3]);

  if($area>$areacutoff) { undef(@wr); next; }

  $id=length($wr[1])."*$wr[1]";
  $ut=$wr[3];
  if(exists $signal{$id})
  {
    if($ut<$signal{$id}[1]) { $signal{$id}[1]=$ut; }
    if($ut>$signal{$id}[2]) 
    { 
      $signal{$id}[2]=$ut; 
    }
  }
  else
  {
    $signal{$id}[1]=$ut;
    $signal{$id}[2]=$ut; 
  }

  $final{$id}[$ut][0]=$x;
  $final{$id}[$ut][1]=$y;
  $final{$id}[$ut][2]=$area;
  undef $id;
  undef $ut;
  undef $x;
  undef $y;
  undef $area;
  undef(@wr);
}  

undef %colony;

#$dir="TimePoint_".$bsttime;
if(!-e "$inppath/$dir/$name[$bsttime]") 
{  
   if(-e "$inppath/$dir/$name[$bsttime-1]")
   {
     $bsttime--;
   }
   else { $bsttime=1; }
}

$image=GD::Image->newFromPng("$inppath/$dir/$name[$bsttime]",0); ## $name[$mi-1]
$red= $image->colorAllocate(255,0,0);
$green= $image->colorAllocate(0,255,0);
undef $dir;


## ----------------------------------------------------------------
## Check if two neighboring colonies touch each other during growth
## ----------------------------------------------------------------


foreach $key (sort keys %final)
{
  $sta=$signal{$key}[1];
  $fin=$signal{$key}[2];

  $rem=$bsttime;

  if((exists $final{$key}[$sta][0]) && ($fin<$rem) && ($fin-$sta>=1) && (exists $final{$key}[$fin][0]) && ($final{$key}[$sta][2]>$initcolsizelim) 
      && ($final{$key}[$fin][2]-$final{$key}[$sta][2])/$final{$key}[$sta][2]>=$cutfrac) ## 
  {
    $ax=$final{$key}[$fin][0];
    $ay=$final{$key}[$fin][1];

    foreach $newkey (keys %final) 
    {
       if($key eq $newkey) { next; }
       $newfin=$signal{$newkey}[2]; 
       if((exists $final{$newkey}[1][0]) && ($newfin>$fin) && ($final{$newkey}[1][2]>$initcolsizelim)) 
       {
          $lowpt=1; $highpt=$rem;
          $area1=1; $area2=1;
          for($pnc=0;$pnc<$fin;$pnc++)
          {
             if(exists $final{$newkey}[$fin-$pnc][0]) { $lowpt=$fin-$pnc; last; } 
          }  
          for($pnc=1;$pnc<$rem-$fin;$pnc++)
          {
             if(exists $final{$newkey}[$fin+$pnc][0]) { $highpt=$fin+$pnc; last; } 
          }  
          
          if(($final{$newkey}[$highpt][2]-$final{$newkey}[1][2])/$final{$newkey}[1][2]>=$cutfrac)
	  {
	    $x=$final{$newkey}[$highpt][0];
            $y=$final{$newkey}[$highpt][1];
            $area1=$final{$newkey}[$highpt][2];
            $x2=$final{$newkey}[$lowpt][0];
            $y2=$final{$newkey}[$lowpt][1];
            $area2=$final{$newkey}[$lowpt][2];
            $adjx=0; $adjy=0;
            if($lowpt==1) { $adjx=$globminx; $adjy=$globminy; }  
	    $dist=sqrt(($ax-$x)**2+($ay-$y)**2);
	    $dist2=sqrt(($x2+$adjx-$x)**2+($y2+$adjy-$y)**2);
            $hh=($area1-$area2)/($area2*($highpt-$lowpt)*($interval/60));
            if(($dist<$neimindist && $dist2>$movedist) || $hh>1.25) ##
  	    {
 	       $signal{$newkey}[2]=$lowpt;
	    }
            undef $hh;
            undef $adjx;
            undef $adjy;
            undef $dist;
            undef $dist2;
	  }
	  #print "$newkey $x $y $dist $dist2 $fin $rem\n";
       }
    }
  }
  undef $sta;
  undef $fin;
  undef $rem;
}
undef $key;

## ---------------------------------------------------------------------------
## Time interval data and growth rate calculation and marking tracked colonies
## ---------------------------------------------------------------------------

open(INT,$intervalpath) or die;;
while($int=<INT>)
{
  chomp($int);
  @et=split(/\s+/,$int);
  @ft=split(/\./,$et[0]);
  @gt=split(/\_/,$ft[0]);
  $uin=$gt[1]."_$gt[2]";
  if($uin eq $wrinic)
  {
    $jn=@et;
    for($cp=1;$cp<$jn;$cp++) { $time_int[$cp]=$et[$cp]; }
  }
  undef $jn;
  undef $uin;
  undef(@gt);
  undef(@ft);
  undef(@et);
}
close(INT);


$string=1;
foreach $key (sort keys %final)
{
  @wr=split(/\*/,$key);
  $rem=$signal{$key}[2];
  $pp=0;
  $nopp=0;
  for($i=1;$i<=$rem;$i++) 
  { 
    if(exists $final{$key}[$i][0] && exists $time_int[$i] && $time_int[$i]!~/NaN/) 
    { 
       $reglist[$pp][0]=$time_int[$i]/60; 
       $reglist[$pp][1]=log($final{$key}[$i][2]);
       $nopp++;
    } 
    else 
    { 
       $reglist[$pp][0]="NaN";  
       $reglist[$pp][1]="NaN"; 
    } 
    $pp++; 
  } 
   
  #print "$nopp $mintime $final{$key}[1][2] $final{$key}[$rem][2] $signal{$key}[2]\n";
  if(($nopp>=$mintime) && (exists $final{$key}[1][0]) && ($final{$key}[1][2]>$initcolsizelim) && (exists $final{$key}[$rem][0]) && 
  (($final{$key}[$rem][2]-$final{$key}[1][2])/$final{$key}[1][2]>=$fractinc) && $final{$key}[$rem][2]>$finalcolsizelim && ($signal{$key}[2]>=$mintime)) ##
  {
    #$grwthrate=sprintf("%0.2f",(log($final{$key}[$rem][2])-log($final{$key}[1][2]))/(($rem-1)*($interval/60)));
    $grwthrate=regression();
    if($grwthrate==0) 
    { 
      undef $rem;
      undef(@wr);
      undef(@reglist); 
      next; 
    } #print "ERROR! Growth Rate!\n"; exit(); }

    print WR "$string $grwthrate (per h)\t"; 

    for($i=1;$i<=$rem;$i++)
    {
      if(!exists $final{$key}[$i][0]) { print WR " NaN NaN NaN\t"; next; }

      $x=$final{$key}[$i][0];
      $y=$final{$key}[$i][1];
      print WR "$x $y $final{$key}[$i][2]\t";

      if($i==1||$i==3)
      {
        if($i==1) 
	{
	  $image->string(gdGiantFont,$x+$globminx,$y+$globminy,$string,$green);
	  $string++;
          $image->setPixel($x+$globminx,$y+$globminy,$red);
          $image->setPixel($x+$globminx+1,$y+$globminy+1,$red);
          $image->setPixel($x+$globminx+1,$y+$globminy,$red);
          $image->setPixel($x+$globminx,$y+$globminy+1,$red);
          $image->setPixel($x+$globminx-1,$y+$globminy-1,$red);
          $image->setPixel($x+$globminx-1,$y+$globminy,$red);
          $image->setPixel($x+$globminx,$y+$globminy-1,$red);
	}
	else
	{
          $image->setPixel($x,$y,$red);
          $image->setPixel($x+1,$y+1,$red);
          $image->setPixel($x+1,$y,$red);
          $image->setPixel($x,$y+1,$red);
          $image->setPixel($x-1,$y-1,$red);
          $image->setPixel($x-1,$y,$red);
          $image->setPixel($x,$y-1,$red);
	}  
      } 
    }
    print WR "\n";
  }
  undef $rem;
  undef(@wr);
  undef(@reglist);
}

$string--;
print "NO. OF COLONIES: $string\n";

$copy=$image->clone();

$wrname=$name[$bsttime]; ## $name[$mi-1]
open(NEW,">$outputpath/YEAST_IDENT/$wrname") || die;
binmode NEW;
print NEW $copy -> png;
close NEW;

close(WR);

undef(@time_int);
undef %final;
undef %signal;
undef(@mem);
undef(@array);
undef(@name);

$randflag=1;
}

close(ER);

undef %dup;
system "rm $gname";

($sec,$min,$hr)=gmtime;
print "$hr:$min:$sec\n";


## ---------------------------------------------------------------------
## Subroutine to find centroid of a microcolony at previous timepoints
## ---------------------------------------------------------------------

sub findprevcentroid
{
    local($lx,$ly,$gen,$currgen,$locadjx,$locadjy)=@_;
    local $lst1=$lst2=$lst3=$lst4=$CENTDIST;
    if($lx-$locadjx<$lst1) { $lst1=$lx-$locadjx; }
    if($lx-$locadjx+$lst2>$width-1) { $lst2=$width-$lx-$locadjx-1; }
    if($ly-$locadjy<$lst3) { $lst3=$ly-$locadjy; }
    if($ly-$locadjy+$lst4>$height-1) { $lst4=$height-$ly-$locadjy-1; }

    local $mindist=1000; 
    local $mindx=$mindy=-1;
  
    local($la,$lb,$dist,$retval);

    for($la=$lx-$locadjx-$lst1;$la<=$lx-$locadjx+$lst2;$la++)
    {
      for($lb=$ly-$locadjy-$lst3;$lb<=$ly-$locadjy+$lst4;$lb++)
      {
        if(!exists $array[$gen][$la][$lb][0]) { next; }
        if($array[$gen][$la][$lb][0]>0) #&& $array[$gen][$la][$lb][3]==0)
        {
	  if($gen==$currgen-1 && $array[$gen][$la][$lb][3]!=0) { next; }
	  $dist=sqrt(($lx-$locadjx-$la)**2+($ly-$locadjy-$lb)**2);
	  if($dist<$mindist) { $mindist=$dist; $mindx=$la; $mindy=$lb; }
        }
      }
    }

    $retval=$mindx."*$mindy";
    return $retval;
}

## ----------------------------
## Subroutine for calculating max growth rate by regression
## ----------------------------

sub regression
{
  local($lno,$li,$lj,$lsumx,$lsumy,$lsum1,$lsum2,$lslope,$maxgr,$lc,$lk,$la,$ssres,$sstot,$R2);
  $lno=@reglist;

  $R2=0;
  $maxgr=0;
  for($lk=1;$lk<$lno-1;$lk++)
  {
    $lslope=0;
    $lc=0;
    $lsumx=0; $lsumy=0;
    for($li=$lk-1;$li<=$lk+1;$li++)
    {
      if($reglist[$li][0]!~/NaN/ && $reglist[$li][1]!~/NaN/)
      {
       $lsumx+=$reglist[$li][0];
       $lsumy+=$reglist[$li][1];
       $lc++;
      } 
    }

    if($lc<3) { next; }
    $lsumx/=$lc;
    $lsumy/=$lc;

    $lsum1=0; $lsum2=0;
    for($lj=$lk-1;$lj<=$lk+1;$lj++)
    {
      $lsum1+=(($reglist[$lj][0]-$lsumx)*($reglist[$lj][1]-$lsumy));
      $lsum2+=(($reglist[$lj][0]-$lsumx)**2);
    }
    if($lsum2!=0) { $lslope=sprintf("%0.3f",$lsum1/$lsum2); }
    $la=$lsumy-($lslope*$lsumx);

    $ssres=0; $sstot=0;
    for($lj=$lk-1;$lj<=$lk+1;$lj++)
    {
      $ypred=$la+$lslope*$reglist[$lj][0];
      $sstot+=(($reglist[$lj][1]-$lsumy)**2);
      $ssres+=(($ypred-$reglist[$lj][1])**2);
      undef $ypred;
    }
    if($sstot==0) { $R2=1; }
    else { $R2=1-($ssres/$sstot); }

    if($lslope>$maxgr && $lslope>0.05 && $R2>=0.95) { $maxgr=$lslope; }
  }

  return $maxgr;
}
