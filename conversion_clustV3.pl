#!/usr/bin/perl -w

## Copyright 2018 Riddhiman Dhar BSD-3-Clause
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
## 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


use lib "/users/blehner/rdhar/perl5/lib/perl5/";
use Parallel::ForkManager;
$mastercnt = Parallel::ForkManager->new(5);

system "export DYLD_LIBRARY_PATH=\"\$MAGICK_HOME/lib/\"";

##-----------------------
## COMMAND LINE INPUT ##
##-----------------------

@arg=@ARGV;

$no=@arg;

$pfile="X";
for($i=0;$i<$no;$i++)
{
  if($arg[$i] eq "-pfile") { $pfile=$arg[$i+1]; next; }
  if($arg[$i] eq "-time") { $batchtime=$arg[$i+1]; last; }
}

undef $no;

if($pfile eq "" || $pfile eq "X") 
{ 
   print "ERROR! Give a parameter file for the program!\n"; 
   print "Usage: perl conversion.pl -pfile <FILENAME>.\n"; 
   exit();
}
undef(@arg);

$dirpath="";
$bfield="YES";
$fluor="NO";
$numtime=0;
open(PA,$pfile) or die;
while($pa=<PA>) 
{
  chomp($pa);
  @prt=split(/\t+/,$pa);
  if($prt[0] eq "DATADIR") { $dirpath=$prt[1]; } 
  if($prt[0] eq "BRIGHTFIELD") { $bfield=$prt[1]; } 
  if($prt[0] eq "FLUORESCENCE") { $fluor=$prt[1]; } 
  if($prt[0] eq "NUMTIME") { $numtime=$prt[1]; } 
  undef(@prt);
}
close(PA);

if(($bfield eq "NO") && ($fluor eq "NO")) { print "ERROR! One of the values BRIGHTFIELD or FLUORESCENCE should be YES\n!!!"; exit(); }
if($numtime==0) { print "ERROR! Total number of time points can not be zero\n!!!"; exit(); }
@qw=split(/\//,$dirpath);
$inppath="../INPUT/INPUT_$qw[5]";
$outputpath="../OUTPUT/OUTPUT_$qw[5]";
undef(@qw);


##-------------------------------------
## CREATE INPUT AND OUTPUT DIRECTORIES
##-------------------------------------


system "mkdir $inppath";
system "mkdir $outputpath";
system "mkdir $outputpath/GROWTH_DATA/";
system "mkdir $outputpath/MARKED_PIXELS/";
system "mkdir $outputpath/CENTROID_FILES/";
system "mkdir $outputpath/GROWTH_RATE/";
system "mkdir $outputpath/YEAST_IDENT/";
system "mkdir $outputpath/INITIAL_CENTROIDS/";

for($k=1;$k<=96;$k++)
{
  $id=$k;
  system "mkdir $inppath/$id/"; 
  system "mkdir $outputpath/GROWTH_DATA/$id"; 
  system "mkdir $outputpath/MARKED_PIXELS/$id";
  system "mkdir $outputpath/CENTROID_FILES/$id"; 
  undef $id;
}


if(($bfield eq "YES") && ($fluor eq "YES")) 
{
  system "mkdir $outputpath/GROWTH_DATA2/";
  system "mkdir $outputpath/MARKED_PIXELS2/";
  system "mkdir $outputpath/GROWTH_RATE2/";
  system "mkdir $outputpath/YEAST_IDENT2/";
  system "mkdir $outputpath/INITIAL_CENTROIDS2/";

  for($k=1;$k<=96;$k++)
  {
    $id=$k;
    system "mkdir $outputpath/GROWTH_DATA2/$id";
    system "mkdir $outputpath/MARKED_PIXELS2/$id"; 
    system "mkdir $outputpath/CENTROID_FILES2/$id"; 
    undef $id;
  }
}

$difile="DIR_$pfile"."_$batchtime";
system "ls $dirpath > $difile";


##---------------------------------------------
## SEPARATE FILES BASED ON WELLS AND TIMEPOINTS
##---------------------------------------------


open(IP,$difile) or die;
while($ip=<IP>)
{
  chomp($ip);
  if($ip ne "TimePoint_$batchtime") { next; }
  $lifile="LIST_$pfile"."_$batchtime";
  system "ls $dirpath/$ip/ > $lifile";

  open(LI,$lifile) or die;
  while($li=<LI>)
  {
    if($li=~/\_Thumb/ || $li=~/\_thumb/ || $li=~/\.HTD/) { next; }
    #if($li=~/_A12_s28\./) { next; }
    #if(($bfield eq "YES") && ($fluor eq "YES"))
    #{
    #   if($li!~/\_w1/) { next; }
    #} 
    $mastercnt->start and next; # do the fork

    chomp($li);
    @arr=split(/\./,$li);
    @pr=split(/\_/,$arr[0]);
    @dg=split(/\_/,$ip);
    $no=length($dg[1]);
    if($no==1) { $tim="T0".$dg[1]; }
    else { $tim="T".$dg[1]; }
    undef $no;
    undef(@dg);
    if(($bfield eq "YES") && ($fluor eq "YES")) 
    {
      $name="$pr[1]_$pr[2]_$tim"."_$pr[3]".".$arr[1]"; ### ## For runs with both BF and fluorescence
      $pngname="$pr[1]_$pr[2]_$tim"."_$pr[3]".".png"; ### ## For runs with both BF and fluorescence
    }
    else
    {
      $name="$pr[1]_$pr[2]_$tim".".$arr[1]"; ###
      $pngname="$pr[1]_$pr[2]_$tim".".png"; ###
    }
    print "$li $name\n"; 
    
    $num=getnum($pr[1]);
    system "scp $dirpath/$ip/$li $inppath/$num/$name";
    system "/users/blehner/rdhar/bin/convert -auto-level $inppath/$num/$name $inppath/$num/$pngname";
    system "rm $inppath/$num/$name";
    undef $name;
    undef(@pr);
    undef(@arr); 

    undef $num;
    $mastercnt->finish;
  }
  close(LI);
}
close(IP);

$mastercnt->wait_all_children;

system "rm $lifile";
system "rm $difile";

## END ###

sub getnum  ## Sub-routine to create a unqiue number identifier for each well ##  
{
   local($linp)=@_;
   local($firstpt,$lastpt,$returnum,$leq);

   $firstpt=substr($linp,0,1);
   $lastpt=substr($linp,1,2);

   if($firstpt eq "A") { $leq=0; }
   if($firstpt eq "B") { $leq=1; }
   if($firstpt eq "C") { $leq=2; }
   if($firstpt eq "D") { $leq=3; }
   if($firstpt eq "E") { $leq=4; }
   if($firstpt eq "F") { $leq=5; }
   if($firstpt eq "G") { $leq=6; }
   if($firstpt eq "H") { $leq=7; }

   $returnum=$leq*12+$lastpt;
   return $returnum;
}

