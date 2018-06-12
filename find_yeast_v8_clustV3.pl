#!/usr/bin/perl/ -w

## Copyright 2018 Riddhiman Dhar BSD-3-Clause
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
## 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


##---------------------------------------
## GOAL: Find yeast cells in an image
##---------------------------------------

use lib "/users/blehner/rdhar/perl5/lib/perl5";


##---------------------------
##   COMMAND LINE INPUTS
##---------------------------


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
   print "Usage: perl ed+findyeast_v3_clust.pl -pfile <FILENAME> -time <SGE_BATCH_ID>.\n";
   exit();
}
if($batchtime eq "" || $batchtime eq "X")
{
   print "ERROR! Need a batch ID for the program!\n";
   print "Usage: perl ed+findyeast_v3_clust.pl -pfile <FILENAME> -time <SGE_BATCH_ID>.\n";
   exit();
}
undef(@arg);

($sec,$min,$hr)=gmtime;
print "$hr:$min:$sec\n";
$dirpath="";
$magnific="X";
open(PA,$pfile) or die;
while($pa=<PA>)
{
  chomp($pa);
  @prt=split(/\t+/,$pa);
  if($prt[0] eq "DATADIR") { $dirpath=$prt[1]; }
  if($prt[0] eq "MAGNIFIC") { $magnific=$prt[1]; }
  if($prt[0] eq "TIMEINTERVAL") { $interval=$prt[1]; }
  undef(@prt);
}
close(PA);

if($magnific eq "X") { print "ERROR! SPECIFY AN APPROPRIATE MAGNIFICATION VALUE!\n"; exit(); }
if($interval==0) { print "ERROR! Interval between time points can not be zero!\n"; exit(); }

