package Bio::Rfam::Utils;

#TODO: add pod documentation to all these functions

#Occasionally useful Rfam utilities

use strict;
use warnings;
use Sys::Hostname;
use File::stat;
use Carp;

use Cwd;
use Data::Dumper;
use Mail::Mailer;
use File::Copy;
use vars qw( @ISA
             @EXPORT
);

@ISA    = qw( Exporter );

#-------------------------------------------------------------------------------

=head2 run_local_command

  Title    : run_local_command
  Incept   : EPN, Tue Apr  2 05:54:38 2013
  Usage    : run_local_command($cmd)
  Function : Performs system call of command $cmd. Dies if it does not
           : successfully complete.
  Args     : $cmd: command to run
  Returns  : void
  Dies     : If $cmd fails by returning non-zero status.

=cut

sub run_local_command { 
  my ($cmd) = @_;
  
  system($cmd);
  if($? != 0) { die "$cmd failed"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 submit_nonmpi_job

  Title    : submit_nonmpi_job()
  Incept   : EPN, Tue Apr  2 05:59:40 2013
  Usage    : submit_nonmpi_job($location, $cmd, $jobname, $errPath, $ncpu, $reqMb, $exStr)
  Function : Submits non-MPI job defined by command $cmd.
           : Submission syntax depends on $location value.
           : We do *not* wait for job to finish. Caller
           : must do that, probably with wait_for_cluster().
  Args     : $location: config->location, e.g. "EBI"
           : $cmd:      command to run
           : $jobname:  name for job
           : $errPath:  path for stderr output
           : $ncpu:     number of CPUs to run job on, can be undefined if location eq "JFRC"
           : $reqMb:    required number of Mb for job, can be undefined if location eq "JFRC"
           : $exStr:    extra string to add to qsub/sub command
           : $queue:    queue to submit to, "" for default
  Returns  : void
  Dies     : If MPI submit command fails.

=cut

sub submit_nonmpi_job { 
  my ($location, $cmd, $jobname, $errPath, $ncpu, $reqMb, $exStr, $queue) = @_;

  my $submit_cmd = "";
  if($location eq "EBI") { 
    if(! defined $ncpu)  { die "submit_nonmpi_job(), location is EBI, but ncpu is undefined"; }
    if(! defined $reqMb) { die "submit_nonmpi_job(), location is EBI, but reqMb is undefined"; }
    $submit_cmd = "bsub ";
    if(defined $exStr && $exStr ne "") { $submit_cmd .= "$exStr "; }
    if(defined $queue && $queue ne "") { 
      $submit_cmd .= "-q $queue "; 
    }
    else { 
      $submit_cmd .= "-q research-rh6 "; 
    }
    $submit_cmd .= "-n $ncpu -J $jobname -o /dev/null -e $errPath -M $reqMb -R \"rusage[mem=$reqMb]\" \"$cmd\" > /dev/null";
  }
  elsif($location eq "JFRC") { 
    my $batch_opt = "";
    if($ncpu > 1) { $batch_opt = "-pe batch $ncpu"; }
    $submit_cmd = "qsub ";
    if(defined $exStr && $exStr ne "") { $submit_cmd .= "$exStr "; }
    if(defined $queue && $queue ne "") { $submit_cmd .= "-l $queue=true "; }
    $submit_cmd .= " -N $jobname -o /dev/null -e $errPath $batch_opt -b y -cwd -V \"$cmd\" > /dev/null"; 
  }
  else { 
    die "ERROR unknown location $location in submit_nonmpi_job()";
  }

  # actually submit job
  # print STDERR ("submit cmd: $submit_cmd\n");
  system($submit_cmd);
  if($? != 0) { die "Non-MPI submission command $submit_cmd failed"; }

  return;
}

#-------------------------------------------------------------------------------

=head2 submit_mpi_job

  Title    : submit_mpi_job()
  Incept   : EPN, Tue Apr  2 05:59:40 2013
  Usage    : submit_mpi_job($location, $cmd, )
  Function : Submits MPI job defined by command $cmd.
           : MPI submission syntax depends on $location value.
           : We do *not* wait for job to finish. Caller
           : must do that, probably with wait_for_cluster().
  Args     : $location: config->location, e.g. "EBI"
           : $cmd:      command to run
           : $jobname:  name for job
           : $errPath:  path for stderr output
           : $nproc:    number of MPI processors to use
           : $queue:    queue to submit to, "" for default, ignored if location eq "EBI"
  Returns  : void
  Dies     : If MPI submit command fails.

=cut

sub submit_mpi_job { 
  my ($location, $cmd, $jobname, $errPath, $nproc, $queue) = @_;

  my $submit_cmd = "";
  if($location eq "EBI") { 
    # EPN: for some reason, this 'module' command fails inside perl..., I think it may be unnecessary because it's in my .bashrc
    #my $prepcmd = "module load openmpi-x86_64";
    #system($prepcmd);
    #if($? != 0) { die "MPI prep command $prepcmd failed"; }

    # Need to use MPI queue ($queue is irrelevant)
    $submit_cmd = "bsub -J $jobname -e $errPath -q mpi -I -n $nproc -a openmpi mpirun.lsf -np $nproc -mca btl tcp,self $cmd";
  }
  elsif($location eq "JFRC") { 
    my $queue_opt = "";
    if($queue ne "") { $queue_opt = "-l $queue=true "; }
    $submit_cmd = "qsub -N $jobname -e $errPath -o /dev/null -b y -cwd -V -pe impi $nproc " . $queue_opt . "\"mpirun -np $nproc $cmd\" > /dev/null";
  }
  else { 
    die "ERROR unknown location $location in submit_mpi_job()";
  }

  # actually submit job
  print STDERR "about to execute system call: \"$submit_cmd\"\n";
  system($submit_cmd);
  if($? != 0) { die "MPI submission command $submit_cmd failed"; }

  return;
}

#-------------------------------------------------------------------------------

=head2 wait_for_cluster

    Title    : wait_for_cluster
    Incept   : EPN, Sat Mar 30 07:01:24 2013
    Usage    : wait_for_cluster($jobnameAR, $outnameAR, $success_string, $program, $outFH, $max_minutes)
    Function : Waits for specific job(s) to finish running on cluster
             : and verifies their output. 
             : The job names are listed in $jobnameAR. Each
             : job will produce an output file named $outnameAR. When
             : each job finishes, as indicated by it no longer appearing
             : in a list of queued or running jobs on the cluster, we
             : check that (a) its output file exists and (b) its output
             : file includes the string $success_string. If $max_minutes
             : is defined and != -1, we will die if all jobs fail to 
             : successfully complete within $max_minutes minutes. 
             : 
             : Ways to return or die:
             : (1) Returns if all jobs finish and all jobs output files 
             :     contain $success_string string. This is only way to 
             :     return successfully.
             : (2) Dies if $success_string ne "" and any job finishes 
             :     and its output file does not contain at least 1 line
             :     that *begins with* $success_string. 
             : (3) Dies if $max_minutes is defined and != -1, and any
             :     job takes longer than $max_minutes to complete.
             :
    Args     : $location:       location, e.g. "JFRC" or "EBI"
             : $username:       username the cluster jobs belong to
             : $jobnameAR:      ref to array of list of job names on cluster
             : $outnameAR:      ref to array of list of output file names, one per job
             : $success_string: string expected to exist in each output file 
             : $program:        name of program running, if "": do not print updates
             : $outFH:          output file handle for updates, if "" only print to STDOUT
             : $extra_note:     extra information to output with progress, "" for none
             : $max_minutes:    max number of minutes to wait, -1 for no limit
             :
    Returns  : Maximum number of seconds any job spent waiting in queue, rounded down to 
             : nearest 10 seconds.
    Dies     : Cases (2) or (3) listed in "Function" section above.

=cut

sub wait_for_cluster { 
  my ($location, $username, $jobnameAR, $outnameAR, $success_string, $program, $outFH, $extra_note, $max_minutes) = @_;

  my $start_time = time();
  
  my $n = scalar(@{$jobnameAR});
  my $i;
  if($extra_note ne "") { $extra_note = "  " . $extra_note; }

  # sanity check
  if(scalar(@{$outnameAR}) != $n) { die "wait_for_cluster(), internal error, number of elements in jobnameAR and outnameAR differ"; }

  # modify username > 7 characters and job names > 10 characters if we're at EBI, because bjobs truncates these
  if($location eq "EBI") { 
    if(length($username) > 7) { 
      $username = substr($username, 0, 7); # bjobs at EBI only prints first 7 letters of username
    }
    for($i = 0; $i < $n; $i++) { 
      if(length($jobnameAR->[$i]) > 10) { # NOTE: THIS WILL CHANGE THE VALUES IN THE ACTUAL ARRAY jobnameAR POINTS TO!
        $jobnameAR->[$i] = "*" . substr($jobnameAR->[$i], -9);
      }
    }
  }
  elsif($location ne "JFRC") { 
    die "ERROR in wait_for_cluster, unrecognized location: $location"; 
  }

  my $sleep_nsecs = 5;  # we'll call qstat/bjobs every 5 seconds
  my $print_freq  = 12; # print update every 12 loop iterations (about every 12*$sleep_nsecs seconds)
  my @ininfoA = ();
  my @successA = ();
  my @infoA  = ();
  my @elA    = ();
  my $nsuccess = 0;
  my $max_wait_secs = 0;
  my ($minutes_elapsed, $nrunning, $nwaiting, $line, $uname, $jobname, $status, $i2);
  $i2 = 0;
  for($i = 0; $i < $n; $i++) { $successA[$i] = 0; } 

  sleep(2); 

  while($nsuccess != $n) { 
    if   ($location eq "JFRC") { @infoA = split("\n", `qstat`); }
    elsif($location eq "EBI")  { @infoA = split("\n", `bjobs`); }

    for($i = 0; $i < $n; $i++) { $ininfoA[$i] = 0; } 
    $nrunning  = 0;
    $nwaiting  = 0;
    foreach $line (@infoA) { 
      if($line =~ m/^\s*\d+\s+/) { 
        $line =~ s/^\s*//;
        @elA = split(/\s+/, $line);
        if($location eq "JFRC") { 
          #1232075 4.79167 QLOGIN     davisf       r     03/25/2013 14:24:11 f02.q@f02u09.int.janelia.org                                      8        
          # 396183 10.25000 QLOGIN     nawrockie    r     07/26/2013 10:10:41 new.q@h02u19.int.janelia.org                                      1        
          # 565685 0.00000 c.25858    nawrockie    qw    08/01/2013 15:18:55                                                                  81        
          ($jobname, $uname, $status) = ($elA[2], $elA[3], $elA[4]);
        }
        elsif($location eq "EBI") { 
          # jobid   uname   status queue     sub node    run node    job name   date     
          # 5134531 vitor   RUN   research-r ebi-004     ebi5-037    *lection.R Apr 29 18:00
          # 4422939 stauch  PEND  research-r ebi-001                 *ay[16992] Apr 26 12:56
          ($uname, $status) = ($elA[1], $elA[2]);
          if($status eq "RUN") { $jobname = $elA[6]; }
          else                 { $jobname = $elA[5]; }
          #print STDERR ("uname: $uname status: $status; jobname: $jobname\n");
        }
        #printf("\tjobname: $jobname uname: $uname status: $status\n");
        if($uname ne $username) { die "wait_for_cluster(), internal error, uname mismatch ($uname ne $username)"; }
        # look through our list of jobs and see if this one matches
        for($i = 0; $i < $n; $i++) { 
          #printf("\t\tsuccess: %d\tininfo: %d\tmatch: %d\n", $successA[$i], $ininfoA[$i], ($jobnameAR->[$i] eq $jobname) ? 1 : 0);
          if((! $successA[$i]) &&              # job didn't successfully complete already 
             (! $ininfoA[$i]) &&              # we didn't already find this job in the queue
             ($jobnameAR->[$i] eq $jobname)) { # jobname match
            $ininfoA[$i] = 1; 
            if($location eq "JFRC") { 
              if($status eq "r")     { $nrunning++; }
              elsif($status =~ m/E/) { die "wait_for_cluster(), internal error, qstat shows Error status: $line"; }
              else                   { $nwaiting++; } 
            }
            elsif($location eq "EBI") { 
              if   ($status eq "RUN")  { $nrunning++; }
              elsif($status eq "PEND") { $nwaiting++; } 
              else                     { die "wait_for_cluster(), internal error, bjobs shows non-\"RUN\" and non-\"PEND\" status: $line"; }
            }
          }
        }
      } # end of if($line =~ m/^\d/) 
    } # end of 'foreach $line (@infoA)'
    if($nwaiting > 0) { $max_wait_secs = time() - $start_time; } 

    # for all jobs not found in the qstat output, make sure they finished properly
    for($i = 0; $i < $n; $i++) { 
      if((! $successA[$i]) && # job didn't successfully complete already 
         (! $ininfoA[$i])) { # we didn't find this job in the queue
        if(! -e $outnameAR->[$i]) { die "wait_for_cluster() job $i seems to be finished (not in queue) but expected output file ($outnameAR->[$i] does not exist"; }
        open(IN, $outnameAR->[$i]) || die "wait_for_cluster() job $i seems to be finished (not in queue) but expected output file ($outnameAR->[$i] can't be opened"; 
        while($line = <IN>) { 
          if($line =~ m/\Q$success_string/) {
            $successA[$i] = 1; 
            $nsuccess++; 
            #printf("\tjob %2d finished successfully!\n", $i);
            last;
          }
        }
        if(! $successA[$i]) { die "wait_for_cluster() job $i finished, but expected output file $outnameAR->[$i] does not contain: $success_string\n"; }
        close(IN);
      }
    }
    $minutes_elapsed = (time() - $start_time) / 60;
    if($program ne "") { 
      if($nsuccess == $n || $i2 % $print_freq == 0) { 
        my $outstr = sprintf("  %-15s  %-10s  %10s  %10s  %10s  %10s%s\n", $program, "cluster", $nsuccess, $nrunning, $nwaiting, Bio::Rfam::Utils::format_time_string(time() - $start_time), $extra_note);
        $extra_note = ""; # only print this once 
        print STDOUT $outstr;
        if($outFH ne "") { print $outFH $outstr; }
      }
    }
    $i2++;
    if(defined $max_minutes && $max_minutes != -1 && $minutes_elapsed > $max_minutes) { die "wait_for_cluster(), reached maximum time limit of $max_minutes minutes, exiting."; }
    if($nsuccess != $n) { sleep($sleep_nsecs); }
  }
  
  return $max_wait_secs;
  # The only way we'll get here is if all jobs are finished (not in queue) 
  # and have $success_string in output file, if not, we'll have die'd earlier
}

#-------------------------------------------------------------------------------

=head2 format_time_string

  Title    : format_time_string()
  Incept   : EPN, Tue Apr  2 11:10:38 2013
  Usage    : format_time_string($seconds)
  Function : Return string in "hh:mm:ss" format given 
           : a number of seconds ($seconds). 
  Args     : $seconds: number of seconds
  Returns  : void

=cut

sub format_time_string { 
  my ($seconds) = @_;

  my $h = int($seconds / 3600.);
  $seconds -= $h * 3600;
  my $m = int($seconds / 60.);
  $seconds -= $m * 60;

  return sprintf("%02d:%02d:%02d", $h, $m, $seconds);
}

#-------------------------------------------------------------------------------

=head2 concatenate_files

  Title    : concatenate_files()
  Incept   : EPN, Tue Apr  2 18:58:54 2013
  Usage    : concatenate_files($fileAR, $dest_file, $unlink_flag)
  Function : Concatenate all files in @{$fileAR} to create a new 
           : file $dest_file. If $unlink_file is '1' then unlink
           : all files in $fileAR before returning.
  Args     : $fileAR: ref to array of files to concatenate
           : $dest_file: new file, concatenation of all files in $fileAR
           : $unlink_flag: '1' to remove all files in $fileAR before returning
  Returns  : void
  Dies     : if unable to do the concatenation

=cut

sub concatenate_files {
  my ($fileAR, $dest_file, $unlink_flag) = @_;

  my $n = scalar(@{$fileAR});
  my $i;
  open(OUT, ">" . $dest_file) || die "ERROR unable to open $dest_file for writing";
  for ($i = 0; $i < $n; $i++) { 
    open(IN, $fileAR->[$i]) || die "ERROR unable to open $fileAR->[$i] for reading";
    while(<IN>) { print OUT $_; }
    close(IN);
  }
  close(OUT);

  # unlink files if nec, do this after we concatenate, in case something goes wrong
  if($unlink_flag) { 
    for ($i = 0; $i < $n; $i++) { 
      unlink $fileAR->[$i];
    }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 tax2kingdom

  Title    : tax2kingdom
  Incept   : pg5
  Usage    : tax2kingdom($species)
  Function : Return kingdom string given a taxonomy string.
  Args     : $species: the taxonomic string 
  Returns  : kingdom string 

=cut

sub tax2kingdom {
    my ($species) = @_;
    my $kingdom;
    #unclassified sequences; metagenomes; ecological metagenomes.
    if ($species=~/^(.+?);\s+(.+?)\.*?;/){
	$kingdom = "$1; $2";
    }
    if(! defined $kingdom) { 
      die "FATAL: failed to parse a kingdom from species string: [$species]. !"; 
    }
    
    return $kingdom;
}

#-------------------------------------------------------------------------------

=head2 nse_breakdown

  Title    : nse_breakdown
  Incept   : EPN, Wed Jan 30 09:50:07 2013
  Usage    : nse_breakdown($nse)
  Function : Checks if $nse is of format "name/start-end" and if so
           : breaks it down into $n, $s, $e, $str (see 'Returns' section)
  Args     : <sqname>: seqname, possibly of format "name/start-end"
  Returns  : 5 values:
           :   '1' if seqname was of "name/start-end" format, else '0'
           :   $n:   name ("" if seqname does not match "name/start-end")
	   :   $s:   start, maybe <= or > than $e (0 if seqname does not match "name/start-end")
	   :   $e:   end,   maybe <= or > than $s (0 if seqname does not match "name/start-end")
           :   $str: strand, 1 if $s <= $e, else -1
=cut

sub nse_breakdown {
    my ($sqname) = @_;

    my $n;       # sqacc
    my $s;       # start, from seq name (can be > $end)
    my $e;       # end,   from seq name (can be < $start)
    my $str;     # strand, 1 if $start <= $end, else -1

    if($sqname =~ m/^(\S+)\/(\d+)\-(\d+)\s*/) {
	($n, $s, $e) = ($1,$2,$3);
        $str = ($s <= $e) ? 1 : -1; 
	return (1, $n, $s, $e, $str);
    }
    return (0, "", 0, 0, 0);
}

#-------------------------------------------------------------------------------

=head2 nse_sqlen

  Title    : nse_sqlen
  Incept   : EPN, Thu Jan 31 10:08:24 2013
  Usage    : nse_sqlen($name);
  Function : Returns length of sequence given $nse,
           : where $nse is of format:
           : <sqacc>/<start>-<end>
           : and <start> may be > <end>.
  Args     : $nse: sequence name in <sqacc>/<start>-<end> format
  Returns  : Length in residues represented by $nse

=cut

sub nse_sqlen {
    my ($nse) = @_;

    my $sqlen;
    if($nse =~ m/^\S+\/(\d+)\-(\d+)\s*/) {
	my ($start, $end) = ($1, $2);
	if($start <= $end) { $sqlen = $end - $start + 1; }
	else               { $sqlen = $start - $end + 1; }
    }
    else { 
	croak "invalid name $nse does not match name/start-end format\n";
    }
    return $sqlen;
}

#-------------------------------------------------------------------------------

=head2 overlap_fraction_two_nse

  Title    : overlap_fraction_two_nse
  Incept   : EPN, Thu Feb  7 14:47:37 2013
  Usage    : overlap_fraction_two_nse($nse1, $nse2)
  Function : Returns fractional overlap of two regions defined by
           : $nse1 and $nse2. Where $nse1 and $nse2 are both of
           : format "name/start-end".
  Args     : <nse1>: "name/start-end" for region 1
           : <nse2>: "name/start-end" for region 2
  Returns  : Fractional overlap between region 1 and region 2
           : (This will be 0. if names are different for regions 1 and 2.)
           : (This will be 0. if regions are on different strands.)

=cut

sub overlap_fraction_two_nse {
    my ($nse1, $nse2) = @_;

    my($is1, $n1, $s1, $e1, $str1) = nse_breakdown($nse1);
    if(! $is1) { croak "$nse1 not in name/start-end format"; }
    my($is2, $n2, $s2, $e2, $str2) = nse_breakdown($nse2);
    if(! $is2) { croak "$nse2 not in name/start-end format"; }

    if($n1 ne $n2) { return 0.; } #names don't match

    return overlap_fraction($s1, $e1, $s2, $e2);
}

#-------------------------------------------------------------------------------

=head2 overlap_fraction

  Title    : overlap_fraction
  Incept   : EPN, Thu Jan 31 08:50:55 2013
  Usage    : overlap_fraction($from1, $to1, $from2, $to2)
  Function : Returns fractional overlap of two regions.
           : If $from1 is <= $to1 we assume first  region is 
           : on + strand, else it's on - strand.
           : If $from2 is <= $to2 we assume second region is 
           : on + strand, else it's on - strand.
           : If regions are on opposite strand, return 0.
  Args     : $from1: start point of first region (maybe < or > than $to1)
           : $to1:   end   point of first region
           : $from2: start point of second region (maybe < or > than $to2)
           : $to2:   end   point of second region
  Returns  : Fractional overlap, defined as nres_overlap / minL
             where minL is minimum length of two regions
=cut

sub overlap_fraction {
    my($from1, $to1, $from2, $to2) = @_;
    
    my($a1, $b1, $strand1, $a2, $b2, $strand2);

    if($from1 <= $to1) { $a1 = $from1; $b1 = $to1;   $strand1 = 1;  }
    else               { $a1 = $to1;   $b1 = $from1; $strand1 = -1; }

    if($from2 <= $to2) { $a2 = $from2; $b2 = $to2;   $strand2 = 1;  }
    else               { $a2 = $to2;   $b2 = $from2; $strand2 = -1; }
    
    if($strand1 != $strand2) { 
	return 0.; 
    }

    my $L1 = $b1 - $a1 + 1;
    my $L2 = $b2 - $a2 + 1;
    my $minL = _min($L1, $L2);
    my $D    = overlap_nres_strict($a1, $b1, $a2, $b2);
    # printf STDERR "D: $D minL: $minL\n";
    return $D / $minL;
}

=head2 overlap_nres_or_full

  Title    : overlap_nres_or_full
  Incept   : EPN, Thu Aug  8 18:41:16 2013
  Usage    : overlap_nres($from1, $to1, $from2, $to2)
  Function : Returns number of residues of overlap between two regions.
           : If $from1 is <= $to1 we assume first region is 
           : on + strand, else it's on - strand.
           : If $from2 is <= $to2 we assume second region is 
           : on + strand, else it's on - strand.
           : If regions are on opposite strand, return 0.
  Args     : $from1: start point of first region (maybe < or > than $to1)
           : $to1:   end   point of first region
           : $from2: start point of second region (maybe < or > than $to2)
           : $to2:   end   point of second region
  Returns  : Number of residues of overlap, or -1 if the overlap is complete
             (complete overlap: entire shorter sequence is contained within longer sequence).
=cut

sub overlap_nres_or_full {
    my($from1, $to1, $from2, $to2) = @_;
    
    my($a1, $b1, $strand1, $a2, $b2, $strand2);

    if($from1 <= $to1) { $a1 = $from1; $b1 = $to1;   $strand1 = 1;  }
    else               { $a1 = $to1;   $b1 = $from1; $strand1 = -1; }

    if($from2 <= $to2) { $a2 = $from2; $b2 = $to2;   $strand2 = 1;  }
    else               { $a2 = $to2;   $b2 = $from2; $strand2 = -1; }
    
    if($strand1 != $strand2) { 
	return 0.; 
    }

    my $L1 = $b1 - $a1 + 1;
    my $L2 = $b2 - $a2 + 1;
    my $minL = _min($L1, $L2);
    my $D    = overlap_nres_strict($a1, $b1, $a2, $b2);
    # printf STDERR "D: $D minL: $minL\n";
    if($D == $minL) { return -1; } # complete overlap, special case: return -1
    else            { return $D; } # non-complete overlap, return nres overlap
}


=head2 overlap_nres_strict

  Title    : overlap_nres_strict
  Incept   : EPN, Thu Jan 31 08:50:55 2013
  Usage    : overlap_nres_strict($from1, $to1, $from2, $to2)
  Function : Returns number of overlapping residues of two regions.
  Args     : $from1: start point of first region (must be <= $to1)
           : $to1:   end   point of first region
           : $from2: start point of second region (must be <= $to2)
           : $to2:   end   point of second region
  Returns  : Number of residues that overlap between the two regions.

=cut

sub overlap_nres_strict {
    my ($from1, $to1, $from2, $to2) = @_;
    
    if($from1 > $to1) { croak "overlap_nres_strict(), from1 > to1\n"; }
    if($from2 > $to2) { croak "overlap_nres_strict(), from2 > to2\n"; }

    my $minlen = $to1 - $from1 + 1;
    if($minlen > ($to2 - $from2 + 1)) { $minlen = ($to2 - $from2 + 1); }

    # Given: $from1 <= $to1 and $from2 <= $to2.

    # Swap if nec so that $from1 <= $from2.
    if($from1 > $from2) { 
	my $tmp;
	$tmp   = $from1; $from1 = $from2; $from2 = $tmp;
	$tmp   =   $to1;   $to1 =   $to2;   $to2 = $tmp;
    }

    # 3 possible cases:
    # Case 1. $from1 <=   $to1 <  $from2 <=   $to2  Overlap is 0
    # Case 2. $from1 <= $from2 <=   $to1 <    $to2  
    # Case 3. $from1 <= $from2 <=   $to2 <=   $to1
    if($to1 < $from2) { return 0; }                    # case 1
    if($to1 <   $to2) { return ($to1 - $from2 + 1); }  # case 2
    if($to2 <=  $to1) { return ($to2 - $from2 + 1); }  # case 3
    croak "unforeseen case in _overlap_nres_strict $from1..$to1 and $from2..$to2";
}

#-------------------------------------------------------------------------------

=head2 log_output_rfam_banner

  Title    : log_output_rfam_banner
  Incept   : EPN, Thu Aug 15 14:44:26 2013
  Usage    : Bio::Rfam::Utils::log_output_rfam_banner($fh, $executable, $banner, $also_stdout)
  Function : Outputs Rfam banner (for rfmake/rfsearch) to $fh and optionally stdout.
  Args     : $fh:          file handle to output to
           : $executable:  command used to execute program (e.g. rfsearch.pl)
           : $banner:      one-line summary of program
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_rfam_banner { 
  my ($fh, $executable, $banner, $also_stdout) = @_;

  my $str;
  $str = sprintf ("# %s :: %s\n", Bio::Rfam::Utils::file_tail($executable), $banner);
  print $fh $str; if($also_stdout) { print $str; }
  #printf $fp ("# RFAM\n");
  #printf $fp ("# COPYRIGHT INFO GOES HERE\n");
  #printf $fp ("# LICENSE INFO GOES HERE\n");
  log_output_divider($fh, $also_stdout);

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_divider

  Title    : log_output_divider
  Incept   : EPN, Mon Aug 19 09:45:26 2013
  Usage    : Bio::Rfam::Utils::log_output_divider($fh, $also_stdout)
  Function : Outputs a divider line to $fh and optionally stdout.
  Args     : $fh:          file handle to output to
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_divider { 
  my ($fh, $also_stdout) = @_;

  my $str = "# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n";
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_header

  Title    : log_output_header
  Incept   : EPN, Thu Aug 15 14:51:34 2013
  Usage    : Bio::Rfam::Utils::log_output_header($fh, $user, $date, $dbchoice, $also_stdout);
  Function : Outputs Rfam header (for rfmake/rfsearch) to $fh and optionally stdout.
  Args     : $fh:          file handle to output to
           : $user:        name of user
           : $date:        date of execution
           : $dbchoice:    string indicating what DB is being used (e.g. 'r79rfamseq')
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_header { 
  my ($fh, $user, $date, $dbchoice, $also_stdout) = @_;

  my $str;
  $str = sprintf ("# user:               %s\n", $user);
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# date:               %s\n", $date);
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# pwd:                %s\n", getcwd);
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# db:                 %s\n", $dbchoice);
  print $fh $str; if($also_stdout) { print $str; }
  $str = ("# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n");
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_progress_column_headings

  Title    : log_output_progress_column_headings
  Incept   : EPN, Thu Aug 15 14:51:30 2013
  Usage    : Bio::Rfam::Utils::log_output_progress_column_headings($fh, $also_stdout);
  Function : Outputs Rfam header (for rfmake/rfsearch) to $fh and optionally stdout.
  Args     : $fh:          file handle to output to
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_progress_column_headings { 
  my ($fh, $also_stdout) = @_;

  my $str;
  $str = "#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = "# per-stage progress:\n#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s\n", "stage",           "type",       "\#finished", "\#running",  "\#waiting",  "stage-time");
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s\n", "===============", "==========", "==========", "==========", "==========", "==========");
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_progress_skipped

  Title    : log_output_progress_skipped
  Incept   : EPN, Thu Aug 15 14:53:06 2013
  Usage    : Bio::Rfam::Utils::log_output_progress_skipped($fh, $stage, $also_stdout);
  Function : Outputs line indicating a stage was skipped.
  Args     : $fh:          file handle to output to
           : $stage:       name of stage
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_progress_skipped { 
  my ($fh, $stage, $also_stdout) = @_;

  my $str = sprintf ("  %-15s  %-10s  %10s  %10s  %10s  %10s\n", $stage, "skipped", "-", "-", "-", "-");
  print $fh $str; if($also_stdout) { print $str; }
  
  return;
}  

#-------------------------------------------------------------------------------

=head2 log_output_progress_local

  Title    : log_output_progress_local
  Incept   : EPN, Thu Aug 15 14:52:12 2013
  Usage    : Bio::Rfam::Utils::log_output_progress_local_finished($fh, $stage, $run_secs, $nrunning, $nfinished, $extra_note, $also_stdout);
  Function : Outputs line indicating progress of script.
  Args     : $fh:          file handle to output to
           : $stage:       name of stage
           : $run_secs:    number of seconds script has been running
           : $nrunning:    number of jobs running (or about to be)
           : $nfinished:   number of jobs finished
           : $extra_note:  note to add at end of line ("" for none) 
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_progress_local { 
  my ($fh, $stage, $run_secs, $nrunning, $nfinished, $extra_note, $also_stdout) = @_;

  if($extra_note ne "") { $extra_note = "  " . $extra_note; }
  my $str = sprintf ("  %-15s  %-10s  %10s  %10s  %10s  %10s%s\n", $stage, "local", $nfinished, $nrunning, "0", Bio::Rfam::Utils::format_time_string($run_secs), $extra_note);
  print $fh $str; if($also_stdout) { print $str; }
  
  return;
}  

#-------------------------------------------------------------------------------

=head2 log_output_file_summary_column_headings

  Title    : log_output_file_summary_column_headings
  Incept   : EPN, Thu Aug 15 14:54:22 2013
  Usage    : Bio::Rfam::Utils::log_output_file_summary_column_headings($fh, $stage, $run_secs, $also_stdout);
  Function : Outputs line indicating progress of script.
  Args     : $fh:          file handle to output to
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_file_summary_column_headings { 
  my ($fh, $also_stdout) = @_;

  my $str;
  $str = "#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = "# Output file summary:\n#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-12s    %-60s\n", "file name",  "description");
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-12s    %-60s\n", "============", "============================================================");
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_file_summary

  Title    : log_output_file_summary
  Incept   : EPN, Thu Aug 15 14:56:38 2013
  Usage    : Bio::Rfam::Utils::log_output_file_summary($fh, $filename, $desc, $also_stdout);
  Function : Outputs line indicating progress of script.
  Args     : $fh:          file handle to output to
           : $filename:    name of output file
           : $desc:        description of file, to print
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_file_summary { 
  my ($fh, $filename, $desc, $also_stdout) = @_;

  my $str = sprintf ("  %-12s    %-60s\n", $filename, $desc);
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_timing_summary_column_headings

  Title    : log_output_timing_summary_column_headings
  Incept   : EPN, Thu Aug 15 14:57:51 2013
  Usage    : Bio::Rfam::Utils::log_output_timing_summary_colum_headings($fh, $also_stdout);
  Function : Outputs column headings for timing summary
  Args     : $fh:          file handle to output to
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_timing_summary_column_headings { 
  my ($fh, $also_stdout) = @_;

  my $str;
  $str = "#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = "# Timing summary:\n#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s\n", "stage",          "wall time",  "ideal time",  "cpu time",   "wait time",  "efficiency");
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s\n", "==============", "==========", "==========", "==========", "==========", "==========");
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_timing_summary

  Title    : log_output_timing_summary
  Incept   : EPN, Thu Aug 15 14:59:21 2013
  Usage    : Bio::Rfam::Utils::log_output_timing_summary($fh, $also_stdout);
  Function : Outputs timing summary
  Args     : $fh:           file handle to output to
           : $stage:        stage 
           : $wall_secs:    number of seconds elapsed
           : $tot_cpu_secs: total number of CPU seconds reported
           : $wait_secs:    total number of seconds waiting in queue
           : $max_elp_secs: slowest jobs maximum elapsed seconds time
           : $also_stdout:  '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_timing_summary { 
  my ($fh, $stage, $wall_secs, $tot_cpu_secs, $wait_secs, $max_elp_secs, $also_stdout) = @_;

  my $efficiency = 1.0;
  if($wall_secs > 0 && ($wall_secs > $max_elp_secs)) { 
    $efficiency = $max_elp_secs / $wall_secs;
  }
  my $str = sprintf ("  %-15s  %10s  %10s  %10s  %10s  %10.2f\n",
                     $stage, 
                     Bio::Rfam::Utils::format_time_string($wall_secs),
                     Bio::Rfam::Utils::format_time_string($max_elp_secs),
                     Bio::Rfam::Utils::format_time_string($tot_cpu_secs),
                     ($wait_secs eq "-") ? "-" : Bio::Rfam::Utils::format_time_string($wait_secs),
                     $efficiency);
  print $fh $str; if($also_stdout) { print $str; }

  return;
}

#-------------------------------------------------------------------------------

=head2 file_tail

  Title    : file_tail
  Incept   : EPN, Thu Apr  4 05:45:14 2013
  Usage    : file_tail($filePath)
  Function : Extract filename, removing path prefix.
           : Based on easel''s esl_FileTail().
           :     '/foo/bar/baz.1' becomes 'baz.1';
           :     'foo/bar'        becomes 'bar'; 
           :     'foo'            becomes 'foo'; and
           :     '/'              becomes the empty string.
  Args     : $filePath: full path to file
  Returns  : file name without path prefix.

=cut

sub file_tail { 
  my ($filePath) = @_;
  
  $filePath =~ s/^.+\///;
  return $filePath;
}

#-------------------------------------------------------------------------------

=head2 printToFileAndStdout

  Title    : printToFileAndStdout
  Incept   : EPN, Wed Apr 24 09:08:18 2013
  Usage    : printToFileAndStdout($str)
  Function : Print string to a file handle and to stdout.
  Args     : $fh:  file handle to print to
           : $str: string to print
  Returns  : void

=cut

sub printToFileAndStdout {
  my ($fh, $str) = @_;

  print $fh $str;
  print $str;

  return;
}

#-------------------------------------------------------------------------------

=head2 youngerThan

  Title    : youngerThan
  Incept   : EPN, Thu Aug 15 15:34:39 2013
  Usage    : Bio::Rfam::Utils::youngerThan($file1, $file2)
  Function : Returns '1' if $file1 was created after $file2, else returns 0
  Args     : $file1: name of file 1
           : $file2: name of file 2
  Returns  : '1' if $file1 was created after $file2, else 0

=cut


sub youngerThan {
  my ($file1, $file2) = @_;

  if( -M $file1 <= -M $file2 ) { 
    return 1; 
  }
  return 0;
}

#-------------------------------------------------------------------------------

=head2 checkStderrFile

  Title    : checkStderrFile
  Incept   : EPN, Tue Apr 30 01:20:50 2013
  Usage    : checkStderrFile($config->location, $calibrate_errO)
  Function : Check output printed to STDERR in location-dependent. 
           : If anything looks like a real error, then die.
  Args     : $location, $errFile
  Returns  : void

=cut

sub checkStderrFile { 
  my ($location, $errFile) = @_;

  if(-s $errFile) { 
    if($location eq "JFRC") { 
      die "Error output, see $errFile";
    }
    elsif($location eq "EBI") { 
      open(IN, $errFile) || die "ERROR unable to open $errFile";
      while(my $line = <IN>) { 
        if($line !~ m/^Warning/) {
          die "Error output, see $errFile";
        }
      }
      close(IN);
    }
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 _max

  Title    : _max
  Incept   : EPN, Thu Jan 31 08:55:18 2013
  Usage    : _max($a, $b)
  Function : Returns maximum of $a and $b.
  Args     : $a: scalar, usually a number
           : $b: scalar, usually a number
  Returns  : Maximum of $a and $b.

=cut

sub _max {
  return $_[0] if @_ == 1;
  $_[0] > $_[1] ? $_[0] : $_[1]
}

#-------------------------------------------------------------------------------

=head2 _min

  Title    : _min
  Incept   : EPN, Thu Jan 31 08:56:19 2013
  Usage    : _min($a, $b)
  Function : Returns minimum of $a and $b.
  Args     : $a: scalar, usually a number
           : $b: scalar, usually a number
  Returns  : Minimum of $a and $b.

=cut

sub _min {
  return $_[0] if @_ == 1;
  $_[0] < $_[1] ? $_[0] : $_[1]
}

#-------------------------------------------------------------------------------

=head1 AUTHOR

Sarah Burge, swb@ebi.ac.uk
Eric Nawrocki, nawrocki@ebi.ac.uk

=head1 COPYRIGHT

Copyright (c) 2013: European Bioinformatics Institute

Authors: Sarah Burge swb@ebi.ac.uk, Eric Nawrocki nawrocki@ebi.ac.uk

This is based on code taken from the Rfam modules at the Sanger institute.

This is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <http://www.gnu.org/licenses/>.

=cut

1;



