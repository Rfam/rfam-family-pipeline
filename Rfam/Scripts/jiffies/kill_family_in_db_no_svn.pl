
# Move rfam_acc to the dead_family table, delete family from all other tables
# The script does not rely on the SVN code so can be used for the "ghost families"
# that exist only in the database but not the SVN.
#
# Example: kill_family_in_db_no_svn.pl -s "Delete ghost family" -f "RF0XXXX" -a 'apetrov' RF0YYYY

use strict;
use warnings;
use Cwd;
use Data::Dumper;
use Getopt::Long;

use Bio::Rfam::Config;

my $config = Bio::Rfam::Config->new;


#------------------------------------------------------
# User options

my ( $comment, $forward, $author, $help );

&GetOptions(
  "m=s"  => \$comment,
  "f=s"  => \$forward,
  "a=s"  => \$author
);

#We expect the entry accession to be passed on the command line
my $family = shift;
chomp($family);

unless ($family) {
  warn "\n***** No entry passed  *****\n\n";
}

unless ($author) {
  warn "\n***** No author passed  *****\n\n";
}

if ( $family !~ /^RF\d{5}$/ ) {
  die "Looks like $family is an identifier, rather than an accession.\n";
}

if ( $forward and $forward !~ /^RF\d{5}$/ ) {
  warn
"\n***** The entry to forward to [ $forward ] does not look like a Rfam acccession *****\n\n";
  help();
}

#Check we got a comment
unless ($comment) {
  die ( 'tried to kill a family without a comment; throwing an error' );
}

#Get the database connection.
my $rfamdb = $config->rfamlive;
print( "got a database connection\n" );

#Need to put a transaction around this block
my $guard = $rfamdb->txn_scope_guard;
print( "opened a database transaction\n" );

#Now make the dead family entry!
my $entry = $rfamdb->resultset('Family')->find( { rfam_acc => $family } );

#print Dumper $entry;

unless($entry and $entry->rfam_acc eq $family){
  die( 'failed to find this family in the database; throwing an error' );
}

#Create the dead family and then finally delete the row.
$rfamdb->resultset('DeadFamily')->createFromFamilyRow($entry, $comment, $forward, $author);
print( "created a dead family row from the family row\n" );

#We should have create the dead row if we get here, so now delete it and let the
#database cascade the delete.
$entry->delete();
print( "deleted the family\n" );

#Finish the transaction.
$guard->commit;
print( "closed the database transaction\n" );
