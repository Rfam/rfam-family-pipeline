my $usage = "perl seed-desc-to-cm.pl <SEED file with DESC> <CM file to add DESC to>";
if(scalar(@ARGV) != 2) { 
  die $usage;
}
($seed, $cm) = (@ARGV);
open(SEED, $seed) || die "ERROR unable to open $seed";

while($line = <SEED>) { 
  if($line =~ m/#=GF\s+AC\s+(RF\d\d\d\d\d)/) { 
    if(($nacc > 0) && ($seen_desc == 0)) { 
      die "ERROR didn't read desc for accession $acc";
    }
    $acc = $1;
    $nacc++;
    $seen_desc = 0;
  }
  if($line =~ m/#=GF\s+DE\s+(.+)$/) { 
    $desc_H{$acc} = $1;
    $seen_desc = 1;
#    printf("$acc $desc_H{$acc}\n");
  }
}
close(SEED);

open(CM, $cm) || die "ERROR unable to open $cm";
while($line = <CM>) { 
  print $line;
  if($line =~ m/^ACC\s+(RF\d\d\d\d\d)/) { 
    $acc = $1;
    if(! exists $desc_H{$acc}) { die "ERROR no desc read in seed for $acc in CM file"; }
    print "DESC     $desc_H{$acc}\n";
  }
}
close(CM);

