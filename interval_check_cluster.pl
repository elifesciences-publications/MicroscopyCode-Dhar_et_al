#!/usr/bin/perl -w

## Copyright 2018 Riddhiman Dhar BSD-3-Clause
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
## 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


##-------------------------------------------------------------
##  Calculation of time intervals between image acquisitions 
##-------------------------------------------------------------


$foldname[0]="<NAME OF THE FOLDER WHERE TIMELAPSE DATA IS PRESENT>";

for($mu=0;$mu<1;$mu++)
{
  system "ls /users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/ > TIMELIST";

  open(MI,">../TIME_INTERVAL/MISSED_$foldname[$mu]") or die;

  open(TI,"TIMELIST") or die;
  $cnt=0;
  while($ti=<TI>)
  {
    chomp($ti);
    if($ti=~/\.HTD/) { next; }
    if($cnt==0) { system "ls /users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$ti/ > FILELIST"; }
    $cnt++;
  }
  close(TI);
  print "$foldname[$mu]\n";
  system "rm TIMELIST";

  open(FP,"FILELIST") or die;
  open(WR,">../TIME_INTERVAL/INTERVAL_$foldname[$mu].txt");
  $filename="";
  while($fp=<FP>)
  {
    chomp($fp);
    if($fp=~/\.HTD/ || $fp=~/\_Thumb/ || $fp=~/\_thumb/) { next; }
    $filename=$fp;   

   print "   $filename\n";
   print WR "$filename\t0\t";

   ##@spfile=split(/\_/,$filename);
   ##$filename2=$spfile[0]."-2"."_$spfile[1]_$spfile[2]";
   ##undef(@spfile);

   $currhr=0; $prevhr=0;
   $currmin=0; $prevmin=0;
   $currday=0; $prevday=0;
   $currmon=0; $prevmon=0;
   $curryear=0; $prevyear=0;
   $monflag=0;
   for($c=0;$c<$cnt;$c++)
   {
    $p=$c+1;
    $timepnt="TimePoint_$p";

    if(!-e "/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename")
    ##if(!-e "/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename" && !-e "/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename2") 
    { 
      print MI "$foldname[$mu] $timepnt $filename\n"; 
      if($p!=1) { print WR "NaN\t"; }
      next; 
    }

    open(LL,"/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename") or die; 
    #if(-e "/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename") { open(LL,"/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename") or die; }
    #else { open(LL,"/users/blehner/rdhar/DATA_Procsys4/$foldname[$mu]/$timepnt/$filename2") or die; }
    $miflag=0;   
    while($ll=<LL>)
    {
       chomp($ll);
       if($ll=~/MetaMorph/)
       {
          $miflag=1;   
          @msp=split(/MetaMorph/,$ll);
          @arr=split(/\:/,$msp[1]);
          @qw=split(/\s+/,$arr[2]);
          if($prevmon==0) 
          {
            $prevyear=substr($arr[0],length($arr[0])-4,4);
            $prevmon=$arr[1];
            $prevday=$qw[0];  
            $prevhr=$qw[1];
            $prevmin=$arr[3];  
 
            if($p!=1) { print WR "0\t"; }
          }
          else
          {
            $curryear=substr($arr[0],length($arr[0])-4,4);
            $currmon=$arr[1];
            $currday=$qw[0];  
            $currhr=$qw[1];
            $currmin=$arr[3];  

            #if($currhr<$prevhr)  
            #{
            #  $currhr+=24;
            #}      
            if($curryear>$prevyear)
            {
              $currmon=$currmon+$prevmon;
            }

            if($currmon>$prevmon)
            {
              if($monflag==0) 
              {
                $monflag=1;
              }
              $currday+=$lastday; 
            }  

            $currhr+=24*($currday-$prevday);

            $currtime=$currhr*60+$currmin;      
            $prevtime=$prevhr*60+$prevmin;      
            $interval=$currtime-$prevtime;      
            print WR "$interval\t";     
            #print "$curryear $prevyear $currmon $prevmon $currday $prevday $currtime $prevtime\n";

            #$prevmon=$arr[1];
            #$prevday=$qw[0];  
            #$prevhr=$qw[1];
            #$prevmin=$arr[3];  
            
            if($monflag==0) { $lastday=$currday; }

          }              
          undef(@qw);   
          undef(@arr);
          undef(@msp);   
          last;  
       }
    }
    close(LL);
    if($miflag==0) 
    { 
      print MI "$foldname[$mu] $timepnt $filename\n";  
      if($p!=1) { print WR "NaN\t"; }
    }
   }
   print WR "\n";
   undef $monflag;
  }
  close(WR);
  close(FP);
  system "rm FILELIST";
  close(MI);
}
