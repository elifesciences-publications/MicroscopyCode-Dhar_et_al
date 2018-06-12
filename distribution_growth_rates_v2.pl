#!/usr/bin/perl -w

## Copyright 2018 Riddhiman Dhar BSD-3-Clause
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
## 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


##---------------------------------------------------------------------------
##GOAL: Compile a list of microcolonies with their growth rates 
##      Compile a list of microcolonies with their respective change in area 
##----------------------------------------------------------------------------


##--------------------------------
##  READING COMMAND LINE INPUTS
##--------------------------------


@arg=@ARGV;

$no=@arg;

$pfile="X";
for($i=0;$i<$no;$i++)
{
  if($arg[$i] eq "-pfile") { $pfile=$arg[$i+1]; last; }
}

undef $no;

if($pfile eq "" || $pfile eq "X")
{
   print "ERROR! Give a parameter file for the program!\n";
   print "Usage: perl distribution_growth_rates_v1.pl -pfile <FILENAME>.\n";
   exit();
}
undef(@arg);

$dirpath="";
open(PA,$pfile) or die;
while($pa=<PA>)
{
  chomp($pa);
  @prt=split(/\t+/,$pa);
  if($prt[0] eq "DATADIR") { $dirpath=$prt[1]; next; }
  if($prt[0] eq "NUMTIME") { $timepnt=$prt[1]; next; }
  undef(@prt);
}
close(PA);

@qw=split(/\//,$dirpath);
$path="../OUTPUT/OUTPUT_$qw[5]/GROWTH_RATE/";
$path2="../OUTPUT/OUTPUT_$qw[5]/INITIAL_CENTROIDS/";
undef(@qw);
@qr=split(/\//,$path);
$outpath="../$qr[1]/$qr[2]";
undef(@qr);

##print "$dirpath $qw[4] $path $outpath\n";
system "ls $path > RATELIST_$pfile";

open(RD,"RATELIST_$pfile") or die;
$cnt=0;
while($rd=<RD>)
{
  chomp($rd);
  #if($rd=~/_B1-/ || $rd=~/_B2-/ || $rd=~/_B3-/ || $rd=~/_B4-/ || $rd=~/_B5-/ || $rd=~/_B6-/) { next; } 
  open(FP,"$path/$rd") or die;
  while($fp=<FP>)
  {
     chomp($fp);
     @arr=split(/\s+/,$fp);
     $name[$cnt]=$rd."_COLONY$arr[0]";
     $grwth[$cnt]=$arr[1];
     $xcord[$cnt]=$arr[4];
     $ycord[$cnt]=$arr[5];
     $no=@arr;
     $tc=1;
     for($i=6;$i<$no;$i+=3)
     {
       $list[$cnt][$tc]=$arr[$i];
       $tc++;
     }  
     $list[$cnt][0]=$tc;
     undef(@arr);
     $cnt++;
  }
  close(FP);
}
close(RD);


##------------------
## COMPILING LISTS
##------------------



@tui=split(/\-/,$pfile); 
@mui=split(/\.txt/,$tui[2]); 
$pref=$mui[0];
undef(@mui);
undef(@tui);
open(WR,">$outpath/$pref-GLOBAL_GROWTH_RATE.txt") or die;
for($i=0;$i<$cnt;$i++)
{
   print WR "$name[$i] $grwth[$i] ($xcord[$i],$ycord[$i])\n";
   @arr=split(/\_/,$name[$i]);
   @fur=split(/Y/,$arr[4]);
   if(exists $wellcount{$arr[0]."*$arr[1]"})
   {
     if($wellcount{$arr[0]."*$arr[1]"}<$fur[1]) { $wellcount{$arr[0]."*$arr[1]"}=$fur[1]; }
   }
   else
   {
     $wellcount{$arr[0]."*$arr[1]"}=$fur[1];
   }
   undef(@fur);
   undef(@arr);
}
close(WR);

open(WR,">$outpath/$pref-COLONY_PER_FIELD.txt") or die;
foreach $key (sort keys %wellcount)
{
  print WR "$key $wellcount{$key}\n";
}
close(WR);
undef %wellcount;

open(WR,">$outpath/$pref-GLOBAL_GROWTH_RATE2.txt") or die;
for($i=0;$i<$cnt;$i++)
{
   print WR "$name[$i]\t($xcord[$i],$ycord[$i])\t";
   for($j=1;$j<$list[$i][0];$j++)
   {
     if($list[$i][$j]=~/\-+/) { $list[$i][$j]="NaN"; }
     print WR "$list[$i][$j]\t";
   }  
   for($j=$list[$i][0];$j<=$timepnt;$j++)
   {
     print WR "NaN\t"; 
   } 
   print WR "\n";
}
close(WR);
undef(@grwth);
undef(@list);
undef(@name);

system "rm RATELIST_$pfile";

system "ls $path2 > CENTLIST_$pfile";

open(WR,">$outpath/$pref-INITIAL_CENTROID_NUM.txt") or die;
open(KU,"CENTLIST_$pfile") or die;
while($ku=<KU>)
{
   chomp($ku);
   $nut=0;
   open(PP,"$path2/$ku") or die;
   while($pp=<PP>)
   {
     $nut++;
   }  
   close(PP);
   undef $pp;
   print WR "$ku\t$nut\n";
}
close(KU);
close(WR);

system "rm CENTLIST_$pfile";
undef $pref;
