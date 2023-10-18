package Bio::Rfam::Utils;

#TODO: add pod documentation to all these functions

#Occasionally useful Rfam utilities

use strict;
use warnings;
use Sys::Hostname;
use File::stat;
use File::Spec;
use Carp;

use Digest::MD5 qw(md5_hex);
use LWP::Simple;
use JSON qw( decode_json );
use XML::LibXML;
use Time::HiRes qw(usleep);

use Cwd;
use Data::Dumper;
use Mail::Mailer;
use File::Copy;
use vars qw( @ISA
             @EXPORT
);

our $FASTATEXTW = '60';    # 60 characters per line in FASTA seq output

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
  if($? != 0) { croak "$cmd failed"; }
  return;
}

#-------------------------------------------------------------------------------

=head2 submit_nonmpi_job

  Title    : submit_nonmpi_job()
  Incept   : EPN, Tue Apr  2 05:59:40 2013
  Usage    : submit_nonmpi_job($config, $cmd, $jobname, $errPath, $ncpu, $reqMb, $exStr)
  Function : Submits non-MPI job defined by command $cmd.
           : Submission syntax depends on $config->location and 
           : config->scheduler values.
           : We do *not* wait for job to finish. Caller
           : must do that, probably with wait_for_cluster().
  Args     : $config:   Rfam config, with 'location' and 'scheduler'
           : $cmd:      command to run
           : $jobname:  name for job
           : $errPath:  path for stderr output
           : $ncpu:     number of CPUs to run job on, can be undefined if location eq "JFRC"
           : $reqMb:    required number of Mb for job, can be undefined if location eq "JFRC"
           : $exStr:    extra string to add to qsub/sub command
           : $queue:    queue to submit to, "" for default, 'p' = "production", 'r' = "research";
  Returns  : void
  Dies     : If MPI submit command fails.

=cut

sub submit_nonmpi_job {
  my ($config, $cmd, $jobname, $errPath, $ncpu, $reqMb, $exStr, $queue) = @_;

  my $submit_cmd = "";
  if(defined $queue && $queue eq "p") { $queue = "production"; }
  if(defined $queue && $queue eq "r") { $queue = "research"; }

  if($config->location eq "EBI") {
    if(! defined $ncpu)  { die "submit_nonmpi_job(), location is EBI, but ncpu is undefined"; }
    if(! defined $reqMb) { die "submit_nonmpi_job(), location is EBI, but reqMb is undefined"; }

    if($config->scheduler eq "slurm") {
      $submit_cmd = "sbatch ";
      if(defined $exStr && $exStr ne "") { $submit_cmd .= "$exStr "; }
      $submit_cmd .= "-c $ncpu -J $jobname -o /dev/null -e $errPath --mem-per-cpu=$reqMb --time=48:00:00 --wrap \"$cmd\" > /dev/null";
    }
    else { # lsf
      $submit_cmd = "bsub ";
      if(defined $exStr && $exStr ne "") { $submit_cmd .= "$exStr "; }
      if(defined $queue && $queue ne "") {
        $submit_cmd .= "-q $queue ";
      }
      else {
        $submit_cmd .= "-q research ";
      }
      $submit_cmd .= "-n $ncpu -J $jobname -o /dev/null -e $errPath -M $reqMb -R \"rusage[mem=$reqMb]\" \"$cmd\" > /dev/null";
    }
  }
  elsif($config->location eq "CLOUD"){
    # temporarily minimize memory to 6GB only to work with the test cloud
#    if ($reqMb >= 24000){
#      $reqMb = 6000;
#    }
    $submit_cmd = "/Rfam/software/bin/rfkubesub.py \"$cmd\" $ncpu $reqMb $jobname";
  }
  elsif($config->location eq "JFRC") {
    my $batch_opt = "";
    if(defined $ncpu && $ncpu > 1) { $batch_opt = "-pe batch $ncpu"; }
    $submit_cmd = "qsub ";
    if(defined $exStr && $exStr ne "") { $submit_cmd .= "$exStr "; }
    # set -l option specifying a queue
    if(defined $queue && $queue ne "") { $submit_cmd .= "-l $queue=true "; }
#    else                               { $submit_cmd .= "-q new.q "; }
    else                               { $submit_cmd .= ""; }
    $submit_cmd .= " -N $jobname -o /dev/null -e $errPath $batch_opt -b y -cwd -V \"$cmd\" > /dev/null";
  }
  # local command
  elsif($config->location eq ""){
    $submit_cmd = $cmd
  }
  else {
    die "ERROR unknown location $config->location in submit_nonmpi_job()";
  }

  # actually submit job
  #print STDERR ("submit cmd: $submit_cmd\n");
  system($submit_cmd);
  if($? != 0) { die "Non-MPI submission command $submit_cmd failed"; }

  return;
}

# -------------------------------------------------------------------------------

=head2 submit_mpi_job

  Title    : submit_mpi_job()
  Incept   : EPN, Tue Apr  2 05:59:40 2013
  Usage    : submit_mpi_job($config, $cmd, )
  Function : Submits MPI job defined by command $cmd.
           : MPI submission syntax depends on $config->location and 
           : config->scheduler values.
           : We do *not* wait for job to finish. Caller
           : must do that, probably with wait_for_cluster().
  Args     : $config:   Rfam config, with 'location' and 'scheduler'
           : $cmd:      command to run
           : $jobname:  name for job
           : $errPath:  path for stderr output
           : $nproc:    number of MPI processors to use
           : $reqMb:    required number of Mb for job, can be undefined if location eq "JFRC"
           : $queue:    queue to submit to, "" for default, ignored if location eq "EBI"
  Returns  : void
  Dies     : If MPI submit command fails.

=cut