@qw=split(/\//,$dirpath);
$inppath="../INPUT/INPUT_$qw[5]";
$outputpath="../OUTPUT/OUTPUT_".$qw[5];
undef(@qw);


use GD;
use LWP::Simple;
use Parallel::ForkManager;
use Statistics::Descriptive;
$stat = Statistics::Descriptive::Full->new();
$sizecut=8;

#print "Generating FILELIST...\n";

$mastercnt = Parallel::ForkManager->new(2);

$rd=$batchtime;
$gname="STARTLIST2_".$pfile."_$batchtime";
system "ls $inppath/$rd/ > $gname";
open(FP,$gname) or die;
while($fp=<FP>)
{
if($fp=~/\.TIF/) { system "rm $inppath/$rd/$fp"; next; } 
if($fp=~/\_w2\.png/|| $fp=~/\_w3\.png/) { next; } 

#if($fp!~/_s5_/ && $fp!~/_s17_/) { next; } ##  
#if($fp=~/_s5_/ || $fp=~/_s6_/ || $fp=~/_s7_/ || $fp=~/_s8_/ || $fp=~/_s9_/) { next; } ##  
$mastercnt->start and next; # do the fork
chomp($fp);

print "$fp\n";

@mco=split(/\./,$fp);
@lco=split(/\_/,$mco[0]);
$wrname2="GROWTH_$lco[0]_$lco[1]_$lco[2]";
$timpnt=substr($lco[2],1,2);
undef(@mco);
undef(@lco);
open(WR,">$outputpath/GROWTH_DATA/$rd/$wrname2") || die;


##-----------------------
##  READ IMAGE FILE
##-----------------------


open (PNG,"$inppath/$rd/$fp") || die;
$image = newFromPng GD::Image(\*PNG) || die;
close PNG;

$image=GD::Image->newFromPng("$inppath/$rd/$fp",0);

($width,$height) = $image->getBounds();

#print "$width $height\n"; exit();

$red = $image->colorAllocate(255,0,0);
$blue = $image->colorAllocate(0,0,255);
$green = $image->colorAllocate(0,255,0);

$no=0;

#print "Checking intensity dist...\n";

$arref=intensitydist($width,$height,$timpnt,$magnific);
@we=@{$arref};
$num=@we;
for($o=0;$o<$num;$o++)
{
   @me=split(/\*/,$we[$o]);
   $mem[$no][0]=$me[0]; $mem[$no][1]=$me[1]; $no++;
}
undef(@me);
undef(@we);

$no=@mem;
      
#print "$no\n"; exit();
#($sec,$min,$hr)=gmtime;
#print "$hr:$min:$sec\n";

$flag=2;


##--------------------------------------------------------------------------------------
## Identify yeast cells using sharp change in pixel intensity and sobel edge detection
##--------------------------------------------------------------------------------------


#print "Finding cells...\n";

$loc=0; 
$stcnt=0;
while($loc<$no)
{
  #if($mem[$loc][0]<3 || $mem[$loc][0]>$width-3 || $mem[$loc][1]<3 || $mem[$loc][1]>$height-3) { $loc++; next; } 
   
  if(exists $dup{$mem[$loc][0]."*$mem[$loc][1]"}) { $loc++; next; } 

  $stack[$stcnt][0]=$mem[$loc][0];
  $stack[$stcnt][1]=$mem[$loc][1];
  $stack[$stcnt][2]=1;
  $stack[$stcnt][3]=0;
  $stcnt++;

  $loc++;

  while($stcnt>0)
  {
    $x=$stack[$stcnt-1][0];
    $y=$stack[$stcnt-1][1];
    $signal=$stack[$stcnt-1][2];
    $signal2=$stack[$stcnt-1][3];
    
    #print "STACK $x $y\n";
    $stcnt--; 
     

    if(exists $dup{$x."*$y"}) { next; }

    if($list[$x][$y]>1) 
    { 
      neighborcheck($x,$y,$signal,$signal2,$timpnt); 
      $dup{$x."*$y"}=1; 
    }

    if($list[$x][$y]==1) # ||$list[$x][$y]==-1) 
    {
       $cnt=checkpixelarea($x,$y,1); 
       if($cnt<$sizecut) { next; } 
       $step1=$step2=$step3=$step4=8;

       if($x<$step1) { $step1=$x; }
       if($x>$width-$step2-1) { $step2=$width-$x-1; }
       if($y<$step3) { $step3=$y; }
       if($y>$height-$step4-1) { $step4=$height-$y-1; }

       $ind=0;
       for($a=$x-$step1;$a<=$x+$step2 && $ind==0;$a++)
       {
         for($b=$y-$step3;$b<=$y+$step4;$b++)
	 {
           if($a==$x || $b==$y) { next; }

	   if($list[$a][$b]>1) 
	   { 
	      $list[$x][$y]=$list[$a][$b]; 
	      $image->setPixel($x,$y,$green);
	      print WR "$x $y $list[$x][$y]\n";
	      $ind=1; last; 
	   }
	 }
       }

       if($ind==1) 
       { 
        neighborcheck($x,$y,1,$signal2,$timpnt); 
	$dup{$x."*$y"}=1;
	next; 
       }	
    }

    if($list[$x][$y]==1) 
    {
       $step1=$step2=$step3=$step4=2;
       if($x<$step1) { $step1=$x; }
       if($x>$width-$step2-1) { $step2=$width-$x-1; }
       if($y<$step3) { $step3=$y; }
       if($y>$height-$step4-1) { $step4=$height-$y-1; }
       
       $ind=0;
       for($a=$x-$step1;$a<=$x+$step2 && $ind==0;$a++)
       {
         for($b=$y-$step3;$b<=$y+$step4;$b++)
	 {
           if($a==$x || $b==$y) { next; }

	   if($list[$a][$b]==-1) 
	   { 
	     $list[$x][$y]=$flag; 
	     if($timpnt*$interval>=0) { $list[$a][$b]=$flag; } 
	     print WR "$x $y $list[$x][$y]\n";
             print WR "$a $b $flag\n"; 
	     $image->setPixel($x,$y,$green);
	     $image->setPixel($a,$b,$red); 
             neighborcheck($x,$y,1,$signal2,$timpnt); 
             neighborcheck($a,$b,1,0,$timpnt); 
	     $dup{$x."*$y"}=1;
	     $dup{$a."*$b"}=1;
	     $flag++; 
	     $ind=1; last; 
	   }
	 }
       }
    }
  } 
}

close(WR);
undef(@mem);
undef(@list);
undef %dup;
undef %set;
undef(@stack);
#print "$flag\n";


$copy=$image->clone();  ##

$wrname=$fp; ##
open(NEW,">$outputpath/MARKED_PIXELS/$rd/$wrname") || die; ##
binmode NEW; ##
print NEW $copy -> png; ##
close NEW; ##

$mastercnt->finish;
}
close(FP);

$mastercnt->wait_all_children;

system "rm $gname";

($sec,$min,$hr)=gmtime;
print "$hr:$min:$sec\n";


##---------------------------------------------------------------------------------------------------------------------
## Sub-routine for identification of juxtaposed bright and dark pixels using intensity distribution calculation & thresholding
## Sobel edge detection 
##---------------------------------------------------------------------------------------------------------------------

sub intensitydist
{
  local ($lwdt,$lhgt,$ltime,$lmag)=@_;
  local ($coeff,$coeff2,@sobel,$val,@data,%ltset,$lcr,$inx,$iny,$index,$crt,@temp,$upcl,$locl,$ref,$lstep1,$lstep2,$li,$lj,$end1,$end2);
  local $tr=0;


  if($lmag eq "10X")
  { 
    $coeff=2.5; # 2.2 for 10X
    $coeff=$coeff-0.05*sprintf("%0.0f",($interval/45))*($ltime-1); 
    #if($ltime>3 && $ltime<=6) { $coeff=2; } # 2
    #if($ltime>6 && $ltime<=10) { $coeff=1.8; } # 1.8
  }
  elsif($lmag eq "20X")
  {
    $coeff=2.2; # 2.2 for 10X
    $coeff=$coeff-0.05*sprintf("%0.0f",($interval/45))*($ltime-1); 
    #if($ltime>3 && $ltime<=6) { $coeff=1.8; } # 2
    #if($ltime>6 && $ltime<=10) { $coeff=1.6; } # 1.8
  }

  elsif($lmag eq "60X")
  {
    $coeff=2.2; # 2.2 for 10X
    $coeff=$coeff-0.05*sprintf("%0.0f",($interval/45))*($ltime-1); 
    #if($ltime>3 && $ltime<=6) { $coeff=1.8; } # 2
    #if($ltime>6 && $ltime<=10) { $coeff=1.6; } # 1.8
  }

  for($lcr=1;$lcr<=2;$lcr++)
  {
    $lstep1=sprintf("%0.0f",$lwdt/$lcr);
    $lstep2=sprintf("%0.0f",$lhgt/$lcr);
    $li=0; $lj=0;
    while($li<$lwdt)
    {
      $end1=$li+$lstep1;
      if($end1+$lstep1>$lwdt) { $end1=$lwdt; }
      while($lj<$lhgt)
      {
        $end2=$lj+$lstep2;
        if($end2+$lstep2>$lhgt) { $end2=$lhgt; }
        $st1=$li; $en1=$end1;
        $st2=$lj; $en2=$end2;
        local $sum1=$sum2=$sd=0;
        local $pp=0;
         
        for($inx=$st1;$inx<$en1;$inx++)
	{
	  for($iny=$st2;$iny<$en2;$iny++)
	  {
	    $index=$image->getPixel($inx,$iny);
	    $sum1+=$index;
	    $sum2+=($index**2);
	    $indlist[$inx][$iny]=$index;
	    if($lcr==1) { $list[$inx][$iny]=0; }

            $sumX=0; $sumY=0;
            if($inx<=5 || $inx>=$lwdt-5) { $sobel[$inx][$iny]=0; next; }
            if($inx<=5 || $iny>=$lhgt-5) { $sobel[$inx][$iny]=0; next; }
            local $sum=0;
            local ($index1,$index2,$index3,$index4,$index5,$index6,$index7,$index8);
	    $index1=$image->getPixel($inx-1,$iny+1);
	    $index2=$image->getPixel($inx,$iny+1);
	    $index3=$image->getPixel($inx+1,$iny+1);
	    $index4=$image->getPixel($inx-1,$iny-1);
	    $index5=$image->getPixel($inx,$iny-1);
	    $index6=$image->getPixel($inx+1,$iny-1);
	    $index7=$image->getPixel($inx+1,$iny);
	    $index8=$image->getPixel($inx-1,$iny);
            $sumX=3*$index1+($index2*10)+3*$index3-3*$index4-($index5*10)-3*$index6;
            $sumY=3*$index3+($index7*10)+3*$index6-3*$index1-($index8*10)-3*$index4;
            $sum=sqrt(($sumX)**2+($sumY)**2);
            $sobel[$inx][$iny]=$sum;
            $data[$pp]=$sum;
            $pp++;
	  }
	}

        $crt=($en1-$st1)*($en2-$st2);
        $sum1/=$crt;
	$sd=sqrt(($sum2/$crt)-($sum1**2));

	#print "$sum1 $sd\n";

	$upcl=$sum1+$coeff*$sd;
	$locl=$sum1-$coeff*$sd;

        $stat->add_data(@data);
        if($lmag eq "10X")
        {
          $coeff2=99.75; # 99.5 for 10X 
          $coeff2=$coeff2-0.05*($ltime-1)*$interval/90;

          #if(($ltime-1)*$interval>=180 && ($ltime-1)*$interval<=360) { $coeff=97; } 
          #if(($ltime-1)*$interval>360) { $coeff=95; } 
        }
        elsif($lmag eq "20X")
        {
          $coeff2=99.75; # 99.5 for 10X 
          $coeff2=$coeff2-0.05*($ltime-1)*$interval/90;

          #if(($ltime-1)*$interval>=180 && ($ltime-1)*$interval<=360) { $coeff=97; } 
          #if(($ltime-1)*$interval>360) { $coeff=95; } 
        }
        elsif($lmag eq "60X")
        {
          $coeff2=99.75; # 99.5 for 10X 
          $coeff2=$coeff2-0.05*($ltime-1)*$interval/90;

          #if(($ltime-1)*$interval>=180 && ($ltime-1)*$interval<=360) { $coeff=97; } 
          #if(($ltime-1)*$interval>360) { $coeff=95; } 
        }

        $val=$stat->percentile($coeff2);

        $lfl=0;
        for($inx=$st1;$inx<$en1;$inx++)
	{
	  for($iny=$st2;$iny<$en2;$iny++)
	  {

	    if($indlist[$inx][$iny]>$upcl || $sobel[$inx][$iny]>$val)
	    {
	      if(exists $ltset{$inx."*$iny"}) { next; }
	      $list[$inx][$iny]=1;
	      $ltset{$inx."*$iny"}=$inx."*$iny";
	      #$image->setPixel($inx,$iny,$green); 
	      $lfl=1;
	    }
	    elsif($indlist[$inx][$iny]<$locl) ## || $sobel[$inx][$iny]>$val)
	    {
	      $ltset{$inx."*$iny"}=$inx."*$iny";
	      $list[$inx][$iny]=-1;
	      #$image->setPixel($inx,$iny,$red); 
	      $lfl=1;
	    }
	  }
	}

        undef $val;
        undef(@sobel);
        undef(@data);
 
        $lj+=$lstep2;
      }
      $li+=$lstep1; $lj=0;
    }
  }

  undef(@indlist);

  foreach $key (sort keys %ltset)
  {
      $temp[$tr]=$ltset{$key};
      $tr++;
  }

  undef %ltset;
  $ref=\@temp;
  return $ref;
}


##----------------------------------------------------------------
## Sub-routine for chacking intensities of neighbouring pixels
##----------------------------------------------------------------


sub neighborcheck
{
  local($xc,$yc,$val,$val2,$loctime)=@_;
  local($la,$lb,$nt);
  local $lcn1=$lcn2=$lcn3=$lcn4=0;

  local $step1=$step2=$step3=$step4=8;
  if($xc<$step1) { $step1=$xc; }
  if($xc>$width-$step2-1) { $step2=$width-$xc-1; }
  if($yc<$step3) { $step3=$yc; }
  if($yc>$height-$step4-1) { $step4=$height-$yc-1; }

  if($val2==1) { $step1=0; $step3=0; }
  if($val2==2) { $step2=0; $step4=0; }
  if($val2==3) { $step1=0; $step4=0;  }
  if($val2==4) { $step2=0; $step3=0; }

  for($la=$xc-$step1;$la<=$xc+$step2;$la++)
  {
    for($lb=$yc-$step3;$lb<=$yc+$step4;$lb++)
    {
      if($la==$xc && $lb==$yc) { next; }

      local $lclfl=0;

      if($list[$la][$lb]==1) 
      { 
        $nt=checkpixelarea($la,$lb,1); 
        if($nt>=$sizecut) 
	{ 
	  $lclfl=1;
          $list[$la][$lb]=$list[$xc][$yc]; 
	  $image->setPixel($la,$lb,$green); 
	  $stack[$stcnt][2]=1;
	}
      }
      elsif($list[$la][$lb]==-1) 
      {
        if((abs($la-$xc)<=2 && abs($lb-$yc)<=2 && $val==1) || ( $loctime*$interval>=0 && abs($la-$xc)<=1 && abs($lb-$yc)<=1 && $val==-1))
	{
          if(exists $set{$la."*$lb"}) { next; }
          $set{$la."*$lb"}=1;
          $list[$la][$lb]=$list[$xc][$yc]; ### 
	  $lclfl=1;
          $image->setPixel($la,$lb,$red);  
	  $stack[$stcnt][2]=-1; ###
	}  
      }
      elsif($loctime*$interval>=0 && $list[$la][$lb]<1 && $la>4 && $lb>4 && $la<$width-4 && $lb<$height-4)
      {
         $lcn1=$lcn2=$lcn3=$lcn4=0;
   
         if(($list[$la+2][$lb+2])>1 || ($list[$la+3][$lb+3])>1 || ($list[$la+4][$lb+4])>1) { $lcn1++; }  
         if(($list[$la-2][$lb-2])>1 || ($list[$la-3][$lb-3])>1 || ($list[$la-4][$lb-4])>1) { $lcn2++; }  
         if(($list[$la+2][$lb-2])>1 || ($list[$la+3][$lb-3])>1 || ($list[$la+4][$lb-4])>1) { $lcn3++; }  
         if(($list[$la-2][$lb+2])>1 || ($list[$la-3][$lb+3])>1 || ($list[$la-4][$lb+4])>1) { $lcn4++; }  
      
         if((($lcn1>=1 && $lcn2>=1 && $lcn3>=1) || ($lcn1>=1 && $lcn2>=1 && $lcn4>=1) || ($lcn1>=1 && $lcn3>=1 && $lcn4>=1) ||
           ($lcn2>=1 && $lcn3>=1 && $lcn4>=1)) && (abs($la-$xc)<=4 && abs($lb-$yc)<=4)) 
           #if(($lcn1>=1 && $lcn2>=1 && $lcn3>=1 && $lcn4>=1) && (abs($la-$xc)<=4 && abs($lb-$yc)<=4)) 
           { 
              $list[$la][$lb]=$list[$xc][$yc]; ### 
              $lclfl=1;
              $image->setPixel($la,$lb,$blue);
              $stack[$stcnt][2]=$list[$la][$lb]; ###
           }  
      }          
      
      if($lclfl==1)
      {
	  print WR "$la $lb $list[$la][$lb]\n";
	  $stack[$stcnt][0]=$la;
	  $stack[$stcnt][1]=$lb;
	  $stack[$stcnt][3]=0;
	  if($la<$xc && $lb<$yc) { $stack[$stcnt][3]=2; }
	  if($la>$xc && $lb>$yc) { $stack[$stcnt][3]=1; }
	  if($la<$xc && $lb>$yc) { $stack[$stcnt][3]=4; }
	  if($la>$xc && $lb<$yc) { $stack[$stcnt][3]=3; }
	  $stcnt++;
      }
   }
 }
 return;
}


##------------------------------------------------------------------------------------------
## Sub-routine to calculate pixel area using intensities of immediate neigbors for a pixel
##------------------------------------------------------------------------------------------


sub checkpixelarea
{
  local($xcord,$ycord,$value)=@_;
  local $count=0;

  if($xcord<2 || $xcord>$width-3 || $ycord<2 || $ycord>$height-3) { return $count; }

  if($list[$xcord+1][$ycord+1]>=$value) { $count++; }
  if($list[$xcord+1][$ycord]>=$value) { $count++; }
  if($list[$xcord][$ycord+1]>=$value) { $count++; }
  if($list[$xcord-1][$ycord-1]>=$value) { $count++; }
  if($list[$xcord-1][$ycord]>=$value) { $count++; }
  if($list[$xcord][$ycord-1]>=$value) { $count++; }
  if($list[$xcord+1][$ycord-1]>=$value) { $count++; }
  if($list[$xcord-1][$ycord+1]>=$value) { $count++; }
  
  if($list[$xcord+1][$ycord+1]>=$value && $list[$xcord+2][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord]>=$value && $list[$xcord+2][$ycord]>=$value) { $count+=2; }
  if($list[$xcord][$ycord+1]>=$value && $list[$xcord][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord+1]>=$value && $list[$xcord][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord]>=$value && $list[$xcord+2][$ycord+1]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord+1]>=$value && $list[$xcord+2][$ycord+1]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord+1]>=$value && $list[$xcord+1][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord][$ycord+1]>=$value && $list[$xcord+1][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord+1]>=$value && $list[$xcord+2][$ycord+1]>=$value) { $count+=2; }
  
  if($list[$xcord-1][$ycord+1]>=$value && $list[$xcord][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord+1]>=$value && $list[$xcord-1][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord][$ycord+1]>=$value && $list[$xcord-1][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord+1]>=$value && $list[$xcord-2][$ycord+2]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord+1]>=$value && $list[$xcord-2][$ycord+1]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord]>=$value && $list[$xcord-2][$ycord+1]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord+1]>=$value && $list[$xcord-2][$ycord]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord]>=$value && $list[$xcord-2][$ycord]>=$value) { $count+=2; }
    
  if($list[$xcord-1][$ycord-1]>=$value && $list[$xcord-2][$ycord]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord-1]>=$value && $list[$xcord-2][$ycord-1]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord]>=$value && $list[$xcord-2][$ycord-1]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord-1]>=$value && $list[$xcord-2][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord-1]>=$value && $list[$xcord-1][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord][$ycord-1]>=$value && $list[$xcord-1][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord][$ycord-1]>=$value && $list[$xcord][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord-1][$ycord-1]>=$value && $list[$xcord][$ycord-2]>=$value) { $count+=2; }

  if($list[$xcord+1][$ycord-1]>=$value && $list[$xcord][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord-1]>=$value && $list[$xcord+1][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord][$ycord-1]>=$value && $list[$xcord+1][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord-1]>=$value && $list[$xcord+2][$ycord-2]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord-1]>=$value && $list[$xcord+2][$ycord-1]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord]>=$value && $list[$xcord+2][$ycord-1]>=$value) { $count+=2; }
  if($list[$xcord+1][$ycord-1]>=$value && $list[$xcord+2][$ycord]>=$value) { $count+=2; }

  return $count; 
}

