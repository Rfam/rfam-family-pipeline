#!/usr/local/bin/perl


use Getopt::Long;

use lib '/nfs/intweb/server/cgi-bin/Rfam';

use RfamWWWConfig;


my($input_dir, $output_dir, $file_type, $ss_cons_only, $family);

&GetOptions(  'input_dir=s' => \$input_dir,
	      'output_dir=s' => \$output_dir,
	      'file_type=s' => \$file_type,
	      'ss_cons_only' => \$ss_cons_only,
	   'family=s' => \$family);

die "need input_dir\n" if(!$input_dir);
die "need output_dir\n" if(!$output_dir);
die "need file_type , either seed or full \n" if (!$file_type);





my @colours = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t");

my %colours_count;
my $count = 0;
foreach (@colours) {
  $colours_count{$_} = $count;
  $count++;
}


my(@seq, @sec_struc, $conserved, %names);
my $count = 0;
my $total_count = 0;
my $maxname_len = 0;
my (@arrays, @new_seq);
my $length;
my @blocks;
my $conserved;
#my $total_seq_count;

$input_dir = $input_dir . "/$file_type";

if ($family) {
  $family .= ".full.gz";
  _do_one_family($family, $input_dir, $output_dir, $file_type, $ss_cons_only);
  exit(0);
}


opendir(_WHOLE, "$input_dir") || die("Could not open $input_dir $!");

foreach my $file ( readdir(_WHOLE) ) {


  $file =~ /^\.+$/ && next;
  _do_one_family($file, $input_dir, $output_dir, $file_type, $ss_cons_only  );
} 