sub submit_mpi_job {
  my ($config, $cmd, $jobname, $errPath, $nproc, $reqMb, $queue) = @_;

  my $submit_cmd = "";
  if($config->location eq "EBI") {
    # EPN: for some reason, this 'module' command fails inside perl..., I think it may be unnecessary because it's in my .bashrc
    #my $prepcmd = "module load openmpi-x86_64";
    #system($prepcmd);
    #if($? != 0) { die "MPI prep command $prepcmd failed"; }

    # Need to use MPI queue ($queue is irrelevant)
    # TEMPORARILY USING research queue and span[ptile=8] as per Asier Roa's instructions, see email ("mpi jobs on cluster")
    # forwarded from Jen, on 08.27.13.
    if($config->scheduler eq "slurm") {
      $submit_cmd .= "sbatch -J $jobname -e $errPath -c $nproc --mem-per-cpu=$reqMb --time=48:00:00 --wrap \"mpirun -np $nproc $cmd\" > /dev/null";
    }
    else { # lsf
      $submit_cmd = "bsub -J $jobname -e $errPath -M $reqMb -q mpi -I -n $nproc -R \"span[ptile=2]\" -a openmpi mpirun -np $nproc -mca btl tcp,self $cmd";
      # ORIGINAL COMMAND (I BELIEVE WE WILL REVERT TO THIS EVENTUALLY):
      # $submit_cmd = "bsub -J $jobname -e $errPath -q mpi -I -n $nproc -a openmpi mpirun.lsf -np $nproc -mca btl tcp,self $cmd";
    }
  }
  elsif($config->location eq "JFRC") {
    my $queue_opt = "";
    if($queue ne "") { $queue_opt = "-l $queue=true "; }
    $submit_cmd = "qsub -N $jobname -e $errPath -o /dev/null -b y -cwd -V -pe impi $nproc " . $queue_opt . "\"mpirun -np $nproc $cmd\" > /dev/null";
  }
  elsif ($config->location eq "CLOUD"){
  	die "ERROR: MPI unavailable on CLOUD. Consider using -cnompi option";
  }
  else {
    die "ERROR unknown location $config->location in submit_mpi_job()";
  }

  # actually submit job
  # print STDERR "about to execute system call: \"$submit_cmd\"\n";
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
             : See an alternative function that serves the same purpose:
             : 'wait_for_cluster_light' but that uses the expensive
             : 'qstat', 'bjobs' or 'squeue' calls less frequently.
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
    Args     : $config:         Rfam config, with 'location' and 'scheduler'
             : $username:       username the cluster jobs belong to
             : $jobnameAR:      ref to array of list of job names on cluster
             : $outnameAR:      ref to array of list of output file names, one per job
             : $success_string: string expected to exist in each output file
             : $program:        name of program running, if "": do not print updates
             : $outFH:          output file handle for updates, if "" only print to STDOUT
             : $extra_note:     extra information to output with progress, "" for none
             : $max_minutes:    max number of minutes to wait, -1 for no limit
             : $do_stdout:      1 to print updates to stdout, 0 not to
             :
    Returns  : Maximum number of seconds any job spent waiting in queue, rounded down to
             : nearest 10 seconds.
    Dies     : Cases (2) or (3) listed in "Function" section above.

=cut

sub wait_for_cluster {
  my ($config, $username, $jobnameAR, $outnameAR, $success_string, $program, $outFH, $extra_note, $max_minutes, $do_stdout) = @_;

  my $start_time = time();

  my $n = scalar(@{$jobnameAR});
  my $i;
  if($extra_note ne "") { $extra_note = "  " . $extra_note; }

  # sanity check
  if(scalar(@{$outnameAR}) != $n) { die "wait_for_cluster(), internal error, number of elements in jobnameAR and outnameAR differ"; }

  # TODO: update this subroutine to work with 'squeue'
  # modify username > 7 characters and job names > 10 characters if we're at EBI, because bjobs truncates these
  if($config->location eq "EBI") {
    if(length($username) > 7) {
      $username = substr($username, 0, 7); # bjobs at EBI only prints first 7 letters of username
    }
    for($i = 0; $i < $n; $i++) {
      if(length($jobnameAR->[$i]) > 10) { # NOTE: THIS WILL CHANGE THE VALUES IN THE ACTUAL ARRAY jobnameAR POINTS TO
        $jobnameAR->[$i] = "*" . substr($jobnameAR->[$i], -9);
      }
    }
  }
  elsif($config->location ne "JFRC") {
    die "ERROR in wait_for_cluster, unrecognized location: $config->location";
  }

  my $sleep_nsecs = 60;  # we'll call qstat/bjobs every 5 seconds
  my $print_freq  = 1; # print update every $print_freq loop iterations (about every $print_freq*$sleep_nsecs seconds)
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
    if   ($config->location eq "JFRC") { @infoA = split("\n", `qstat`); }
    elsif($config->location eq "EBI")  { @infoA = split("\n", `bjobs`); }

    for($i = 0; $i < $n; $i++) { $ininfoA[$i] = 0; }
    $nrunning  = 0;
    $nwaiting  = 0;
    foreach $line (@infoA) {
      if($line =~ m/^\s*\d+\s+/) {
        $line =~ s/^\s*//;
        @elA = split(/\s+/, $line);
        if($config->location eq "JFRC") {
          #1232075 4.79167 QLOGIN     davisf       r     03/25/2013 14:24:11 f02.q@f02u09.int.janelia.org                                      8
          # 396183 10.25000 QLOGIN     nawrockie    r     07/26/2013 10:10:41 new.q@h02u19.int.janelia.org                                      1
          # 565685 0.00000 c.25858    nawrockie    qw    08/01/2013 15:18:55                                                                  81
          ($jobname, $uname, $status) = ($elA[2], $elA[3], $elA[4]);
        }
        elsif($config->location eq "EBI") {
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
            if($config->location eq "JFRC") {
              if($status eq "r")     { $nrunning++; }
              elsif($status =~ m/E/) { die "wait_for_cluster(), internal error, qstat shows Error status: $line"; }
              else                   { $nwaiting++; }
            }
            elsif($config->location eq "EBI") {
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
        if($do_stdout) { print STDOUT $outstr; }
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

=head2 wait_for_cluster_light

    Title    : wait_for_cluster_light
    Incept   : EPN, Sat Mar 30 07:01:24 2013
    Usage    : wait_for_cluster_light($jobnameAR, $outnameAR, $success_string, $program, $outFH, $max_minutes)
    Function : Waits for specific job(s) to finish running on cluster
             : and verifies their output.
             : The job names are listed in $jobnameAR. Each
             : job will produce an output file listed in @{$outnameAR}
             : and an stderr error file listed in @{$errnameAR}.
             : This function (the '_light' version) determines which jobs
             : are finished mostly using the existence of error files and
             : by looking for the success string in those error files
             : and tries to use expensive 'qstat', 'bjobs' or 'squeue' calls infrequently.
             : The non-light version (wait_for_cluster()) calls 'qstat'/'bjobs'/'squeue'
             : once every minute.
             :
             : If $max_minutes is defined and != -1, we will die if all jobs
             : fail to successfully complete within $max_minutes minutes.
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
    Args     : $config:         Rfam config, with 'location' and 'scheduler'
             : $username:       username the cluster jobs belong to
             : $jobnameAR:      ref to array of list of job names on cluster
             : $outnameAR:      ref to array of list of output file names, one per job
             : $errnameAR:      ref to array of list of err file names, one per job
             : $success_string: string expected to exist in each output file
             : $program:        name of program running, if "": do not print updates
             : $outFH:          output file handle for updates, if "" only print to STDOUT
             : $extra_note:     extra information to output with progress, "" for none
             : $max_minutes:    max number of minutes to wait, -1 for no limit
             : $do_stdout:      1 to print updates to stdout, 0 not to
             :
    Returns  : Maximum number of seconds any job spent waiting in queue, rounded down to
             : nearest 10 seconds.
    Dies     : Cases (2) or (3) listed in "Function" section above.

=cut

sub wait_for_cluster_light {
  my ($config, $username, $jobnameAR, $outnameAR, $errnameAR, $success_string, $program, $outFH, $extra_note, $max_minutes, $do_stdout) = @_;

  my $start_time = time();
  my $n = scalar(@{$jobnameAR});
  my $i;
  if($extra_note ne "") { $extra_note = "  " . $extra_note; }

  # sanity check - limit this to EBI and JFRC clusters only

  if(scalar(@{$outnameAR}) != $n) { die "wait_for_cluster_light(), internal error, number of elements in jobnameAR and outnameAR differ"; }
  if(scalar(@{$errnameAR}) != $n) { die "wait_for_cluster_light(), internal error, number of elements in jobnameAR and errnameAR differ"; }

  # modify username > 7 characters and job names > 10 characters if we're using lsf   at EBI, because bjobs truncates these
  # if we are using slurm we will use the --format option to squeue to deal with the fact that squeue truncates job names to 8 chars by default
  if($config->location eq "EBI") {
    if($config->scheduler ne "slurm") { 
      if(length($username) > 7) {
        $username = substr($username, 0, 7); # bjobs at EBI only prints first 7 letters of username
      }
      for($i = 0; $i < $n; $i++) {
        if(length($jobnameAR->[$i]) > 10) { # NOTE: THIS WILL CHANGE THE VALUES IN THE ACTUAL ARRAY jobnameAR POINTS TO!
          $jobnameAR->[$i] = "*" . substr($jobnameAR->[$i], -9);
        }
      }
    }
  }
  elsif(($config->location ne "JFRC") && ($config->location ne "CLOUD")) {
    die "ERROR in wait_for_cluster_light, unrecognized location: $config->location";
  }

  my $sleep_nsecs = 30;  # we'll look at file system every 30 seconds
  my $print_freq  = 2; # print update every 2 loop iterations (about every 2*$sleep_nsecs seconds)
  my @ininfoA = (); # array to hold information about which job is still in the queue and running
  my @infoA  = ();
  my @elA    = ();
  my $max_wait_secs = 0;
  my ($minutes_elapsed, $line, $uname, $jobname, $status);
  sleep(2);

  my $ncycle     = 0; # number of cycles waited since last cluster check
  my $ncycle_tot = 0; # total number of cycles waited
  my $ncycle_thresh = 10; # we'll only check cluster with 'qstat' once every 5 minutes
  my $ncluster_check = 0; # number of times we've used 'qstat' or 'bjobs'
  my $do_cluster_check = 0; # should we use 'qstat' or 'bjobs' this cycle?
  my @successA = ();   # [0..$n-1]: '1' if job is finished (tail of its output file contains $success_string) else '0'
  my @runningA  = ();  # [0..$n-1]: '1' if job is running (its error file does exist), else '0'
  my @waitingA  = ();  # [0..$n-1]: '1' if job is waiting (its error does not exists), else '0'
  my @finishedA  = (); # [0..$n-1]: '1' if job does not exist in the queue and so should be finished (revealed by 'qstat' or 'bjobs'), else '0'

  # initialize status buffers
  for($i = 0; $i < $n; $i++) {
    $finishedA[$i] = 0;
    $successA[$i] = 0;
    $runningA[$i] = 0;
    $waitingA[$i] = 1; # all jobs pending in the beginning
  }

  # initialize counters
  my $nsuccess = 0;
  my $nrunning = 0;
  my $nwaiting = $n;

  while($nsuccess != $n) {
    # determine if we should check the cluster using 'qstat/bjobs' to determine
    # which jobs are no longer in the queue, these should've all finished
    # successfully
    $do_cluster_check = 0;
    if((($ncycle == $ncycle_thresh) && ($nrunning > 0)) || # we've reached the threshold of number of times to wait before checking cluster and at least some jobs are not waiting, do it
       (($ncluster_check == 0) && ($ncycle > 0) && ($nwaiting == 0))) # we haven't checked the cluster at all yet, and all jobs appear to be running, do it
    {
      $do_cluster_check = 1;
    }

    #################################################
    # CLUSTER CHECK BLOCK
    #
    if($do_cluster_check) {
      #printf("checking the cluster with qstat/bjobs\n");
      sleep(rand(30)); # randomize wait time here, so all jobs started at same time don't run qstat/bjobs at exact same time
      $ncycle = 0; # reset to 0
      $ncluster_check++;
      if   ( $config->location eq "JFRC") {
        @infoA = split("\n", `qstat`);
      }
      elsif(($config->location eq "EBI") && ($config->scheduler eq "slurm")) {
        @infoA = split("\n", `squeue --format=\"%.8i %.9P %25j %10u %.8T %.12M %9N\"`);
        # --format used to specify job names can be 25 characters, instead of default 8
      } 
      elsif( $config->location eq "EBI")  { # lsf
        @infoA = split("\n", `bjobs`);
      }
      # Fetch all running jobs of a specific user
      elsif($config->location eq "CLOUD") {
        @infoA = split("\n", `kubectl get pods --selector=user=$username --selector=tier=backend`);
      }

      # initialize array
      for($i = 0; $i < $n; $i++) { $ininfoA[$i] = 0; }

      # parse job log
      foreach $line (@infoA) {
        if ($config->location ne "CLOUD"){
        if($line =~ m/^\s*\d+\s+/) {
          $line =~ s/^\s*//;
          @elA = split(/\s+/, $line);
          if($config->location eq "JFRC") {
            #1232075 4.79167 QLOGIN     davisf       r     03/25/2013 14:24:11 f02.q@f02u09.int.janelia.org                                      8
            # 396183 10.25000 QLOGIN     nawrockie    r     07/26/2013 10:10:41 new.q@h02u19.int.janelia.org                                      1
            # 565685 0.00000 c.25858    nawrockie    qw    08/01/2013 15:18:55                                                                  81
            ($jobname, $uname, $status) = ($elA[2], $elA[3], $elA[4]);
          } # closes JFRC if
          elsif(($config->location eq "EBI") && ($config->scheduler eq "slurm")) {
            #JOBID PARTITION NAME               USER          STATE         TIME NODELIST
            #35080251  standard rs.4002890-9       nawrocki    RUNNING         0:02 hl-codon-
            #35080252  standard rs.4002890-10      nawrocki    RUNNING         0:02 hl-codon-
            #35080253  standard ss.4002890-1       nawrocki    RUNNING         0:02 hl-codon-
            ($jobname, $uname, $status) = ($elA[2], $elA[3], $elA[4]);
            # print STDERR ("uname: $uname status: $status; jobname: $jobname\n");
          } # closes EBI + slurm elsif
          elsif($config->location eq "EBI") { # lsf 
            # jobid   uname   status queue     sub node    run node    job name   date
            # 5134531 vitor   RUN   research-r ebi-004     ebi5-037    *lection.R Apr 29 18:00
            # 4422939 stauch  PEND  research-r ebi-001                 *ay[16992] Apr 26 12:56
            ($uname, $status) = ($elA[1], $elA[2]);
            if($status eq "RUN") { $jobname = $elA[6]; }
            else                 { $jobname = $elA[5]; }
            #print STDERR ("uname: $uname status: $status; jobname: $jobname\n");
          } # closes EBI (and not slurm) elsif
          # no need to do this for CLOUD
          if($uname ne $username) { die "wait_for_cluster_light(), internal error, uname mismatch ($uname ne $username)"; }

          # look through our list of jobs and see if this one matches
          for($i = 0; $i < $n; $i++) { #5
            #printf("\t\tsuccess: %d\tininfo: %d\tmatch: %d\n", $successA[$i], $ininfoA[$i], ($jobnameAR->[$i] eq $jobname) ? 1 : 0);
            if((! $successA[$i]) &&              # job didn't successfully complete already
               (! $ininfoA[$i]) &&               # we didn't already find this job in the queue
               ($jobnameAR->[$i] eq $jobname)) { # jobname match
              $ininfoA[$i] = 1;
              $i = $n;
              
              # make sure job state is either pending, running or completing
              if(($config->location eq "JFRC") && ($status =~ m/E/)) { 
                die "wait_for_cluster_light(), internal error, qstat shows Error status: $line";
              }
              if($config->location eq "EBI") {
                if((! defined $config->scheduler) || ($config->scheduler ne "slurm")) {
                  if(($status ne "RUN") && ($status ne "PEND")) {
                    die "wait_for_cluster_light(), internal error, bjobs shows non-\"RUN\" and non-\"PEND\" status: $line";
                  }
                }
                elsif((defined $config->scheduler) && ($config->scheduler eq "slurm")) {
                  if(($status ne "RUNNING") && ($status ne "PENDING") && ($status ne "COMPLETING")) {
                    die "wait_for_cluster_light(), internal error, squeue shows non-\"RUNNING\", non-\"PENDING\" and non-\"COMPLETING\" status:\n$line";
                  }
                }
              }
            }
          } # EBI/JFRC for loop
        } # first line check here
      } # EBI/JFRC location if

      # CHECK THE JOBS RUNNING ON THE CLOUD
      else{

          $line =~ s/^\s*//;
          @elA = split(/\s+/, $line);
	  # example of kubectl get output
	  # -----
	  # NAME                                            READY   STATUS              RESTARTS   AGE
          # rfam-dev-entry-pod-deployment-689f678b4-58g6m   1/1     Running             0          24h
          # rfsearch-job-ikalvari-m5vxz                     0/1     Completed           0          4d
          # rfsearch-job-root-hzc28                         0/1     ContainerCreating   0          19m

          ($jobname, $status) = ($elA[0], $elA[2]);

	  # check if any of the running jobs matches those in the job array
          for($i = 0; $i < $n; $i++) { #5 - TODO: jobnameAR needs to be converted into a dictionary for faster processing
            if((! $successA[$i]) &&              # job didn't successfully complete already
                 (! $ininfoA[$i]) &&               # we didn't already find this job in the queue
                 (index($jobname, $jobnameAR->[$i]) != -1) && # jobname match
		 ($status ne "Completed")) { # look for a substring if on CLOUD - change this to ne if eq doesn't work
                  $ininfoA[$i] = 1; # job with jobname is still running or pending
                  $i = $n; # skip the rest of the computations
              # check if job is in error status, if it is, then exit
	      #
              if (($config->location eq "CLOUD") && ($status ne "Running" && $status ne "Pending" && $status ne "Completed" && $status ne "ContainerCreating")){ die "wait_for_cluster_light(), internal error, kubectl shows Error status: $line"; }
            } #internal if
          } # for loop
      } # cloud segment else
    } # parse job log loop

      # for any job not still in the queue, it should have successfully finished
      for($i = 0; $i < $n; $i++) {
        $finishedA[$i] = ($ininfoA[$i] == 0) ? 1 : 0;
	}
      sleep(60.); # sleep 1 minute after checking cluster to allow jobs that we think are finished to finish writing output files
    } # end of 'if($do_cluster_check)'

    # END OF CLUSTER CHECK BLOCK
    #################################################

    # ---------------------------------------------------------------------------------------------------------------------------

    # now go through each job and check whether its error and output files exist, for those jobs
    # that our most recent cluster check revealed should be finished (true if $finishedA[$i] is '1')
    # make sure they finished successfully - Skip this if on CLOUD

    for($i = 0; $i < $n; $i++){
      # sanity check
      if(($runningA[$i] + $waitingA[$i] + $successA[$i]) != 1) {
        die "wait_for_cluster_light() internal error, job $i runningA[$i]: $runningA[$i], waitingA[$i]: $waitingA[$i], successA[$i]: $successA[$i] (exactly 1 of these should be 1 and the others 0)";
      }

      if($successA[$i] == 0) {
        # if err file exists
        #    if output file exists
        #       if success string exists: then JOB FINISHED SUCCESSFULLY
        #       else: JOB IS RUNNING OR FAILED (check by consulting finishedA filled in CLUSTER CHECK BLOCK)
        #    else: JOB IS RUNNING FAILED (check by consulting finishedA filled in CLUSTER CHECK BLOCK)
        # else JOB IS WAITING OR FAILED (check by consulting finishedA filled in CLUSTER CHECK BLOCK)
        #
        if(-e $errnameAR->[$i]) {
          # First check for the following rare case:
          # finishedA[$i] is 1 (qstat/bjobs indicated the job is finished (no longer in queue))
          # but the expected output file either does not exist or is empty. If this happens, we wait
          # up to 20 minutes for it to appear, to guard against the real possibility that the file
          # is currently being written to but isn't visible to the file system yet).

	  if($finishedA[$i] && (! -s $outnameAR->[$i])) {
            my $nsleep = 0;
            while((! -s $outnameAR->[$i]) && ($nsleep < 20)) {
              sleep(60.);
              $nsleep++;
            }
          }

	  if(-e $outnameAR->[$i]) { # check if output file exists
            if(-s $outnameAR->[$i]) { # check if output file not empty
              # check for success string in tail output, if it's not there and $finishedA[$i] is 1 (qstat/bjobs indicated this job should be finished)
              # then wait a minute and check again (up to 10 times)
              my $ncheck = 0;
              while(($ncheck == 0) || ($finishedA[$i] == 1 && $ncheck < 20 && $successA[$i] == 0)) { # if finishedA[$i] is 1, we'll stay in this loop until we've found the $success_string or checked for it 10 times
                my $tail= `tail $outnameAR->[$i]`;
                foreach $line (split ('\n', $tail)) {
                  if($line =~ m/\Q$success_string/) {
                    $successA[$i] = 1;
                    $nsuccess++;
                    if($runningA[$i] == 1) { $runningA[$i] = 0; $nrunning--; }
                    if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
                    #printf("\tjob %2d finished successfully!\n", $i);
                    last;
                  }
                }
                $ncheck++;
                if($successA[$i] == 0) { # didn't find $success_string
                  sleep(60.);
                }
              }
              if($successA[$i] == 0) { # we didn't find the $success_string in the output
                if($finishedA[$i] == 1) { # if our cluster check revealed this job should be finished, then we waited 20 minutes and it still didn't have success, so die
                  die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but tail of expected output file $outnameAR->[$i] does not contain: $success_string\n";
                }
              }
            } #end of 'if(-s $outnameAR->[$i])'
            else { # $outfile exists but is empty, job is running or failed
              if($finishedA[$i] == 1) {
                die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but expected output file $outnameAR->[$i] is empty\n";
              }
              elsif($runningA[$i] == 0) {
                $runningA[$i] = 1;
                $nrunning++;
                if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
              }
            }
          } # end of 'if(-e $outnameAR->[$i])'
          else { # outfile doesn't exist, but errfile does, job is running or failed
            if($finishedA[$i] == 1) {
              die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but expected output file $outnameAR->[$i] does not exist\n";
            }
            elsif($runningA[$i] == 0) {
              $runningA[$i] = 1;
              $nrunning++;
              if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
            }
          }
        } # end of 'if(-e $errnameAR->[$i])'
        else { # err file doesn't exist yet, job is waiting (or failed) or job is running on cloud
          if ($config->location ne "CLOUD"){
          if($finishedA[$i] == 1) {
            die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but expected output ERROR file $errnameAR->[$i] does not exist\n";
          }
          elsif($waitingA[$i] != 1) {
            die "wait_for_cluster_light() internal error 2, job $i runningA[$i]: $runningA[$i], waitingA[$i]: $waitingA[$i], successA[$i]: $successA[$i] (exactly 1 of these should be 1 and the others 0)";
          }
        }
        # re-do outfile checks because on CLOUD
        else{ # running on Cloud
          if(-e $outnameAR->[$i]) { # check if output file exists
            if(-s $outnameAR->[$i]) { # check if output file not empty
              # check for success string in tail output, if it's not there and $finishedA[$i] is 1 (qstat/bjobs indicated this job should be finished)
              # then wait a minute and check again (up to 10 times)
              my $ncheck = 0;
              while(($ncheck == 0) || ($finishedA[$i] == 1 && $ncheck < 20 && $successA[$i] == 0)) { # if finishedA[$i] is 1, we'll stay in this loop until we've found the $success_string or checked for it 10 times
                my $tail= `tail $outnameAR->[$i]`;
		foreach $line (split ('\n', $tail)) {
		if($line =~ m/\Q$success_string/) {
                    $successA[$i] = 1;
                    $nsuccess++;
                    if($runningA[$i] == 1) { $runningA[$i] = 0; $nrunning--; }
                    if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
                    #printf("\tjob %2d finished successfully!\n", $i);
                    last;
                  }
                }
                $ncheck++;
                if($successA[$i] == 0) { # didn't find $success_string
                  sleep(60.);
                }
              }
              if($successA[$i] == 0) { # we didn't find the $success_string in the output
                if($finishedA[$i] == 1) { # if our cluster check revealed this job should be finished, then we waited 20 minutes and it still didn't have success, so die
                  die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but tail of expected output file $outnameAR->[$i] does not contain: $success_string\n";
                }
              }
            } #end of 'if(-s $outnameAR->[$i])'
            else { # $outfile exists but is empty, job is running or failed
              if($finishedA[$i] == 1) {
		      #die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but expected output file $outnameAR->[$i] is empty\n";
              }
              elsif($runningA[$i] == 0) {
                $runningA[$i] = 1;
                $nrunning++;
                if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
              }
            }
          } # end of 'if(-e $outnameAR->[$i])'
          else { # outfile doesn't exist, but errfile does, job is running or failed
            if($finishedA[$i] == 1) {
		    #die "wait_for_cluster_light() job $i finished according to qstat/bjobs, but expected output file $outnameAR->[$i] does not exist\n";
            }
            elsif($runningA[$i] == 0) {
              $runningA[$i] = 1;
              $nrunning++;
              if($waitingA[$i] == 1) { $waitingA[$i] = 0; $nwaiting--; }
            }
          }
        }
        }
	   }
  } # end of 'for($i = 0; $i < $n; $i++)'

    if($nwaiting > 0) { $max_wait_secs = time() - $start_time; }
    $minutes_elapsed = (time() - $start_time) / 60;
    if($program ne "") {
      if($nsuccess == $n || $ncycle_tot % $print_freq == 0) {
        my $outstr = sprintf("  %-15s  %-10s  %10s  %10s  %10s  %10s%s\n", $program, "cluster", $nsuccess, $nrunning, $nwaiting, Bio::Rfam::Utils::format_time_string(time() - $start_time), $extra_note);
        $extra_note = ""; # only print this once
        if($do_stdout) { print STDOUT $outstr; }
        if($outFH ne "") { print $outFH $outstr; }
      }
    }
    if(defined $max_minutes && $max_minutes != -1 && $minutes_elapsed > $max_minutes) { die "wait_for_cluster_light(), reached maximum time limit of $max_minutes minutes, exiting."; }
    # now wait for a while before reexamining
    if($nsuccess != $n) {
      sleep($sleep_nsecs);
      $ncycle++;
      $ncycle_tot++;
    }
  }
  return $max_wait_secs;
  # The only way we'll get here is if all jobs are finished
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

  return sprintf("%02d:%02d:%02d", $h, $m, int($seconds + 0.5));
}

#-------------------------------------------------------------------------------

=head2 delete_completed_k8s_jobs

  Title    : delete_completed_k8s_jobs()
  Incept   : IK, Wed Mar 6 20:08:10 2019
  Usage    : delete_completed_k8s_jobs($user, $tier)
  Function : Delete all k8s jobs of a specific
           : user.
  Args     : $user: user id
           : $tier: backend/frontend
  Returns  : void

=cut

sub delete_completed_k8s_jobs {
  my ($user, $tier) = @_;

  my $cmd = "kubectl delete jobs --selector=user=$user --selector=tier=$tier";
  run_local_command($cmd);

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

=head2 capitalize_token_in_taxstring

  Title    : capitalize_token_in_taxstring
  Incept   : EPN, Thu Apr 10 10:01:41 2014
  Usage    : capitalize_token_in_taxstring($taxstr, $level)
  Function : Given a taxonomy string capitalize a given token within it.
           : Tokens are delimited by ';'.
  Args     : $taxstr: the taxonomic string
           : $level:  the level of token to capitalize NOTE '0' means 1st token [0..ntok-1]
  Returns  : $taxstr with token number $level capitalize
  Dies     : If there are less than ($level+1) tokens in $taxstr.

=cut

sub capitalize_token_in_taxstring {
  my ($taxstr, $level) = @_;
  if(! defined $level) { die "ERROR, level not defined in capitalize_token_in_taxstring"; }

  my @elA = split(";", $taxstr);
  my $ntok = scalar(@elA);
  if($ntok < ($level+1)) { $level++; die "ERROR, trying to capitalize token number $level but only $ntok exist in $taxstr"; }

  my $ret_tok = "";
  for(my $i = 0; $i < $ntok; $i++) {
    if($level == $i) { $elA[$i] =~ tr/a-z/A-Z/; }
    $ret_tok .= $elA[$i];
    if($i < ($ntok-1)) { $ret_tok .= ";"; }
  }

  return $ret_tok;
}


#-------------------------------------------------------------------------------

=head2 pad_tokens_in_taxstring

  Title    : pad_tokens_in_taxstring
  Incept   : EPN, Mon Apr 28 11:38:15 2014
  Usage    : pad_tokens_in_tax_string($taxstr, $widthAR, $sepchar)
  Function : Given a taxonomy string and a width for each token, return a string
           : where each string is printed as a separate string of the proper
           : width, for pretty output formatting.
  Args     : $taxstr:   the taxonomic string
           : $widthAR:  ref to array of width for each token
           : $sepchar:  character to separate tokens (e.g. ';' '|' or ' ')
  Returns  : $taxstr with new desired spacing
  Dies     : if more tokens in $taxstr than widths in @{$widthAR}
=cut

sub pad_tokens_in_taxstring {
  my ($taxstr, $widthAR, $sepchar) = @_;

  my @elA = split(";", $taxstr);
  my $ntok = scalar(@elA);
  my $nwid = scalar(@{$widthAR});
  if($ntok > $nwid) { die "ERROR in pad_tokens_in_taxstring: $ntok tokens in taxstr, but only $nwid widths"; }
  my $retstr = "";
  for(my $i = 0; $i < $ntok; $i++) {
    $retstr .= sprintf("%-*s%s", $widthAR->[$i], $elA[$i], $sepchar);
  }
  return $retstr;
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
    my ($sqname) = $_[0];

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

=head2 overlap_nres_two_nse

  Title    : overlap_nres_two_nse
  Incept   : EPN, Mon Mar 31 11:17:20 2014
  Usage    : overlap_nres_two_nse($nse1, $nse2)
  Function : Returns number of residue overlap of two regions defined by
           : $nse1 and $nse2. Where $nse1 and $nse2 are both of
           : format "name/start-end".
  Args     : <nse1>: "name/start-end" for region 1
           : <nse2>: "name/start-end" for region 2
  Returns  : Number of residue overlap between region 1 and region 2
           : (This will be 0 if names are different for regions 1 and 2.)
           : (This will be 0 if regions are on different strands.)

=cut

sub overlap_nres_two_nse {
    my ($nse1, $nse2) = @_;

    my($is1, $n1, $s1, $e1, $str1) = nse_breakdown($nse1);
    if(! $is1) { croak "$nse1 not in name/start-end format"; }
    my($is2, $n2, $s2, $e2, $str2) = nse_breakdown($nse2);
    if(! $is2) { croak "$nse2 not in name/start-end format"; }

    if($n1   ne $n2)   { return 0; } #names don't match
    if($str1 ne $str2) { return 0; } #strands don't match

    my $nres_overlap = 0;
    ($nres_overlap, $str1, $str2) = overlap_nres_either_strand($s1, $e1, $s2, $e2);
    return $nres_overlap;
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

#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------

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

=head2 overlap_nres_either_strand

  Title    : overlap_nres_either_strand
  Incept   : EPN, Thu Oct 10 09:24:57 2013
  Usage    : overlap_nres_either_strand($from1, $to1, $from2, $to2)
  Function : Returns number of overlapping residues between two
           : regions, irrespective of strand. That is, if two
           : regions overlap by 10 residues but on opposite residues
           : we return 10. (overlap_nres_strict() would return 0.)
           : If $from1 is <= $to1 we assume first region is
           : on + strand, else it's on - strand.
           : If $from2 is <= $to2 we assume second region is
           : on + strand, else it's on - strand.
  Args     : $from1: start point of first region (must be <= $to1)
           : $to1:   end   point of first region
           : $from2: start point of second region (must be <= $to2)
           : $to2:   end   point of second region
  Returns  : $nres_overlap: number of residues that overlap between the two regions.
           : $strand1:      strand of region 1 ('1' if $from1 <= $to1, else '-1')
           : $strand2:      strand of region 2 ('1' if $from2 <= $to2, else '-1')
=cut

sub overlap_nres_either_strand {
    my ($from1, $to1, $from2, $to2) = @_;

    my ($strand1, $strand2, $tmpfrom1, $tmpto1, $tmpfrom2, $tmpto2);
    if($from1  <= $to1)  { $strand1 =  1; $tmpfrom1 = $from1; $tmpto1 = $to1;   }
    else                 { $strand1 = -1; $tmpfrom1 = $to1;   $tmpto1 = $from1; }
    if($from2  <= $to2)  { $strand2 =  1; $tmpfrom2 = $from2; $tmpto2 = $to2;   }
    else                 { $strand2 = -1; $tmpfrom2 = $to2;   $tmpto2 = $from2; }

    my $nres_overlap = overlap_nres_strict($tmpfrom1, $tmpto1, $tmpfrom2, $tmpto2);

    return($nres_overlap, $strand1, $strand2);
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
           : $dlen:        length of divider line, 80 if ! defined
  Returns  : void

=cut

sub log_output_rfam_banner {
  my ($fh, $executable, $banner, $also_stdout, $dlen) = @_;

  if(! defined $dlen) { $dlen = 80; }
  my $str;
  $str = sprintf ("# %s :: %s\n", Bio::Rfam::Utils::file_tail($executable), $banner);
  print $fh $str; if($also_stdout) { print $str; }
  #printf $fp ("# RFAM\n");
  #printf $fp ("# COPYRIGHT INFO GOES HERE\n");
  #printf $fp ("# LICENSE INFO GOES HERE\n");
  log_output_divider($fh, $also_stdout, $dlen);

  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_preamble

  Title    : log_output_preamble
  Incept   : EPN, Tue Nov 12 10:33:05 2013
  Usage    : Bio::Rfam::Utils::log_output_preamble($fh, $cwidth, $config, $desc, $also_stdout);
  Function : Outputs Rfam preamble (user, date, pwd etc.) to $fh and optionally stdout.
  Args     : $fh:          file handle to output to
           : $cwidth:      column width, usually 40
           : $user:        user name
           : $config:      Bio::Rfam::Config object
           : $desc:        famObj->desc file
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void
=cut

sub log_output_preamble {
  my ($fh, $cwidth, $user, $config, $desc, $also_stdout) = @_;

  my $date = scalar localtime();

  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# user:", $user),                 $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# date:", $date),                 $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# pwd:", getcwd),                 $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# process-id:", $$),              $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# location:", $config->location), $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# family-id:", $desc->ID),        $also_stdout);
  if(defined $desc->AC) {
    Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# family-acc:", $desc->AC),       $also_stdout);
  }
  else {
    Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf ("%-*s%s\n", $cwidth, "# family-acc:", "undef"),       $also_stdout);
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 log_output_tail

  Title    : log_output_tail
  Incept   : EPN, Wed Nov 20 10:40:40 2013
  Usage    : Bio::Rfam::Utils::log_output_tail($fh, $start_time);;
  Function : Outputs final 3 lines of all log files, run time and [ok] stamp.
  Args     : $fh:          file handle to output to
           : $start_time:  time() returned this when script started
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void
=cut

sub log_output_tail {
  my ($fh, $start_time, $also_stdout) = @_;

  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf("#\n"), $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf("# Total time elapsed: %s\n", Bio::Rfam::Utils::format_time_string(time() - $start_time)), $also_stdout);
  Bio::Rfam::Utils::printToFileAndOrStdout($fh, sprintf("# [ok]\n"), $also_stdout);

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
           : $len:         length of divider line, 80 if ! defined,
  Returns  : void

=cut

sub log_output_divider {
  my ($fh, $also_stdout, $len) = @_;
  if(! defined $len || $len eq "") { $len = 80; }
  my $str = "# -";
  my $curlen = 3;
  while($curlen < $len) { $str .= " -"; $curlen += 2; }
  $str .= "\n";

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
           : $dbchoice:    string indicating what DB is being used (e.g. 'rfamseq')
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
           : $header_str:  string to output at top of progress table
           : $also_stdout: '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_progress_column_headings {
  my ($fh, $header_str, $also_stdout) = @_;

  my $str;
  $str = "#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = "# $header_str\n#\n";
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
           : $fwidth:      width of file name, set to "20" if undefined
           : $dwidth:      width of description, set to "60" if undefined
  Returns  : void

=cut

sub log_output_file_summary_column_headings {
  my ($fh, $also_stdout, $fwidth, $dwidth) = @_;

  if(! defined $fwidth) { $fwidth = 20; }
  if(! defined $dwidth) { $dwidth = 60; }

  my $str;
  $str = "#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = "# Output file summary:\n#\n";
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-*s    %-*s\n", $fwidth, "file name",  $dwidth, "description");
  print $fh $str; if($also_stdout) { print $str; }
  my $fstr = monocharacterString("=", $fwidth);
  my $dstr = monocharacterString("=", $dwidth);
  $str = sprintf ("# %-*s    %-*s\n", $fwidth, $fstr, $dwidth, $dstr);
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
           : $fwidth:      width of file name, set to "20" if undefined
           : $dwidth:      width of description, set to "60" if undefined
  Returns  : void

=cut

sub log_output_file_summary {
  my ($fh, $filename, $desc, $also_stdout, $fwidth, $dwidth) = @_;

  if(! defined $fwidth) { $fwidth = 20; }
  if(! defined $dwidth) { $dwidth = 60; }

  my $str = sprintf ("  %-*s    %-*s\n", $fwidth, $filename, $dwidth, $desc);
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
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s  %10s\n", "stage",          "wall time",  "ideal time",  "cpu time",   "wait time",  "wait fract", "efficiency");
  print $fh $str; if($also_stdout) { print $str; }
  $str = sprintf ("# %-15s  %-10s  %10s  %10s  %10s  %10s  %10s\n", "==============", "==========", "==========", "==========", "==========", "==========", "==========");
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
           : $max_elp_secs: slowest jobs maximum elapsed seconds
           : $ideal_secs:   total num elapsed secs it would have taken if all CPUs took identical time
           : $also_stdout:  '1' to also output to stdout, '0' not to
  Returns  : void

=cut

sub log_output_timing_summary {
  my ($fh, $stage, $wall_secs, $tot_cpu_secs, $wait_secs, $max_elp_secs, $ideal_secs, $also_stdout) = @_;

  # $ideal_secs: time it would have taken if all jobs took equal time (the goal of parallelization)
  # efficiency: $ideal_secs / $max_elp_secs
  my $efficiency = 1.0;
  if($ideal_secs > 0 && ($ideal_secs < $max_elp_secs)) {
    $efficiency = $ideal_secs / $max_elp_secs;
  }
  # wait fraction: fraction of time spent waiting
  my $wait_fract = 0.;
  if($wait_secs ne "-" && $wait_secs > 0) {
    if($wait_secs > $wall_secs) { die "ERROR in log_output_timing_summary(): wait_secs exceeds wall_secs ($wait_secs > $wall_secs)"; }
    $wait_fract = $wait_secs / $wall_secs;
  }
  my $str = sprintf ("  %-15s  %10s  %10s  %10s  %10s  %10.2f  %10.2f\n",
                     $stage,
                     Bio::Rfam::Utils::format_time_string($wall_secs),
                     Bio::Rfam::Utils::format_time_string($ideal_secs),
                     Bio::Rfam::Utils::format_time_string($tot_cpu_secs),
                     ($wait_secs eq "-") ? "-" : Bio::Rfam::Utils::format_time_string($wait_secs),
                     $wait_fract,
                     $efficiency);
  print $fh $str; if($also_stdout) { print $str; }

  return;
}


#-----------------------------------------------------------------

=head2 fetchSubseqsGivenNseArray

    Title    : fetchSubseqsGivenNseArray
    Incept   : EPN, Thu Nov 14 10:02:34 2013
    Usage    : fetchSubseqsGivenNseArray($nseAR, $fetchfile, $textw, $outfile, $logFH, $do_stdout)
    Function : Fetch all hits listed in name/start-end format in @{$nseAR}
             : from $fetchfile and output to $outfile (or return
             : seqstring if $outfile is "" or undefined).
    Args     : $nseAR:     ref to array of name/start-end, we will fetch a subset
             :             from seq 'name' from 'start' to 'end' and rename the
             :             subseq 'name/start-end'.
             : $fetchfile: file to fetch seqs from
             : $textw:     width of FASTA seq lines, usually $FASTATEXTW, -1 for unlimited
             : $outfile:   output file for fetched seqs, if undefined or "", return $seqstring
             : $logFH:     file handle to output progress info on fetching to, unless undefined
             : $do_stdout: output progress to stdout too
    Returns  : $nseq:      number of sequences fetched
             : $nres:      number of residues fetched
             : $seqstring: string of all seqs, IFF $outfile is undefined or ""
=cut

sub fetchSubseqsGivenNseArray {
  my ($nseAR, $fetchfile, $textw, $outfile, $logFH, $do_stdout) = @_;

  if(! defined $textw) { $textw = $FASTATEXTW; }

  my @fetchAA; # array with info on seqs to fetch
  my $nseq = 0;
  my $nres = 0;
  foreach my $nse (@{$nseAR}) {
    my ($validated, $name, $start, $end) = Bio::Rfam::Utils::nse_breakdown($nse);
    if(! $validated) { die "ERROR, $nse not in name/start-end format"; }
    $nres += Bio::Rfam::Utils::nse_sqlen($nse);
    $nseq++;
    push(@fetchAA, [$nse, $start, $end, $name]);
  }
  close(IN);

  my $seqstring = undef;
  if(defined $outfile && $outfile ne "") {
    Bio::Rfam::Utils::fetch_from_sqfile_wrapper($fetchfile, \@fetchAA, 1, $textw, $logFH, 1, $outfile);
  }
  else {
    $seqstring = Bio::Rfam::Utils::fetch_from_sqfile_wrapper($fetchfile, \@fetchAA, 1, $textw, $logFH, 1, ""); # "" means return a string of all seqs
  }

  return ($nseq, $nres, $seqstring); # note: seqstring is undefined if $outfile was passed in
}

#-------------------------------------------------------------------------------

=head2 fetch_from_sqfile_wrapper

  Title    : fetch_from_sqfile_wrapper
  Incept   : EPN, Thu Oct 31 15:07:56 2013
  Usage    : Bio::Rfam::Utils::fetch_seqs_wrapper($fetchfile, $fetchAAR, $logFH, $also_stdout, $seqfile);
  Function : Fetches complete sequences or subsequences (if $do_subseqs == 1) from a
           : sequence file and either outputs them to a file or returns them
           : concatenated together in a string.
  Args     : $fetchfile:    file to fetch seqs from
           : $fetchAR:      reference to array of names to fetch, or 2D arrays (if $do_subseqs),
           :                in which case, 2nd array is [$nse, $start, $end, $name] for seqs to fetch
           : $do_subseqs:   '1' if fetchAAR is really a ref to a 2D array for subseq fetching
           : $textw:        width of FASTA seq lines, usually $FASTATEXTW, -1 for unlimited
           : $logFH:        log file to output timing info to, undef for none
           : $do_stdout:    '1' to output updates to stdout also, ignored if $logFH is ""
           : $outfile:      seq file to print sequences to, if "" or undefined, return string of all fetch seqs
  Returns  : IF $seqfile is "" or undefined: string of all fetch seqs, concatenated, else ""

=cut

sub fetch_from_sqfile_wrapper {
  my ($fetchfile, $fetchAR, $do_subseqs, $textw, $logFH, $do_stdout, $outfile) = @_;

  if(! defined $textw) { $textw = $FASTATEXTW; }

  my $fetch_sqfile = Bio::Easel::SqFile->new({
    fileLocation => $fetchfile,
  });

  my $ret_str = "";

  my $fetch_start_time = time();

  if(defined $logFH) {
    Bio::Rfam::Utils::log_output_progress_local($logFH, "seqfetch", time() - $fetch_start_time, 1, 0, sprintf("[fetching %d seqs]", scalar(@{$fetchAR})), $do_stdout);
  }
  if(defined $outfile && $outfile ne "") {
    if($do_subseqs) { $fetch_sqfile->fetch_subseqs($fetchAR, $textw, $outfile); }
    else            { $fetch_sqfile->fetch_seqs_given_names($fetchAR, $textw, $outfile); }
  }
  else { # outfile is undefined,
    if($do_subseqs) { $ret_str = $fetch_sqfile->fetch_subseqs($fetchAR, $textw); }
    else            { $ret_str = $fetch_sqfile->fetch_seqs_given_names($fetchAR, $textw); }
  }

  if(defined $logFH) {
    Bio::Rfam::Utils::log_output_progress_local($logFH, "seqfetch", time() - $fetch_start_time, 0, 1, "", $do_stdout);
  }

  $fetch_sqfile->close_sqfile();

  return $ret_str; # this will be "" if $outfile was defined and ne ""
}
#-------------------------------------------------------------------------------

=head2 remove_descriptions_from_fasta_seq_string

  Title    : remove_descriptions_from_fasta_seq_string
  Incept   : EPN, Fri Nov  1 10:03:45 2013
  Usage    : Bio::Rfam::Utils::remove_descriptions_from_fasta_seq_string($seqstring)
  Function : Remove descriptions from a string that includes sequence data in
           : FASTA format.
  Args     : $seqstring:    sequence string, possibly including multiple sequences in FASTA format
  Returns  : string that is $seqstring with descriptions removed

=cut

sub remove_descriptions_from_fasta_seq_string {
  my ($seqstring) = @_;

  # want to only remove Descriptions
  # [^\S\n] says match anything that's not (not-whitespace or newline)
  $seqstring =~ s/\>(\S+)[^\S\n]+.*\n/\>$1\n/g;

  return $seqstring;
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

=head2 fileToString

  Title    : fileToString
  Incept   : EPN, Fri Nov  1 10:16:06 2013
  Usage    : fileToString($filePath)
  Function : Open a file, copy it in its entirety to a string
           : and return that string.
  Args     : $filePath: full path to file
  Returns  : $str: the full files contents as a string

=cut

sub fileToString {
  my ($filePath) = @_;

  my $ret_str = "";
  open(IN, $filePath) || die "ERROR unable to open $filePath, to convert it to a string";
  while(my $line = <IN>) {
    $ret_str .= $line;
  }
  return $ret_str;
}

#-------------------------------------------------------------------------------

=head2 fileToArray

  Title    : fileToArray
  Incept   : EPN, Thu Nov 14 09:29:06 2013
  Usage    : fileToArray($filePath)
  Function : Open a file, and push each line as an element onto
           : a provided array (referred to by $AR).
  Args     : $filePath:        full path to file
           : $AR:              ref to array to push each line to
           : $remove_newlines: '1' to remove newlines from each line before pushing to array, '0' not to
  Returns  : void

=cut

sub fileToArray {
  my ($filePath, $AR, $remove_newlines) = @_;

  open(IN, $filePath) || die "ERROR unable to open $filePath, to convert it to a string";
  while(my $line = <IN>) {
    if(defined $remove_newlines && $remove_newlines) { chomp $line; }
    push(@{$AR}, $line);
  }
  return;
}

#-------------------------------------------------------------------------------

=head2 checkIfTwoFilesAreIdentical

  Title    : checkIfTwoFilesAreIdentical
  Incept   : EPN, Thu Feb 20 13:23:20 2014
  Usage    : checkIfTwoFilesAreIdentical($file1, $file2)
  Function : Open two files and return 1 if they are identical
           : (same number of lines and each line is identical).
           : else return 0;
  Args     : $file1: path to first file
           : $file1: path to second file
  Returns  : void

=cut

sub checkIfTwoFilesAreIdentical {
  my ($file1, $file2) = @_;

  my ($line1, $line2);
  open(IN1, $file1) || die "ERROR unable to open $file1 in checkIfTwoFilesAreIdentical()";
  open(IN2, $file2) || die "ERROR unable to open $file2 in checkIfTwoFilesAreIdentical()";

  while($line1 = <IN1>) {
    if(! ($line2 = <IN2>)) { close(IN1); close(IN2); return 0; } # more lines in file 1 than file 2
    if($line1 ne $line2)   { close(IN1); close(IN2); return 0; } # difference in current line
  }
  while($line2 = <IN2>) { close(IN1); close(IN2); return 0; } # more lines in file 2 than file 1

  close(IN1);
  close(IN2);

  return 1;
}

#-------------------------------------------------------------------------------

=head2 printToFileAndOrStdout

  Title    : printToFileAndOrStdout
  Incept   : EPN, Wed Apr 24 09:08:18 2013
  Usage    : printToFileAndStdout($str)
  Function : Print string to a file handle and/or to stdout.
  Args     : $fh:        file handle to print to, "" to not print to fh
           : $str:       string to print
           : $do_stdout: 1 to print to stdout, 2 to print to stderr, 0 to
           :             print to neither
  Returns  : void

=cut

sub printToFileAndOrStdout {
  my ($fh, $str, $do_stdout) = @_;

  if($fh ne "") {
    print $fh $str;
  }
  if(defined $do_stdout && $do_stdout == 2) {
    print STDERR $str;
  }
  elsif((! defined $do_stdout) || $do_stdout) {
    print $str;
  }

  return;
}
#-------------------------------------------------------------------------------

=head2 printToFileAndStderr

  Title    : printToFileAndStderr
  Incept   : EPN, Mon Mar 31 11:26:56 2014
  Usage    : printToFileAndStderr($str)
  Function : Print string to a file handle and to stderr.
  Args     : $fh:   file handle to print to, "" to not print to fh
           : $str:  string to print
  Returns  : void

=cut

sub printToFileAndStderr {
  my ($fh, $str) = @_;

  if($fh ne "") { print $fh $str; }
  print STDERR $str;

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
  my $age1 = stat($file1)->mtime;
  my $age2 = stat($file2)->mtime;
  if ($age2 < $age1) {
	return 1;
 }

  #if( -M $file1 <= -M $file2 ) {
  #  return 1;
  #}
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

=head2 sumArray

  Title    : sumArray
  Incept   : EPN, Wed Aug 21 13:21:47 2013
  Usage    : sumArray($AR, $n)
  Function : Return sum of first $n elements in array @{$AR}.
  Args     : $AR: ref to array to sum
           : $n:  size of array (we\'ll sum the first $n values)
  Returns  : sum of first $n elements (usually all elements)

=cut

sub sumArray {
  my ($AR, $n) = @_;

  my $i;
  my $sum = 0;
  for($i = 0; $i < $n; $i++) {
    $sum += $AR->[$i];
  }
  return $sum;
}

#-------------------------------------------------------------------------------

=head2 setArray

  Title    : setArray
  Incept   : EPN, Wed Aug 28 09:18:25 2013
  Usage    : setArray($AR, $val, $n)
  Function : Set all values in an array to $val.
  Args     : $AR:  ref to array to sum
           : $val: to set all array elements to
           : $n:   size of array
  Returns  : void

=cut

sub setArray {
  my ($AR, $val, $n) = @_;

  my $i;
  for($i = 0; $i < $n; $i++) { $AR->[$i] = $val; }
  return;
}

#-------------------------------------------------------------------------------

=head2 maxArray

  Title    : maxArray
  Incept   : EPN, Thu Nov  7 15:00:05 2013
  Usage    : maxArray($AR, $n)
  Function : Return max value in first $n elements in array @{$AR}.
  Args     : $AR: ref to array to sum
           : $n:  size of array (we\'ll find max of first $n values)
  Returns  : maximum of first $n elements (usually all elements)

=cut

sub maxArray {
  my ($AR, $n) = @_;

  my $i;
  if($n == 0) { die "ERROR, maxArray entered with empty array";  }

  my $max = $AR->[0];
  for($i = 0; $i < $n; $i++) {
    $max = ($AR->[$i] > $max) ? $AR->[$i] : $max;
  }
  return $max;
}

#-------------------------------------------------------------------------------

=head2 minArray

  Title    : minArray
  Incept   : EPN, Thu Nov  7 15:01:43 2013
  Usage    : minArray($AR, $n)
  Function : Return min value in first $n elements in array @{$AR}.
  Args     : $AR: ref to array to sum
           : $n:  size of array (we\'ll find min of first $n values)
  Returns  : minimum of first $n elements (usually all elements)

=cut

sub minArray {
  my ($AR, $n) = @_;

  my $i;
  if($n == 0) { die "ERROR, minArray entered with empty array"; }

  my $min = $AR->[0];
  for($i = 0; $i < $n; $i++) {
    $min = ($AR->[$i] < $min) ? $AR->[$i] : $min;
  }
  return $min;
}

#-------------------------------------------------------------------------------

=head2 maxLenStringInArray

  Title    : maxLenStringInArray
  Incept   : EPN, Fri Nov  1 10:53:59 2013
  Usage    : maxLenStringInArray($AR, $n)
  Function : Determine length of longest string in array referenced
           : by $AR, and return that length
  Args     : $AR:  ref to array to examine
           : $n:   size of array, if known, can be undef
  Returns  : length (num chars) in longest string in $AR

=cut

sub maxLenStringInArray {
  my ($AR, $n) = @_;

  if(! defined $n) { $n = scalar(@{$AR}); }
  if($n == 0) { return 0; }
  my $i;
  my $xlen = length($AR->[0]);
  for($i = 1; $i < $n; $i++) {
    my $len = length($AR->[$i]);
    if($len > $xlen) { $xlen = $len; }
  }
  return $xlen;
}

#-------------------------------------------------------------------------------

=head2 minLenStringInArray

  Title    : minLenStringInArray
  Incept   : EPN, Thu Nov  7 14:52:11 2013
  Usage    : minLenStringInArray($AR, $n)
  Function : Determine length of shortest string in array referenced
           : by $AR, and return that length
  Args     : $AR:  ref to array to examine
           : $n:   size of array, if known, can be undef
  Returns  : length (num chars) in shortest string in $AR

=cut

sub minLenStringInArray {
  my ($AR, $n) = @_;

  if(! defined $n) { $n = scalar(@{$AR}); }
  if($n == 0) { return 0; }
  my $i;
  my $nlen = length($AR->[0]);
  for($i = 1; $i < $n; $i++) {
    my $len = length($AR->[$i]);
    if($len < $nlen) { $nlen = $len; }
  }
  return $nlen;
}

#-------------------------------------------------------------------------------

=head2 monocharacterString

  Title    : monocharacterString
  Incept   : EPN, Wed Nov  6 09:35:11 2013
  Usage    : monocharacterString($char, $len)
  Function : Return a string of $char repeated $len times.
  Args     : $char:  single character that will compose returned string
           : $len:   number of times to repeat $char to make return string
  Returns  : string of $char repeated $len times

=cut

sub monocharacterString {
  my ($char, $len) = @_;

  my $ret_str = "";
  for(my $i = 0; $i < $len; $i++) {
    $ret_str .= $char;
  }
  return $ret_str;
}

#-------------------------------------------------------------------------------

=head2 padString

  Title    : padString
  Incept   : EPN, Mon Mar 24 13:56:56 2014
  Usage    : padString($orig_str, $tot_len, $pad_char)
  Function : Return a string that is of total length $tot_len and composed of $orig_str
           : appended with repeating $padchar.
  Args     : $orig_str:  original string
           : $tot_len:   desired length
           : $pad_char:  character to add to $orig_str
  Returns  : string of $orig_str followed by repeating $pad_char

=cut

sub padString {
  my ($orig_str, $tot_len, $pad_char) = @_;

  my $ret_str = $orig_str;
  my $nadd = $tot_len - length($orig_str);
  if($nadd > 0) {
    $nadd /= length($pad_char);
    $ret_str .= Bio::Rfam::Utils::monocharacterString($pad_char, $nadd);
  }
  return $ret_str;
}

#-------------------------------------------------------------------------------

=head2 percentize

  Title    : percentize
  Incept   : EPN, Wed Nov 13 09:19:16 2013
  Usage    : percentize($val)
  Function : Convert a real into a (rounded) percent
           : Examples:
           : $val: 0.73    returns 73
           : $val: 0.7349  returns 73
           : $val: 0.7350  returns 74
           : $val: 1.0     returns 100
           : $val: 5.3     returns 530
  Args     : $val: real value
  Returns  : real value converted to a percentage

=cut

sub percentize {
  return int (($_[0] * 100) + .5);
}

#-------------------------------------------------------------------------------

=head2 numLinesInFile

  Title    : numLinesInFile
  Incept   : EPN, Tue Feb  4 09:43:32 2014
  Usage    : numLinesInFile($filename)
  Function : Determine number of lines in a file and return it.
  Args     : $filename: path to the file of interest
  Returns  : number of lines in $filename
  Dies     : if unable to open the file
=cut

sub numLinesInFile {
  my ($filename) = @_;

  open(IN, $filename) || die "ERROR unable to open file $filename in numLinesInFile()";
  my $line_cnt = 0;

  while(<IN>) { $line_cnt++; }

  close(IN);
  return $line_cnt;
}

#-------------------------------------------------------------------------------
# Subroutines brought in to check seed sequences using md5s [Nov 2018]
#-------------------------------------------------------------------------------
# md5_of_sequence_string:     calculate md5 of a sequence string
# revcomp_sequence_string:    reverse complement a sequence string
# rfamseq_nse_lookup_and_md5: fetch a sequence in Rfamseq and calculate its md5
# ena_nse_lookup_and_md5:     fetch a sequence from ENA and calculate its md5
# genbank_nse_lookup_and_md5: fetch a sequence from NCBI's GenBank and calculate its md5
# rnacentral_md5_lookup:      check if a sequence is in RNAcentral using its md5
#-------------------------------------------------------------------------------
# Subroutines brought in to deal with SEED seqs not being in the Rfam DB
#-------------------------------------------------------------------------------
# genbank_fetch_seq_info: fetch taxids and descs for a list of sequences from NCBI's GenBank
# ncbi_taxonomy_fetch_taxinfo:    fetch tax info to populate taxonomy table for a list of taxids
#-------------------------------------------------------------------------------
=head2 md5_of_sequence_string
  Title    : md5_of_sequence_string
  Incept   : EPN, Wed Nov 14 19:38:53 2018
  Function : Returns MD5 value for a sequence string
           : after converting to all uppercase, and converting Ts to Us.
  Args     : $seqstring: the sequence string
  Returns  : the md5
=cut

sub md5_of_sequence_string {
  my ( $seqstring ) = @_;

  $seqstring =~ s/\n//g;     # remove newlines
  $seqstring =~ tr/a-z/A-Z/; # all uppercase
  $seqstring =~ s/U/T/g;     # all DNA

  return md5_hex($seqstring);
}

#-------------------------------------------------------------------------------
=head2 revcomp_sequence_string
  Title    : revcomp_of_sequence_string
  Incept   : EPN, Tue Nov 27 15:01:39 2018
  Function : Returns the reverse complement DNA sequence of the passed
           : in DNA/RNA sequence string.
           : If passed in sequence is RNA, it is converted to DNA before
           : being reverse complemented.
  Args     : $seqstring: the DNA/RNA sequence string
  Returns  : the reverse complemented DNA sequence string
=cut

sub revcomp_sequence_string {
  my ( $seqstring ) = @_;

  # DNA-ize it
  $seqstring =~ s/Uu/Tt/g; # convert to DNA
  # reverse it
  $seqstring = reverse $seqstring;
  # complement it
  $seqstring =~ tr/ACGTRYMKHBVDacgtrymkhbvd/TGCAYRKMDVBHtgcayrkmdvbh/;
  # see esl_alphabet.c::set_complementarity()
  # note that S, W, N are omitted they are their own complements

  return $seqstring;
}

#-------------------------------------------------------------------------------
=head2 rfamseq_nse_lookup_and_md5
  Title    : rfamseq_nse_lookup_and_md5
  Incept   : EPN, Mon Nov 26 19:28:23 2018
  Function : Looks up a sequence in Rfamseq and calculates its md5 if it's there.
  Args     : $seqDBObj: the Rfamseq sequence database
           : $nse:      sequence name in name/start-end format
  Returns  : 3 values:
           : $have_source_seq: '1' if source sequence is in Rfamseq, else '0'
           : $have_sub_seq:    '1' if $have_source_seq and further subseq start-end is in Rfamseq too, else '0'
           : $md5:             if $have_sub_seq, md5 of subseq, else undefined
  Dies     : if $nse is not in valid name/start-end format
=cut

sub rfamseq_nse_lookup_and_md5 {
  my ( $seqDBObj, $nse) = @_;

  my ( $is_nse, $name, $start, $end, $strand ) = Bio::Rfam::Utils::nse_breakdown($nse);
  if(! $is_nse) {
    die "ERROR, in rfamseq_nse_lookup_and_md5() $nse not in name/start-end format.\n";
  }

  my $have_source_seq = $seqDBObj->check_seq_exists($name) ? 1 : 0;
  my $have_sub_seq    = $seqDBObj->check_subseq_exists($name, $start, $end) ? 1 : 0;
  my $md5 = undef;
  if($have_sub_seq) { # fetch the sequence to a string and compute its md5
    my $subseq = $seqDBObj->fetch_subseq_to_sqstring($name, $start, $end, ($strand == -1));
    $md5       = md5_of_sequence_string($subseq);
  }

  return ($have_source_seq, $have_sub_seq, $md5);
}

#-------------------------------------------------------------------------------
=head2 ena_nse_lookup_and_md5
  Title    : ena_nse_lookup_and_md5
  Incept   : EPN, Mon Nov 26 19:28:23 2018
  Function : Looks up a sequence in ENA and calculates its md5 if it's there.
  Args     : $nse:      sequence name in name/start-end format
  Returns  : 3 values:
           : $have_source_seq: '1' if source sequence is in Rfamseq, else '0'
           : $have_sub_seq:    '1' if $have_source_seq and further subseq start-end is in Rfamseq too, else '0'
           : $md5:             if $have_sub_seq, md5 of subseq, else undefined
  Dies     : if $nse is not in valid name/start-end format
=cut

sub ena_nse_lookup_and_md5 {
  my ( $nse ) = @_;

  my ( $is_nse, $name, $start, $end, $strand ) = Bio::Rfam::Utils::nse_breakdown($nse);
  if(! $is_nse) {
    die "ERROR, in ena_nse_lookup_and_md5() $nse not in name/start-end format.\n";
  }
  # $nse will have end < start if it is negative strand, but we can't fetch from ENA
  # with an end coord less than start, so if we are negative strand, we need to fetch
  # the positive strand, and then revcomp it later.
  my $qstart = ($strand == 1) ? $start : $end;
  my $qend   = ($strand == 1) ? $end   : $start;
  my $qlen   = abs($start - $end) + 1;

  my $url = sprintf("http://www.ebi.ac.uk/ena/data/view/%s&display=fasta&range=%d-%d\"", $name, $qstart, $qend);

  my $got_url = get($url);
  my $have_source_seq = ($got_url =~ m/\>/) ? 1 : 0;
  # if we a sequence named $name exists in ENA, $got_url will have a fasta header line

  # initialize default values, which will change below if we have a valid subseq
  my $have_sub_seq = 0; # changed to '1' below if nec
  my $sqstring = "";
  my $md5 = undef;

  # it is possible that our coords were out of bounds of the ENA seq.
  # We can detect this if $got_url has nothing but a header line
  if($have_source_seq) {
    my @got_url_A = split(/\n/, $got_url);
    foreach my $got_url_line (@got_url_A) {
      if($got_url_line !~ m/^\>/) {
        $sqstring .= $got_url_line;
      }
    }
    if($sqstring ne "") { # $got_url had some sequence, so coords were valid
      $have_sub_seq = 1;
      my $sqlen = length($sqstring);
      # Sometimes we fetch the full sequence, sometimes we only fetch the subseq.
      # (I'm not sure how that is determined.) To deal with this, we check if
      # we've checked the full seq, and if so, we use substr() to get the subseq.
      if(length($sqstring) ne $qlen) { # we fetched the full sequence, need substr() to get subseq
        $sqstring = substr($sqstring, $qstart-1, $qlen);
      }
      if($strand != 1) { # negative strand, reverse complement it
        $sqstring = revcomp_sequence_string($sqstring);
      }
      $md5 = md5_of_sequence_string($sqstring);
    }
  }

  return ($have_source_seq, $have_sub_seq, $md5);
}

#-------------------------------------------------------------------------------
=head2 genbank_nse_lookup_and_md5
  Title    : genbank_nse_lookup_and_md5
  Incept   : EPN, Tue Feb 19 13:13:16 2019
  Function : Looks up a sequence in GenBank and calculates its md5 if it's there.
  Args     : $nse:       sequence name in name/start-end format
           : $nattempts: number of attempts to make to fetch the sequence
           :             (if this is being run in parallel it can cause failure
           :              due (presumably) to overloading NCBI in some way.)
           :             can be undef, in which case set to '1'
           : $nseconds:  number of seconds to wait between attempts
           :             can be undef, in which case set to '3'
  Returns  : 3 values:
           : $have_source_seq: '1' if source sequence is in Rfamseq, else '0'
           : $have_sub_seq:    '1' if $have_source_seq and further subseq start-end is in Rfamseq too, else '0'
           : $md5:             if $have_sub_seq, md5 of subseq, else undefined
  Dies     : if $nse is not in valid name/start-end format
=cut

sub genbank_nse_lookup_and_md5 {
  my ( $nse, $nattempts, $nseconds ) = @_;

  my ( $is_nse, $name, $start, $end, $strand ) = Bio::Rfam::Utils::nse_breakdown($nse);
  if(! $is_nse) {
    die "ERROR, in genbank_nse_lookup_and_md5() $nse not in name/start-end format.\n";
  }
  if(! defined $nattempts) { $nattempts = 1; }
  if(! defined $nseconds)  { $nseconds  = 3; }

  # $nse will have end < start if it is negative strand, but we can't fetch from ENA
  # with an end coord less than start, so if we are negative strand, we need to fetch
  # the positive strand, and then revcomp it later.
  my $qstart = ($strand == 1) ? $start : $end;
  my $qend   = ($strand == 1) ? $end   : $start;
  my $qlen   = abs($start - $end) + 1;

  # initialize default values, which will change below if we have a valid subseq
  my $successful_fetch = 0; # possibly changed to '1' below
  my $have_source_seq  = 0; # possibly changed to '1' below
  my $have_sub_seq     = 0; # possibly changed to '1' below
  my $sqstring = "";
  my $md5 = undef;

  my $api_key = "472570bf7f5d4d9d52023765697b4957fa08";
  my $url = sprintf("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=%s&rettype=fasta&retmode=text&from=%d&to=%d&api_key=%s", $name, $qstart, $qend, $api_key);
  my $got_url = get($url);
  my $looks_like_rnacentral = id_looks_like_rnacentral($name);

  if(! defined $got_url) {
    if(! $looks_like_rnacentral) {
      # if NCBI is being hit by a bunch of requests, the get() command
      # may fail in that $got_url may be undefined. If that happens we
      # wait a few seconds ($nseconds) and try again (up to
      # $nattempts) times BUT we only do this for sequences that
      # don't look like they are RNAcentral ids. For sequences that
      # look like they are RNAcentral ids we do not do more attempts.
      my $attempt_ctr = 1;
      while((! defined $got_url) && ($attempt_ctr < $nattempts)) {
        sleep($nseconds);
        $got_url = get($url);
        $attempt_ctr++;
      }
      if(($attempt_ctr >= $nattempts) && (! defined $got_url)) {
        croak "ERROR trying to fetch sequence info for $name from genbank, reached maximum allowed number of attempts ($nattempts)";
      }
    }
  }
  elsif($got_url !~ m/^>/) {
    # this shouldn't happen, if the sequence doesn't exist then $got_url should be undefined
    die "ERROR in genbank_nse_lookup_and_md5() get() returned a value that is not a sequence";
  }
  else {
    # if we get here: we know that $got_url is defined and starts with a ">",
    # so we know that a sequence named $name exists in GenBank
    $have_source_seq = 1;

    # the fetched sequence should have a header line with a name in this format:
    # >$name:$qstart-$qend
    # if this is not the case, then either the sequence start or end were out of bounds
    # (longer than the sequence length of the fetched sequence)
    my @got_url_A = split(/\n/, $got_url);
    foreach my $got_url_line (@got_url_A) {
      if($got_url_line =~ /^>(\S+)\:(\d+)\-(\d+)/) {
        my ($fetched_name, $fetched_qstart, $fetched_qend) = ($1, $2, $3);
        if(($fetched_name   eq $name) &&
           ($fetched_qstart == $qstart) &&
           ($fetched_qend   == $qend)) {
          $successful_fetch = 1;
        }
      }
      elsif($got_url_line =~ m/\S/) { # not the header line, not a blank line
        $sqstring .= $got_url_line;
      }
    }
    if(($successful_fetch) && ($sqstring ne "") && (length($sqstring) == $qlen)) {
      # we fetched the (sub)sequence, coords were valid
      $have_sub_seq = 1;
      if($strand != 1) { # negative strand, reverse complement it
        $sqstring = revcomp_sequence_string($sqstring);
      }
      $md5 = md5_of_sequence_string($sqstring);
    }
  }
  # printf("returning: have_source_seq: $have_source_seq have_sub_seq: $have_sub_seq, md5: $md5\n");

  return ($have_source_seq, $have_sub_seq, $md5);
}

#-------------------------------------------------------------------------------
=head2 genbank_fetch_seq_info
  Title    : genbank_fetch_seq_info
  Incept   : EPN, Tue Apr 30 20:35:00 2019
  Function : Looks up sequences in GenBank and parses their taxids.
  Args     : $name_AR:   ref to array of names to fetch taxids for, pre-filled
           : $info_HHR:  ref to 2D hash to fill, 1D key is name from name_AR,
           :             2D keys are "ncbi_id", "description", "length", and "mol_type"
           : $nattempts: number of attempts to make to fetch the sequence
           :             (if this is being run in parallel it can cause failure
           :              due (presumably) to overloading NCBI in some way.)
           :             can be undef, in which case set to '1'
           : $nseconds:  number of seconds to wait between attempts
           :             can be undef, in which case set to '3'
  Returns  : void, fills %{$info_HHR}
  Dies     : if @{$name_AR} is empty upon entering
           : if something goes wrong parsing xml
=cut

sub genbank_fetch_seq_info {
  my ( $name_AR, $info_HHR, $nattempts, $nseconds ) = @_;

  my $sub_name = "genbank_fetch_seq_info";

  if(! defined $nattempts) { $nattempts = 10; }
  if(! defined $nseconds)  { $nseconds  = 3; }

  if((! defined $name_AR) || (scalar(@{$name_AR}) == 0)) {
    croak "ERROR in $sub_name undefined or empty input name array";
  }
  if(! defined $info_HHR) {
    croak "ERROR in $sub_name undefined info_HHR";
  }

  # for each sequence, fetch it's info from GenBank, we do this separately to avoid
  # the need to fetch a huge xml string/file
  foreach my $name (@{$name_AR}) {
    # initialize, and also determine if the sequence name looks
    # like RNAcentral IDs, if so, we don't expect the GenBank query to
    # fetch anything
    my $name_str = $name;
    my $looks_like_rnacentral = id_looks_like_rnacentral($name) ? 1 : 0;
    $info_HHR->{$name}{"ncbi_id"}     = "-";
    $info_HHR->{$name}{"description"} = "-";
    $info_HHR->{$name}{"length"}      = "-";
    $info_HHR->{$name}{"mol_type"}    = "-";

    my $api_key = "472570bf7f5d4d9d52023765697b4957fa08";
    my $genbank_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&retmode=xml&id=" . $name_str . "&api_key=" . $api_key;
    my $xml = undef;
    my $xml_string = get($genbank_url);
    my $xml_valid = 0;
    if(defined $xml_string) {
      # Previously, we tried to substitute out the GBSeq_sequence and translation lines
      # but in Sept 2022 this was identified as a bottleneck for at least some families
      # these substitution commands are now commented out but left here for reference.
      # The motivation for them in the first place was to save memory so if memory
      # does not become an issue it should be fine to leave them commented out.
      # However, if we do want to put the substitution commands back in, an alternative
      # strategy might be to add a 'usleep(0.1)' call just prior to the substitution
      # commands. In 2019 testing, this seemed to work when I encountered flakiness
      # related to these substitution commands (see git commits on 7/9/2019, e.g. d1547f8)
      # --------------
      ## to save memory, remove sequence info from the xml_string since we don't need it
      ## remove <GBSeq_sequence> lines
      #$xml_string =~ s/[^\n]+\<GBSeq\_sequence\>\w+\<\/GBSeq\_sequence\>\n//g;
      ## remove <GBQualifier>\n<GBQualifer_name>translation\nGBQualifier_value\n<\GBQualifier> sets of 4 lines
      #$xml_string =~ s/[^\n]+\<GBQualifier\>\n[^\n]+\<GBQualifier\_name\>translation\<\/GBQualifier\_name\>\n[^\n]+\<GBQualifier\_value\>\w+\<\/GBQualifier\_value\>\n[^\n]+\<\/GBQualifier\>\n//g;
      $xml = eval { XML::LibXML->load_xml(string => $xml_string); };
      if($@) { $xml_valid = 0; }
      else   { $xml_valid = 1; }
    }

    if(! $xml_valid) {
      if(! $looks_like_rnacentral) {
        # the get() command either failed (returned undef) or
        # returned an invalid xml string, either way we
        # wait a few seconds ($nseconds) and try again (up to
        # $nattempts) times BUT we only do this if the ID doesn't look
        # like a RNAcentral ids. If it does, we do not do more attempts.
        my $attempt_ctr = 1;
        while((! $xml_valid) && ($attempt_ctr < $nattempts)) {
          sleep($nseconds);
          # printf("Retrying to fetch for $name\n");
          $xml_string = get($genbank_url);
          if(defined $xml_string) {
            # Two substitions below are commented out, see comment above
            # in analogous position (search for 'Sept 2022')
            # --------------
            ## to save memory, remove sequence info from the xml_string since we don't need it
            ## remove <GBSeq_sequence> lines
            # first substition commented out in Sept 2022:
            #$xml_string =~ s/[^\n]+\<GBSeq\_sequence\>\w+\<\/GBSeq\_sequence\>\n//g;
            ## remove <GBQualifier>\n<GBQualifer_name>translation\nGBQualifier_value\n<\GBQualifier> sets of 4 lines
            # second substition commented out in Sept 2022:
            #$xml_string =~ s/[^\n]+\<GBQualifier\>\n[^\n]+\<GBQualifier\_name\>translation\<\/GBQualifier\_name\>\n[^\n]+\<GBQualifier\_value\>\w+\<\/GBQualifier\_value\>\n[^\n]+\<\/GBQualifier\>\n//g;
            #---------------
            $xml = eval { XML::LibXML->load_xml(string => $xml_string); };
            if($@) { $xml_valid = 0; }
            else   { $xml_valid = 1; }
          }
          $attempt_ctr++;
        }
        if(($attempt_ctr >= $nattempts) && (! $xml_valid)) {
          croak "ERROR trying to fetch sequence data for sequence $name from genbank, reached maximum allowed number of attempts ($attempt_ctr)";
        }
      }
    }
    else {
      # if we get here: we know that $xml_string is defined and valid
      # and $xml is ready for parsing
      foreach my $gbseq ($xml->findnodes('//GBSeq')) {
        my $accver = $gbseq->findvalue('./GBSeq_accession-version');
        if(! defined $accver) {
          croak "ERROR in $sub_name problem parsing XML, no accession-version read";
        }
        if(! exists $info_HHR->{$accver}) {
          croak "ERROR in $sub_name problem parsing XML, unexpected accession.version $accver";
        }

        my $description = $gbseq->findvalue('./GBSeq_definition');
        if(! defined $description) {
          croak "ERROR in $sub_name problem parsing XML, no definition (description) read";
        }
        $info_HHR->{$accver}{"description"} = $description;

        my $length = $gbseq->findvalue('./GBSeq_length');
        if(! defined $length) {
          croak "ERROR in $sub_name problem parsing XML, no length read";
        }
        $info_HHR->{$accver}{"length"} = $length;

        # for taxid and mol_type, we have to fetch from Qualifier_values, and may have more than 1
        # in that case, they will be concatenated together
        my $taxid_val = $gbseq->findvalue('./GBSeq_feature-table/GBFeature/GBFeature_quals/GBQualifier/GBQualifier_value[starts-with(text(), "taxon:")]');
        my $taxid = undef;
        my $orig_taxid_val = $taxid_val;
        if(! defined $taxid_val) {
          croak "ERROR in $sub_name did not read taxon info for $accver";
        }
        # $taxid_val will be concatenation of taxon:<\d+> N >= 1 times, we want to make sure <\d+> is equivalent all N instances
        while($taxid_val =~ /^taxon\:(\d+)/) {
          my $cur_taxid = $1;
          if(! defined $taxid) { # first taxid
            $taxid = $cur_taxid;
          }
          elsif($cur_taxid != $taxid) {
            ; # do nothing, see comment below
            # Change Jan 29, 2021: if multiple taxids are returned for a single accession,
            # always use the first one and don't complain. Previously we would fail here
            # with following croak:
            #croak "ERROR in $sub_name for $accver, > 1 taxids read: $taxid and $cur_taxid\nFull taxon values read: $orig_taxid_val\n";
          }
          $taxid_val =~ s/^taxon\:(\d+)//;
        }
        if($taxid_val ne "") {
          croak "ERROR in $sub_name could not parse taxon info $accver\nFull taxon values read: $orig_taxid_val\n";
        }
        $info_HHR->{$accver}{"ncbi_id"} = $taxid;

        # mol_type is like taxid in that we may fetch more than one value concatenated together
        # but more complicated because we don't have the 'taxon:' at the beginning to use to parse
        # to determine the single value that we want
        # For example if we have more than 3 mol_type qualifiers, they will just be concatenated
        # together like "genomic DNAgenomic DNAgenomic DNA" and the single value we want is
        # "genomic DNA". To figure out the single value we assume it is repeated N times,
        # determine N, then determine its length, use substr to get it, and then verify
        # we have that same single value concatenated N times.
        my $mol_type_val = $gbseq->findvalue('./GBSeq_feature-table/GBFeature/GBFeature_quals/GBQualifier/GBQualifier_name[text()="mol_type"]/following-sibling::GBQualifier_value');
        my $mol_type = undef;
        my $orig_mol_type_val = $mol_type_val;
        my $nmol_type = $gbseq->findvalue('count(./GBSeq_feature-table/GBFeature/GBFeature_quals/GBQualifier/GBQualifier_name[text()="mol_type"]/following-sibling::GBQualifier_value)');
        # the value we want ($mol_type) is concatenated $nmol_type times together in $mol_type_val, determine what it is, croaking if we can't
        if((length($mol_type_val) % ($nmol_type)) != 0) {
          croak "ERROR in $sub_name could not parse mol_type info $mol_type_val\n";
        }
        my $mol_type_len = int((length($mol_type_val) / $nmol_type) + 0.01);
        my $mol_type_val_start = 0;
        while($mol_type_val_start < $mol_type_len) {
          my $cur_mol_type = substr($mol_type_val, $mol_type_val_start, $mol_type_len);
          if(! defined $mol_type) {
            $mol_type = $cur_mol_type;
          }
          elsif($cur_mol_type ne $mol_type) {
            croak "ERROR in $sub_name for $accver, > 1 mol_types read: $mol_type and $cur_mol_type\nFull mol_type values read: $orig_mol_type_val\n";
          }
          $mol_type_val_start += $mol_type_len;
        }
        if($mol_type_val_start != $mol_type_len) {
          croak "ERROR in $sub_name could not parse mol_type value for $accver\nFull mol_type values read: $orig_mol_type_val\n";
        }
        $info_HHR->{$accver}{"mol_type"} = $mol_type;

        $info_HHR->{$accver}{"source"} = "SEED:GenBank";
      }
    } # end of 'else' entered if $xml_string is defined
  } # end of 'for' loop over seq names for fetching and adding data per seq name

  return;
}

#-------------------------------------------------------------------------------
=head2 ncbi_taxonomy_fetch_taxinfo
  Title    : ncbi_taxonomy_fetch_taxinfo
  Incept   : EPN, Tue May  7 19:04:55 2019
  Function : Looks up taxids in NCBI's taxonomy DB and parses the resulting info.
  Args     : $taxid_AR:      ref to array of taxids to fetch info for, pre-filled
           : $tax_table_HHR: ref to 2D hash to fill with fetched info
           : $nattempts:     number of attempts to make to fetch the sequence
           :                 (if this is being run in parallel it can cause failure
           :                 due (presumably) to overloading NCBI in some way.)
           :                 can be undef, in which case set to '1'
           : $nseconds:      number of seconds to wait between attempts
           :                 can be undef, in which case set to '3'
  Returns  : void
  Dies     : if @{$taxid_AR} is empty upon entering
           : if something goes wrong parsing the xml
=cut

sub ncbi_taxonomy_fetch_taxinfo {
  my ( $taxid_AR, $tax_table_HHR, $nattempts, $nseconds ) = @_;

  my $sub_name = "ncbi_taxonomy_fetch_taxinfo()";

  if(! defined $nattempts) { $nattempts = 10; }
  if(! defined $nseconds)  { $nseconds  = 3;  }

  if((! defined $taxid_AR) || (scalar(@{$taxid_AR}) == 0)) {
    croak "ERROR in $sub_name undefined or empty input name array";
  }
  my %taxid_H = (); # hash to keep track of the taxids in our input @{$taxid_AR}
  foreach my $taxid (@{$taxid_AR}) {
    if(! defined $taxid_H{$taxid}) {
      $taxid_H{$taxid} = 1;
    }
  }

  # look up each taxid separately to avoid problem with fetching too many taxids (limit seems to be somewhere around 1000)
  foreach my $taxid (sort keys (%taxid_H)) {
    my $api_key = "472570bf7f5d4d9d52023765697b4957fa08";
    my $genbank_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&retmode=xml&id=" . $taxid . "&api_key=" . $api_key;
    my $xml = undef;
    my $xml_string = get($genbank_url);
    my $xml_valid = 0;
    if(defined $xml_string) {
      $xml = eval { XML::LibXML->load_xml(string => $xml_string); };
      if($@) { $xml_valid = 0; }
      else   { $xml_valid = 1; }
    }

    if(! $xml_valid) {
      # the get() command either failed (returned undef) or
      # returned an invalid xml string, either way we
      # wait a few seconds ($nseconds) and try again (up to
      # $nattempts) times BUT we only do this if the ID doesn't look
      # like a RNAcentral ids. If it does, we do not do more attempts.
      my $attempt_ctr = 1;
      while((! $xml_valid) && ($attempt_ctr < $nattempts)) {
        sleep($nseconds);
        $xml_string = get($genbank_url);
        if(defined $xml_string) {
          $xml = eval { XML::LibXML->load_xml(string => $xml_string); };
          if($@) { $xml_valid = 0; }
          else   { $xml_valid = 1; }
        }
        $attempt_ctr++;
      }
      if(($attempt_ctr >= $nattempts) && (! $xml_valid)) {
        croak "ERROR trying to fetch taxids from genbank, reached maximum allowed number of failed attempts ($nattempts)\nTried to fetch taxid\n$taxid\n";
      }
    }

    foreach my $taxon ($xml->findnodes('/TaxaSet/Taxon')) {
      my $cur_taxid = $taxon->findvalue('./TaxId');
      if(! defined $cur_taxid) {
        croak "ERROR in $sub_name unable to parse taxid from xml";
      }
      # check if there are any additional taxids:
      my @aka_taxid_A = ();
      foreach my $aka_taxid_node ($taxon->findnodes('./AkaTaxIds/TaxId')) {
        push(@aka_taxid_A, $aka_taxid_node->to_literal());
      }
      # Determine which input taxid this xml set pertains to.
      # It is not necessarily $cur_taxid (because if input taxid has been merged
      # with another taxid, then $cur_taxid will be the new taxid it was merged to).
      # However, if $cur_taxid is not an input taxid, one of the ids in @aka_taxid_A
      # should be.
      my $taxid = undef;
      my $taxid_is_cur = 0; # the taxid we wanted to fetch we actually fetched (we didn't fetch a new taxid that was merged to the one we wanted)
      if(defined $taxid_H{$cur_taxid}) {
        $taxid = $cur_taxid;
        $taxid_is_cur = 1;
      }
      else {
        foreach my $aka_taxid (@aka_taxid_A) {
          if((! defined $taxid) && (defined $taxid_H{$aka_taxid})) {
            $taxid = $aka_taxid;
          }
        }
      }
      if(! defined $taxid) {
        croak ("ERROR in $sub_name, unable to determine matching input tax id for fetched taxid $cur_taxid");
      }

      my $lineage = $taxon->findvalue('./Lineage');
      if(! defined $lineage) {
        croak "ERROR in $sub_name unable to parse lineage from xml for taxid $cur_taxid";
      }

      my $scientific_name = $taxon->findvalue('./ScientificName');
      if(! defined $scientific_name) {
        croak "ERROR in $sub_name unable to parse scientific_name from xml for taxid $cur_taxid";
      }

      my $genbank_common_name = $taxon->findvalue('./OtherNames/GenbankCommonName');
      my $species = sprintf("%s%s", $scientific_name, (defined $genbank_common_name) ? " ($genbank_common_name)" : "");

      my $tree_display_name = $species;
      $tree_display_name =~ s/ /\_/g;

      my $align_display_name = $tree_display_name . "[" . $taxid . "]";

      # we only want the lineage starting at "superkingdom", so we have to parse further
      my @lineage_A = split("; ", $lineage);
      my $i = 0;
      my $superkingdom_i = -1;
      foreach my $sub_taxon ($taxon->findnodes('./LineageEx/Taxon')) {
        my $sub_scientific_name = $sub_taxon->findvalue('./ScientificName');
        my $sub_rank = $sub_taxon->findvalue('./Rank');
        if($sub_rank eq "superkingdom") {
          $superkingdom_i = $i;
        }
        $i++;
      }
      my $tax_string = "Unclassified"; # overwritten below if we read LineageEx/Taxon info into @lineage_A
      if($superkingdom_i != -1) {
        $tax_string = join("; ", splice(@lineage_A, $superkingdom_i));
      }
      # commented out this check: could be 'unclassified sequences' or 'marine metagenome' or maybe others?
      # this check used to verify it was an expected species value, but I commented it out because I
      # didn't want to need to list them all
      #elsif($species !~ /^unclassified sequences/) { # could also
      #  croak "ERROR in $sub_name unable to find superkingdom rank for taxid $taxid and species is not 'unclassified sequences' but '$species'";
      #}

      if(($taxid_is_cur) || (! defined $tax_table_HHR->{$taxid})) {
        %{$tax_table_HHR->{$taxid}} = ();
        $tax_table_HHR->{$taxid}{"species"}            = $species;
        $tax_table_HHR->{$taxid}{"tax_string"}         = $tax_string;
        $tax_table_HHR->{$taxid}{"tree_display_name"}  = $tree_display_name;
        $tax_table_HHR->{$taxid}{"align_display_name"} = $align_display_name;
      }
    } # end of 'foreach my $taxon ($xml->findnodes('/TaxaSet/Taxon'))'
  } # end of 'foreach my $taxid (sort keys %taxid_H)

  return;
}

#-------------------------------------------------------------------------------
=head2 rnacentral_md5_lookup
  Title    : rnacentral_md5_lookup
  Incept   : EPN, Tue Nov 27 11:33:59 2018
  Function : Looks up a sequence in RNAcentral based on its md5
  Args     : $in_md5: md5 of the sequence we are looking up
  Returns  : 3 values:
           : $have_seq: '1' if sequence exists in RNAcentral, else '0'
           : $md5:      if $have_seq is '1': RNAcentral md5 for sequence, else undefined
           :            if defined, this should be equal to $md5 input
           : $id:       if $have_seq is '1': RNAcentral ID for sequence, else undefined
           : $desc:     if $have_seq is '1': RNAcentral description for sequence, else undefined
  Dies     : if there is a problem fetching from RNAcentral
=cut

sub rnacentral_md5_lookup {
  my ( $in_md5 ) = @_;

  my $rnacentral_url = "https://rnacentral.org/api/v1/rna?md5=" . $in_md5;
  #printf("rnacentral_url: $rnacentral_url\n");
  my $json = get($rnacentral_url);
  if(! defined $json) { croak "ERROR trying to fetch from rnacentral using md5: " . $in_md5; }
  # Decode the entire JSON
  my $decoded_json = decode_json($json);
  #print Dumper $decoded_json;

  my $have_seq = 0;
  my $md5  = undef;
  my $id   = undef;
  my $desc = undef;

  if((defined $decoded_json->{'results'}) &&
     (defined $decoded_json->{'results'}[0]{'md5'}) &&
     (defined $decoded_json->{'results'}[0]{'rnacentral_id'})) {
    $have_seq = 1;
    $md5  = $decoded_json->{'results'}[0]{'md5'};
    $id   = $decoded_json->{'results'}[0]{'rnacentral_id'};
    $desc = $decoded_json->{'results'}[0]{'description'};
  }

  return ($have_seq, $md5, $id, $desc);
}

#-------------------------------------------------------------------------------
=head2 rnacentral_id_lookup
  Title    : rnacentral_id_lookup
  Incept   : EPN, Wed May  8 19:36:30 2019
  Function : Looks up a sequence in RNAcentral based on its RNAcentral id
  Args     : $in_id: URS id of the sequence we are looking up
  Returns  : 4 values:
           : $have_seq: '1' if sequence exists in RNAcentral, else '0'
           : $md5:      if $have_seq is '1': RNAcentral md5 for sequence, else undefined
           :            if defined, this should be equal to $md5 input
           : $desc:     if $have_seq is '1': RNAcentral description for sequence, else undefined
           : $length:   if $have_seq is '1': length for sequence, else undefined
  Dies     : if there is a problem fetching from RNAcentral
=cut

sub rnacentral_id_lookup {
  my ( $in_id ) = @_;

  my $rnacentral_url = "https://rnacentral.org/api/v1/rna?rnacentral_id5=" . $in_id;
  #printf("rnacentral_url: $rnacentral_url\n");
  my $json = get($rnacentral_url);
  if(! defined $json) { croak "ERROR trying to fetch from rnacentral using id: " . $in_id; }
  # Decode the entire JSON
  my $decoded_json = decode_json($json);
  #print Dumper $decoded_json;

  my $have_seq = 0;
  my $md5    = undef;
  my $desc   = undef;
  my $length = undef;

  if((defined $decoded_json->{'results'}) &&
     (defined $decoded_json->{'results'}[0]{'md5'}) &&
     (defined $decoded_json->{'results'}[0]{'rnacentral_id'})) {
    $have_seq = 1;
    $md5    = $decoded_json->{'results'}[0]{'md5'};
    $desc   = $decoded_json->{'results'}[0]{'description'};
    $length = $decoded_json->{'results'}[0]{'length'};
  }
  return ($have_seq, $md5, $desc, $length);
}

#-------------------------------------------------------------------------------
=head2 rnacentral_subseq_lookup
  Title    : rnacentral_subseq_lookup
  Incept   : AIP, Mon Aug 17 10:00:00 2020
  Function : Looks up (sub)sequence in RNAcentral and returns its md5.
  Args     : $nse: URS_taxid/start-end of a sequence from SEED
  Returns  : 2 values:
           : $have_seq:  '1' if sequence URS[0-9A-F]{10} exists in RNAcentral, else '0'
           : $md5:       if $have_seq is '1': RNAcentral md5 for subsequence from start-end, else undefined
  Dies     : if there is a problem fetching from RNAcentral
=cut

sub rnacentral_subseq_lookup {
  my ( $nse, $seed_md5 ) = @_;

  my ($is_nse, $name, $start, $end, $strand) = nse_breakdown($nse);

  my $urs;
  if ($nse =~ /^(URS[0-9A-F]{10})/) {
    $urs = $1;
  } else {
    return (0, undef);
  }

  my $rnacentral_url = "https://rnacentral.org/api/v1/rna/" . $urs . ".fasta";
  my $fasta = get($rnacentral_url);
  if(! defined $fasta) { croak "ERROR trying to fetch fasta from RNAcentral $rnacentral_url"; }

  my @lines = split(/^/m, $fasta);
  my $sequence = '';
  for my $line (@lines) {
      if ($line =~ /^>/) {
        next;
      }
      chomp($line);
      $sequence .= $line;
  }

  my $subseq = '';
  if ($strand == 1) {
      $subseq = substr($sequence, $start-1, $end-$start+1);
  } else {
    warn("Found RNAcentral sequence in reverse orientation: $nse");
    return (0, undef);
  }
  my $subseq_md5 = md5_of_sequence_string($subseq);

  return(1, $subseq_md5);
}

#-------------------------------------------------------------------------------
=head2 id_looks_like_rnacentral
  Title    : id_looks_like_rnacentral
  Incept   : EPN, Fri Feb 22 16:24:58 2019
  Function : Returns '1' if $id 'looks like' a RNAcentral ID
  Args     : $id: sequence name
  Returns  : '1' if $id 'looks like' it is from RNAcetnral
           : '0' if it does not
=cut

sub id_looks_like_rnacentral {
  my ( $id ) = @_;

  if($id =~ /^URS[0-9A-F]{10}/) {
    return 1;
  }
  return 0;
}

#-------------------------------------------------------------------------------
=head2 rnacentral_urs_taxid_breakdown

  Title    : rnacentral_urs_taxid_breakdown
  Incept   : EPN, Tue May  7 14:08:46 2019
  Usage    : rnacentral_urs_taxid_breakdown($rnacentral_id)
  Function : Checks if $rnacentral_id is of format "URS_taxid",
           : where URS matches /^URS[0-9A-F]{10}/ and taxid is
           : an integer, and breaks it down into $urs, $taxid
           : (see 'Returns' section)
  Args     : <sqname>: seqname, possibly of format "URS_taxid"
  Returns  : 3 values:
           :   '1' if <sqname> is of "URS_taxid" format, else '0'
           :   $urs:   the URS part of <sqname>, undef if <sqname> does not match URS_taxid
	   :   $taxid: the taxid part of <sqname>, undef if <sqname> does not match URS_taxid
=cut

sub rnacentral_urs_taxid_breakdown {
  my ($sqname) = $_[0];

  my $urs;    # URS id
  my $taxid;  # taxid

  if($sqname =~ /^(URS[0-9A-F]{10})\_(\d+)$/) {
    ($urs, $taxid) = ($1,$2);
    return(1, $urs, $taxid);
  }
  return (0, undef, undef);
}

#-------------------------------------------------------------------------------
=head2 accession_version_breakdown

  Title    : accession_version_breakdown
  Incept   : EPN, Fri May 10 17:04:20 2019
  Usage    : accession_version_breakdown($accver)
  Function : Checks if $accver is of format /^\S+\.\d+$/
           : without checking that accession is actually a
           : valid accession (any string is allowed)
           : and breaks down into accession and version.
           : (see 'Returns' section)
  Args     : <sqname>: seqname, possibly of format /\S+\.\d+/
  Returns  : 3 values:
           :   '1' if <sqname> is in /^\S+\.\d+$/ format, else '0'
           :   $acc: the \S+ part of the matching <sqname>, undef if first return value is '0'
	   :   $ver: the \d+ part of the matching <sqname>, undef if first return value is '0'
=cut

sub accession_version_breakdown {
  my ($sqname) = $_[0];

  my $acc;
  my $ver;

  if($sqname =~ /^(\S+)\.(\d+)$/) {
    ($acc, $ver) = ($1,$2);
    return(1, $acc, $ver);
  }
  return (0, undef, undef);
}

#-------------------------------------------------------------------------------
=head2 strip_version
  Title    : strip_version
  Incept   : EPN, Tue Apr 30 21:09:22 2019
  Function : Removes a version from an accession.version string
  Args     : $accver: accession.version
  Returns  : $accver with version removed, if $accver not in the
           : correct format, just returns what is passed in
=cut

sub strip_version {
  my ( $accver ) = @_;

  $accver =~ s/\.\d+$//;

  return $accver;
}

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Miniature helper subroutines
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

