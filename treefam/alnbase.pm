package treefam::alnbase;

=head1 NAME

  treefam::alnbase - basic utilities for handling multialignment

=head1 SYNOPSIS

=head1 DESCRIPTION

This module mainly provides two methods. One is for locating splicing
boundaries on an alignment, and the other for locating domain regions and
aligned parts. These two might be of little interest to ordinary users
who might prefer high-level interface in L<treefam::align> module.

=head2 Functions

=cut

use strict;
use warnings;

use Exporter;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw();

sub new
{
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = { @_ };
	bless($self, $class);
	return $self;
}

=head3 cigar2site

  Args [4]    : string $aa_cigar, string $nt_map, ARRAY ref $rst, ARRAY ref $rst2
  ReturnType  : NONE
  Example     : $aln->($cigar, $map, \@rst, \@rst2);
  Description : Locate splice sites in aligment coordinates. $aa_align is the
                CIGAR line. $nt_map stores splicing sites in genomic
				coordinates. In return, $rst2->[$i] gives the i-th splic site
				in alignment coordinates, while $rst2->[$i] indicates the number
				of alignment gaps following the i-th splice site.

=cut

sub cigar2site
{
	my ($self, $aa_cigar, $nt_map, $rst, $rst2) = @_;
	# read nt_map
	$_ = $nt_map;
	my @t = split;
	my @t2 = split(',', $t[8]);
	my @t3 = split(',', $t[9]);
	my ($start, $stop, @s, $l);
	$l = 0;
	if ($t[2] eq '+') {
		for (my $i = 0; $i < $t[7]; ++$i) {
			next if ($t3[$i] < $t[5] || $t2[$i] >= $t[6]);
			$start = ($t2[$i] < $t[5])? $t[5] : $t2[$i];
			$stop = ($t3[$i] >= $t[6])? $t[6] : $t3[$i];
			$l += $stop - $start;
			push(@s, $l);
		}
	} else {
		for (my $i = $t[7]-1; $i >= 0; --$i) {
			next if ($t3[$i] < $t[5] || $t2[$i] >= $t[6]);
			$start = ($t2[$i] < $t[5])? $t[5] : $t2[$i];
			$stop = ($t3[$i] >= $t[6])? $t[6] : $t3[$i];
			$l += $stop - $start;
			push(@s, $l);
		}
	}
	@t = (); @t2 = (); @t3 = ();
	# read aa_cigar
	my ($i, $j, $m, $d);
	my $cigar = $aa_cigar;
	$i = 0;
	$cigar =~ s/(\d+)([MD])/($t[$i]=$1*3),($t2[$i++]=$2),"$1$2"/eg;
	# consistency check
	$d = $s[@s-1];
	for ($j = $m = 0; $j < @t; ++$j) {
		$m += $t[$j] if ($t2[$j] eq 'M');
	}
	if ($m != $d && $m != $d - 3) { # 3 for possible stop codon
		warn("[treefam::alnbase::cigar2site] inconsistency occurs ($m != $d), continue anyway");
	}
	$l = $m;
	# fill result
	for ($i = $j = $m = $d = 0; $i < @t; ++$i) {
		if ($t2[$i] eq 'M') {
			while ($m < $s[$j] && $m + $t[$i] >= $s[$j]) {
				if ($m + $t[$i] == $s[$j] && $i+1 < @t && $t2[$i+1] eq 'D') {
					push(@$rst2, $t[$i+1]);
				} else {
					push(@$rst2, 0);
				}
				last if ($s[$j] >= $l);
				push(@$rst, $d + $s[$j++]);
			}
			$m += $t[$i];
		} elsif ($t2[$i] eq 'D') {
			$d += $t[$i];
		}
	}
	return $l;
}

####################################################################
#
# structure of $aln (necessary information):
#
#     $aln->{CIGAR}				CIGAR line
#     @{$aln->{PFAM}}			domain information
#       $aln->{PFAM}[$i]{V}		e-value
#       $aln->{PFAM}[$i]{B}		start position (0 based)
#       $aln->{PFAM}[$i]{E}		end position (0 based)
#       $aln->{PFAM}[$i]{N}		Pfam accession
#
# This structure is usually generated by treefam::db::get_aln_pos()
#
####################################################################

sub get_pos_hash
{
	my ($self, $aln, $pos, $tot_len) = @_;
	my ($is_overlap, $is_finished, $is_begin, $l, $k, $i, $len) = (0, 0, 1, 0, 0, 0, 0);
	$self->resolve_ol_domain($aln);
	my $pfam = $aln->{PFAM};
	unless ($tot_len) {
		$tot_len = 0;
		$_ = $aln->{CIGAR};
		s/(\d+)[MD]/$tot_len+=$1,''/eg;
	}
	my $cur = (@$pfam)? $pfam->[0]{B} : $tot_len;
	$_ = $aln->{CIGAR};
	while (1) {
		if (!$is_overlap) {
			$l += $len; $k += $len;
			while (1) {
				if (s/^(\d+)M//) {
					$len = $1;
					$pos->{$k} = 0x01; $pos->{$k+$len} = 0x02;
					last;
				} elsif (s/^(\d+)D//) {
					$k += $1;
				} else {
					$is_finished = 1; last;
				}
			}
		}
		last if ($is_finished);
		$is_overlap = 0;
		if ($is_begin) {
			if ($l <= $cur && $l + $len > $cur) {
				my $t = $k + ($cur - $l);
				if (defined($pos->{$t})) { $pos->{$t} |= 0x10; } else { $pos->{$t} = 0x10; }
				$is_begin = 0;
				$is_overlap = 1;
				$cur = $pfam->[$i]{E};
			}
		} else {
			if ($l < $cur && $l + $len >= $cur) {
				my $t = $k + ($cur - $l);
				if (defined($pos->{$t})) { $pos->{$t} |= 0x20; } else { $pos->{$t} = 0x20; }
				$is_begin = 1;
				$is_overlap = 1;
				$cur = ($i+1 < @$pfam)? $pfam->[++$i]{B} : $tot_len;
			}
		}
	}
}
sub resolve_ol_domain
{
	my ($self, $aln) = @_;
	my @pfam = @{$aln->{PFAM}};
	my @t = sort {$a->{V}<=>$b->{V}} @pfam;
	my @s;
	for (my $i = 0; $i < @t; ++$i) {
		my $is_del = 0;
		for (my $j = 0; $j < $i; ++$j) {
			if ($t[$i]{B} <= $t[$j]{B}) {
				unless ($t[$i]{E} <= $t[$j]{B}) {
					$is_del = 1;
					last;
				}
			} else {
				unless ($t[$j]{E} <= $t[$i]{B}) {
					$is_del = 1;
					last;
				}
			}
		}
		push(@s, $t[$i]) unless ($is_del);
	}
	delete($aln->{PFAM});
	@{$aln->{PFAM}} = sort {$a->{B}<=>$b->{B}} @s;
}

1;

=head1 AUTHOR

Heng Li <lh3@sanger.ac.uk>

=cut