sub _do_one_family {

  my($file, $input_dir, $output_dir, $file_type, $ss_cons_only) = @_;

  @blocks = @arrays = @new_seq = @seq = @sec_struc = ();
  %names = {};
  $count = $total_count = $maxname_len =  $length = $conserved = undef;

  
  my $file_sub;
  $file_sub = $1 if ($file =~ /(RF\d+\.full).gz/);

  my $complete_file = $input_dir . "/" . $file;

 # $complete_file = "/nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/full/Rfam.full.tmp";
#  print "FILE: $complete_file \n";
 # my $file_sub;
 # $file_sub = $1 if ($file =~ /(RF\d+\.full.gz)/);

  my $complete_out = $output_dir . "/" . $file_type. "/" . $file_sub;
#print "OUT: $complete_out \n";
  #$complete_out = "/nfs/WWWdev/SANGER_docs/htdocs/Software/Rfam/data/markup_align/full/Rfam.full.tmp";


  open(_FILE, "gunzip -c $complete_file |");
 #  open(_FILE, " $complete_file |") or print "CANNA AS $! \n";
  
  while(<_FILE>) {
  #  print "$_ ";
    next if ($_ =~ /\# STOCKHOLM/);
    chop($_);
    #print "$_";
    
    if ($_ !~ /^\#/) {
      if ($_ =~ /(\S+)\s+(\S+)/ ) {
	$seq[$count] .= $2 ;
	#    my $seq = $2;
	#   print "seq: $seq \n";
	#     $length = length $seq if(!$length);
	my $name = $1;
	#  print "NAME: $name :: len : " . length($name) ." \n"; sleep 1;
	#    chop($1);
	$names[$count] = $1;
#	print "NAME: $1 \n";
#	print "COUNT: $count \n" if ($1 =~ /U41756/);
	$maxdisplayname_length = length $1 if (length $1 > $maxdisplayname_length);
	if ( ($file_type =~ /seed/i) || ($ss_cons_only)  ) {
	  
	  $count++;
	  
	}



      }
      #  print "COUNT: $count :: seq: $1 \n";
      
    } elsif ($_ =~ /\#=GR\s+\S+\s+SS\s+(\S+)/) { 
      $sec_struc[$count] .= $1;
      $count++;
      
      
      
    } elsif ( $_ =~  /\#=GC\s+SS_cons\s+(\S+)/) {
 #     print "$_ \n";
      $conserved .= $1;
      $count = 0;
      
      
    }
    
    
    
  }
  
 # $seq_count = $count;
 # print "COUNT: $total_seq_count \n";

  $length = length $seq[1];
  #print "LEN: $length \n";
  #exit(0);
  
  $maxdisplayname_length = $maxdisplayname_length + 1;
  
  close(_FILE) or die "CANNA CLOSE FILE $complete_file  AS $! \n";
  
  
  
  my $start = 0;
  #print "LENGTH: $length \n";
  

  while($start < $length) {
    push @blocks, $start;
    
    $start = $start + 79;
  }
  
  #print "LENGTH: $length :: BLOCKS: @blocks \n";
  
  my $count = 0;
  
  
  my %all_arrays;
  
  
  
  my $file_count = 1;
  my $count_track = 0;
  
  my ($junk, $temp_arr, $temp_col, %cons_colour) = _add_markup("" , $conserved );

  my @col_blocks = @{$temp_arr};
  my @col_colours_blocks = @{$temp_col};
  

#  print "HERE @col_blocks \n";
#  exit(0);
#  foreach my $key(sort keys %cons_colour) {
#    print "key: $key, val: " . $cons_colour{$key}. " \n";
#  }


 

  my $key = 0;

  my %fix_colours;
  my $colour_count = 0;

  my @colour_map;
  my(%lowest, %highest);

  my $last = undef;

 # print "OLD: @col_colours_blocks\n";

  foreach (@col_colours_blocks) {
    
    if(defined($fix_colours{$_})) {
      
    } else {
      
      $fix_colours{$_} = $colours[$colour_count];
      
      $colour_count++;
      
    }

    push @colour_map, $fix_colours{$_};

  }

 # foreach (sort keys %fix_colours) {
#    print "key: $_ :: val: " .$fix_colours{$_} . "\n";
#  }
#print "NEW: @colour_map \n";

  while($key <= $length) {
    
#    if(defined($fix_colours{$cons_colour{$key}})) {
      
#    } elsif ($cons_colour{$key} =~ /[a-z]/) {
      
#      $fix_colours{$cons_colour{$key}} = $colours[$colour_count];
      
#      $colour_count++;
      
#    }
    
    
    if (defined($cons_colour{$key})) {
      
     # print "KEY: $key :: val: " . $cons_colour{$key}. " \n";

      $cons_colour{$key} = $fix_colours{$cons_colour{$key}};
     # print "letter: " .$cons_colour{$key} . " count: " .$key . " \n";

      
#      ### find lowest
#      if (defined($lowest{$cons_colour{$key}})) {
#	$lowest{$cons_colour{$key}} = $key if ($key < 	$lowest{$cons_colour{$key}});
#      } else  {
#	$lowest{$cons_colour{$key}} = $key;	
#      }

#      ### find highest
#      if (defined($highest{$cons_colour{$key}})) {
#	$highest{$cons_colour{$key}} = $key if ($key > 	$highest{$cons_colour{$key}});
#      } else  {
#	$highest{$cons_colour{$key}} = $key;	
#      }
     

      
 #     if ($cons_colour{$key} ne $last) {
#	push @colour_map, $cons_colour{$key};
#	$last = $cons_colour{$key};
#      }

      
    }

    $key++;
  
  }
  
#exit(0);
#  my %colour_blocks;

#  foreach my $letter (sort keys %lowest) {
#    $colour_blocks{$letter} = $lowest{$letter} . "~" . $highest{$letter};
#   # print "letter: $letter , lowest: " . $lowest{$letter}. " , highest: " .$highest{$letter} . " \n";
    
#  }


#  print "COL: @colour_map \n";

#  exit(0);
  $cons_colour{SS} = 1;

#  my %cons_last_colour = %cons_colour;
#  $cons_last_colour{last} = 1;

  
my $print = 0;
  foreach (@seq) {
    my $the_seq = $_;
    push @new_seq, $the_seq;
   # print "NAME: " . $names[
    my($new_seq, %colour, $temp);
 #   $print = 1 if ($count eq 12);
    if ( ($file_type =~ /full/i) && (!$ss_cons_only)  ){ 
      ($new_seq, $temp, $temp_cols, %colour) = _add_markup($the_seq, $sec_struc[$count] , $print);
      
   #   foreach (sort keys %colour) {
#	print "key: $_ :: val: " .$colour{$_} . " \n";
#      }

      my @temp_blo_col = @{$temp};
      my @temp_col_col_block = @{$temp_cols};

      my $last;
      my @col_map;


      %fix_colours = undef;

      my $colour_count = 0;

      foreach (@temp_col_col_block) {
    
#	print "BLEE: $_ \n";
	if(defined($fix_colours{$_})) {
      
	} else {
      
	  $fix_colours{$_} = $colours[$colour_count];
      
	  $colour_count++;
      
	}

	push @col_map, $fix_colours{$_};

      }

 #     print "TEMP : @temp_col_col_block\n";
    #  foreach (@temp_col_col_block) {
#		print "BLEE: $_ \n";
#	push @col_map,$fix_colours{$_}; 
	
#      }



      my $key = 0;
      my $first  = 1;
      while($key <= $length) {

	if (defined($colour{$key})) {

#	  print "OLD: " .$colour{$key} . "  ::  ";
	  $colour{$key} = $fix_colours{$colour{$key}};
#	  print  "NEW : " . $colour{$key}. " \n";
#	  if ($colour{$key} ne $last) {
#	    push @col_map, $colour{$key};
#	    $last = $colour{$key};
#	  }

	  if ($first) {
	  #  print "COL: $colour{$key} \n";
	    $first = 0;
	  }
	}

	$key++;

      }

     
      if (@col_map eq @colour_map) {
#	print "EQUALS \n";
      } else {

	%colour = undef;
	my $key = 0;

	my $cons_arrows = $conserved ;
	
	my $new_seq = $the_seq;
	my $new_arrows = $sec_struc[$count];

	my %temp_new_colours;

	while($key <= $length) {
	  
	  my $sub_cons_arrow = substr($cons_arrows, $key, 1);
	  my $sub_new_seq = substr($new_seq, $key, 1);
	  my $sub_new_arrows = substr($new_arrows, $key, 1);

	#  print "SUB ARROW: $sub_cons_arrow  :: NEW ARROW: $sub_new_arrows -> letter $sub_new_seq \n";

	  if ( $sub_cons_arrow ne $sub_new_arrows) {

	  # print "SUB ARROW: $sub_cons_arrow  :: NEW ARROW: $sub_new_arrows -> letter $sub_new_seq \n";
	  } else {
	    $temp_new_colours{$key} = $cons_colour{$key};
	  }

	  $key++;
	}
	%colour = undef;
	%colour = %temp_new_colours;

#	exit(0);

#	print "DONT EQUAL \n";
#	print "\n\n@col_map\n";
#	print "@colour_map\n";
##	exit(0);


#	my $key = 0;
#	my %new_fix_colours;
##	my @new_colour_map;
##	my $last;
#	my $colour_count = 0;


##	my (%temp_highest, %temp_lowest);


#	  while($key <= $length) {
	    
#	    if(defined($new_fix_colours{$colour{$key}})) {
	      
#	    } elsif ($colour{$key} =~ /[a-z]/) {
	      
#	      $new_fix_colours{$colour{$key}} = $colours[$colour_count];
	      
#	      $colour_count++;
	      
#	    }
	    
	    
#	    if (defined($colour{$key})) {
	      
#	      $colour{$key} = $new_fix_colours{$colour{$key}};


	      
	      
#	    }
	    
#	    $key++;
	    
#	  }



#	my %new_fixed_hash;
##	print "NEW: @new_colour_map \n";
#	my $let_count = 0;
#	foreach my $letter ( @col_map) {
#	  my($min, $max) = split(/~/, $temp_blo_col[$let_count]);
#	  my $middle = $max - $min;
#	  $middle = $middle / 2;
#	  $middle = $middle + $min;
#	  print "\nlet: $letter :: min: " . $min. " max: " . $max. " middle: $middle \n";
#	  my $int_count = 0;
#	  my $min_let = 99999;
#	  foreach (@col_blocks) {
##	    print "EEP : $_ \n";
#	    my($col_min, $col_max) = split(/~/, $_);
#	   # if (($min eq $col_min)) { print "EEP ! \n"};
#	    print "MIN: $min to col min: $col_min ::  MAX: $max to col max: $col_max which is SS_cons : " .$colour_map[$int_count] . " \n";
#	    if ( ( ( $middle >= $col_min) && ($middle <= $col_max)) || ($min eq $col_min) || ($max eq $col_max) ) {

#	      print "VAL: " . $colour_map[$int_count] ."  to : ".$colours_count{$colour_map[$int_count]} . " \n";
	   


#	    #  $min_let = $colours_count{$colour_map[$int_count]} if ( $colours_count{$colour_map[$int_count]} < $min_let); 
#	      $new_fixed_hash{$letter} = $colour_map[$int_count];
#	      print "LETTER: $letter \n";

#	           print "MATCH : " .$new_fixed_hash{$letter} .  " get: " . $colour_map[$int_count] . " :: COUNT: $int_count   MIN: $min_let  :: " .$colours[$min_let] . " \n";
#	     # $new_fixed_hash{$letter} = $colours[$min_let];
#	    #  exit(0);
#	    }
#	    $int_count++;

#	  }

	  
	  
#	  $let_count++;
#	}
#	exit(0);

	
#	my $key = 0;

#	while($key <= $length) {
	  
	  
#	  if (defined($colour{$key})) {
	    
#	    $colour{$key} = $new_fixed_hash{$colour{$key}};
	    
	    
#	  }
	  
#	  $key++;
	  
#	  }
	
	
	
##	print "\n\n";
##	exit(0);

      }

    } else {

      ### Got a seed alignment

     # ($new_seq, $temp, $temp_cols, %colour)
      ($new_seq, $temp, $temp_cols,%colour) = _add_markup($the_seq, $conserved);

      
      
      my $key = 0;
      my %new_fix_colours;
      my $colour_count = 0;
      
      
      
      
      while($key <= $length) {
	
	if(defined($new_fix_colours{$colour{$key}})) {
	  
	} elsif ($colour{$key} =~ /[a-z]/) {
	  
	  $new_fix_colours{$colour{$key}} = $colours[$colour_count];
	  
	  $colour_count++;
	  
	}
	
	
	if (defined($colour{$key})) {
	  
	  $colour{$key} = $new_fix_colours{$colour{$key}};
	  
	  
	  
	}
	$key++;
	
      }
      
      
      
      


    }
      
  #   print "\n\n$new_seq \n" if ($count eq 11);
    #exit(0);
#    my $colour_array = %colour;
    
    push @arrays, \%colour;
    
    $count++;
  #  exit if ($count > 12);
    if (not($count % 500)) {
      my $file_out = $complete_out . "." . $file_count;
      push @arrays, \%cons_colour;
      push @new_seq, $conserved;

      _print_to_file( $count_track, $file_out);
      @new_seq = ();
      @arrays = ();
      $file_count++;
      $count_track = $count_track + 500;
      
    }
    
  }
  #print "SEQ: @new_seq \n";

  push @arrays, \%cons_colour;
  push @new_seq, $conserved;
  my $file_out = $complete_out . "." . $file_count;
  _print_to_file( $count_track, $file_out) if(defined($new_seq[0]));
  

}



#print "BLOCKS: @blocks SEQ: @seq\n";





#########################################
#
#   print the marked up sequences to file :-)
#
##########################################

sub _print_to_file {

  my ( $seq_name_count, $file_out)  = @_;
#  print "FILE OUT: $file_out \n";
  open(_OUT, ">$file_out");
#  print _OUT "<html><head><link REL=\"stylesheet\" HREF=\"rfam_align.css\"></head><body>";
  
  my $block_count = 0;
 # print "BLOCKS: @blocks \n";
  print _OUT "<pre>";
  foreach my $block (@blocks) {
 #    print "bloock: $block \n";sleep 1;
    my $internal_seq_name_count = $seq_name_count;
    my $seq_count  = 0;
    foreach my $seq (@new_seq) {
      my $parsed_sub;
      #  print "SEQ: $seq \n"; sleep 1;
      my $sub = substr($seq, $block, 79);
      
      my $sub_count = 0;
      
      #  my $tmp_block = $block;
      
      while($sub_count < 79) {
	my $tmp_sub = substr($sub, $sub_count, 1);
	my $prefix = $sub_count + $block;
	if(defined($arrays[$seq_count]{$prefix})) {
	  $tmp_sub = "<b ID=\"" .$arrays[$seq_count]{$prefix} . "\">$tmp_sub</b>";
	  #	print "SUB: $tmp_sub \n";
	} else {
	  $tmp_sub = "<b>$tmp_sub</b>";
	}
	
	
	$parsed_sub = $parsed_sub . $tmp_sub;
	$sub_count++;
      }
      #  print "PARSED: $parsed_sub \n";
      #  print "MAX: $maxdisplayname_length : LEN: " . . " 

      my $name; 
      my $spaces;

      if(defined($arrays[$seq_count]{SS}) ) {
#	print "SS_cons " .$names[$internal_seq_name_count] . "  : COUNT: $internal_seq_name_count \n";
#	print _OUT "\n";
	$spaces = "&nbsp;" x ($maxdisplayname_length - length("SS_cons"));
	$name = "<a name=\"" . $seq_count . "~" . $blocks[$block_count] . "\">SS_cons</A>";
      } else {
	my $link = $RfamWWWConfig::srsserver;
#	print "LINK: $link \n";
	my $acc = $1 if ($names[$internal_seq_name_count] =~ /^(\S+)\// );
#	print "ACC: $acc \n";
	$link =~ s/ACC/$acc/;
#	print "FINAL : $link \n";
#exit(0);
	$name = "<a name=\"" . $seq_count . "~" . $blocks[$block_count] . "\"><A href=$link>" . $names[$internal_seq_name_count] . "</A></A>";
	$spaces = "&nbsp;" x ($maxdisplayname_length - length($names[$internal_seq_name_count])); 
      }

    #  my $spaces = "&nbsp;" x ($maxdisplayname_length - length($names[$internal_seq_name_count])); 
      # print "SUB: $sub \n seq: $seq \n\n";

  

      # print "Name: $name \n"; sleep 1;
      my $next = "<A HREF=#" . $seq_count . "~" . $blocks[$block_count + 1]. ">Next</A>" if (defined($blocks[$block_count + 1] ) );
  
      my $prev = "<A HREF=#" . $seq_count . "~" . $blocks[$block_count - 1]. ">Prev</A>" if ( $block_count > 0 );

 #     print "BLOCK: $block_count :: PREV: $prev \n";

      print  _OUT  sprintf("%s%s%s  %s %s\n", $name, $spaces,  $parsed_sub, $next, $prev);
      
      # print _OUT "$names[$seq_count]$spaces$parsed_sub <br>";
      
      # my $spaces = "        ";
      # print _OUT  sprintf("%-22s      %s\n",$names[$seq_count],$parsed_sub);
      # print _OUT $names[$seq_count] . "  $parsed_sub<br>";
      $seq_count++;
      $internal_seq_name_count++;
    }
  
    print _OUT "\n\n";
    $block_count++;
  }

  print _OUT "</pre>";
  close(_OUT);
  system("gzip -f $file_out");
 # exit(0);


}



#############################
#
#  SUB _add_markup
#
#############################

sub _add_markup {
  
  my($seq, $sec_struc, $print) = @_;
  # print "\n$seq\n$sec_struc \n" if ($print);
  my $new_seq, $new_sec_struc;
  
  
 
  
  my @font_colours;
  open(_COL, "/nfs/WWW/htdocs/Pfam/data/hex_colours");
  while(<_COL>) {
    my($num, $color, @junk) = split(/~/, $_);
    push @font_colours, $color;
    
  }
  
  close(_COL);
  
  
  my $old = $sec_struc;
  
  ## work out loops and covarence
  my $length = length $sec_struc ;
  #	  print "LEN: $length <P>";
  my $start = 0;
  my $count = 0;
  my $for_prev = 0;
  my $back_prev = 0;
  my %new_block_track;
  my (%for_storage, %back_storage);
  my $new_block = 0;
  
  
  my %seq_colour;
  
  my %text_colour;
  
  my $font_color = 0;
  
  my @arr;
  my @txt_arr;
  my $first = 1;
  

  ## temp var
 # my $blee_for = 0;
 # my $blee_back = 0;

  my %arrows;

  while($start <= $length) {
    my $sub = substr($sec_struc, $start, 1);
    
    my $txt_sub =  substr($seq, $start, 1);
 #   print "$txt_sub :$sub :: " if ( ($print) && ($sub =~ /[\>|\<]/)  );
    if ( ($sub eq "<") || ($sub eq "{") ||  ($sub eq "(") ||  ($sub eq "[") ){
  #    $blee_for++;
      $arrows{$start} = "for";

      $count++ if(!$back_prev);
      $for_storage{$count} = $start;
      #	print "$sub: $start :: count: $count :: stor: " .$for_storage{$count} .  " <BR>";
      
      if ( ($back_prev) || ($first) ) {
	$new_block_track{$count} = $count;
	#	  print "TRACK: " .$new_block_track{$count}  ." <BR>";
	$first = 0;
      }
      
      if ($back_prev) {
	$new_block++;
	$font_color = 0;
	# $new_block{$count} = $count;
	
      }
      $for_prev = 1;
      $back_prev = 0;
      
    }	elsif ( ($sub eq ">") || ($sub eq "}") ||  ($sub eq ")") ||  ($sub eq "]") ){
   #   $blee_back++;
      $count-- if (!$for_prev);
      $back_storage{$count} = $start;
       $arrows{$start} = "back";
      
      if ($for_prev) {
	#  $new_block = 1;
      }
      #	print "SUB: $sub \n";
      
      #		$arr[$for_storage{$count} ] =  "<font color=#" . $colours[$new_block] . "><B>></B></font>";
      $arr[$for_storage{$count}] =  "<b ID=\"" . $colours[$new_block] . "\">" .$arr[$for_storage{$count} ] . "</b>";

   #   print " arr: " .  $arr[$for_storage{$count}]. " IS: " . $txt_arr[$for_storage{$count}] . "  " if ($print);

      $seq_colour{$for_storage{$count}} = $colours[$new_block];
      #	print "SEQ: " .$for_storage{$count} . " eq : " .$seq_colour{$for_storage{$count}} . " \n";
      
      $seq_colour{$start} = $colours[$new_block];
      
      #		$sub = "<font color=#" . $colours[$new_block] . "><b><</b></font>";
      $sub = "<b ID=\"" . $colours[$new_block] . "\"><</b>";
   #   print " sub: $sub IS : " . $colours[$new_block]. " \n" if ($print);
#      print "$sub :: COLOURS: " .$colours[$new_block]  . " :: NEW : $new_block \n";
      
      
      
      #	$txt_sub = "<font color=#" . $colours[$new_block] . "><b>$txt_sub</b></font>";
      $txt_sub = "<b ID=\"" . $colours[$new_block] . "\">$txt_sub</b>";
      
      #		$txt_arr[$for_storage{$count}] =  "<font color=#" . $colours[$new_block] . "><B>" . 	$txt_arr[$for_storage{$count}]. "</B></font>";
      $txt_arr[$for_storage{$count}] =  "<b ID=\"" . $colours[$new_block] . "\">" . 	$txt_arr[$for_storage{$count}]. "</b>";
      
      
      $font_color++;
      
      #	print "NEW: $sub <BR>";
      if (defined($new_block_track{$count})) {
	$new_block_track{$count} = undef;
	$new_block++;
	$font_color = 0;
      }
      $for_prev = 0;
      $back_prev = 1;
    } else {
      ## default
      $sub = "<b>$sub</b>";
      
    }
    
    
    push @arr, $sub;
    push @txt_arr, $txt_sub;
    
    $start++;
    
  }
  
  
  
  my $tmp;
  foreach (@arr) {
    $tmp = $tmp . "$_";
    
  }
  $sec_struc = $tmp;
  
  my $tmp;
  foreach (@txt_arr) {
    if ($_ !~ /ID/) {
      #	       print "$_ :: ";
      $_ = "<b>$_</b>";
    }
    
    $tmp = $tmp . "$_";
  }

  $new_seq = $tmp;
  
#  print "FOR:  $blee_for  BACK: $blee_back \n\n";

#  my @blee = ("1", "2", "3");
  my @blocks;
  my @col_blocks;
  my $start = 0;
  my ($last_arrow, $last_col, $num_start, $num_end , $last_num);
  while ($start <= $length) {
  #foreach my $key (sort keys %arrows) {
    if (defined($arrows{$start}  ) ) {
      if ( ( $last_arrow ne $arrows{$start}) || ($last_col ne   $seq_colour{$start}  ) ) {

    #  if ($last_col ne   $seq_colour{$start}) {  
	
	push @blocks, $num_start . "~" . $last_num if ($num_start);
	push @col_blocks, $seq_colour{$start};
 
	$num_start = $start;

	$last_arrow = $arrows{$start};
	$last_col =  $seq_colour{$start};

      } else {
	$last_num = $start;
      }

#      print "key: $start :: arrow: " . $arrows{$start}. " :: colour: "  . $seq_colour{$start}. " \n";
      

    }
    $start++;
  }

  push @blocks, $num_start . "~" . $last_num if ($num_start);

  #print "num_start: $num_start :: last : $last_num \n\n";
  #print "BLOCKS: \n@blocks \n\n";
 # print "COL: \n@col_blocks\n";

# exit(0);

  return $new_seq, \@blocks, \@col_blocks,  %seq_colour;
}
