#!/usr/bin/perl

use strict;

use algo::H5N1;

use config::Config_Reader;

use db::DB_Handler;

use util::Utils;
###
### configuration file
###
my $configFile = $ARGV[0];
unless ( defined($configFile) && -e $configFile ) {
  warn "Usage: perl classifier [configuration file]\n";
  exit(1);
}
my $config = config::Config_Reader->new( fileName => $configFile );
my $OUT    = $config->getValue("output");
my $IN     = $config->getValue("input");
###
### classifier directory
###
my $date = $ARGV[1];
print "date = $date\n";
unless ( defined($date) && $date =~ /^\d\d\d\d\d\d\d\d$/ ) {
  warn "Usage: perl classifier [configuration file] [date] $date\n";
  exit(1);
}
my $ClassifierDir     = $config->getValue("ClassifierDir");
my $ClassifierPattern = $config->getValue("ClassifierPattern");
$ClassifierDir =~ s/$ClassifierPattern/$date/;
$config->setValue( "ClassifierDir", $ClassifierDir );
my $classifierDir = $config->getValue("TempDir") . "/" . $ClassifierDir;
chdir($classifierDir);
###
### input file for text mode
###
if ( $IN eq "text" ) {

  unless ( defined( $ARGV[2] ) && -f $ARGV[2] ) {
    warn
"Usage: perl classifier [configuration file] [date] [input sequence file fasta]\n";
    exit(1);
  }
}
my $inputFile = $ARGV[2] if ( defined( $ARGV[2] ) );
###
### output file for text mode
###
my $outputfile = undef;
if ( $OUT eq "text" && defined( $ARGV[3] ) ) {
  $outputfile = $ARGV[3];
}
###
###  database connection
###
my $dbConn =
  ( $IN eq "DB" || $OUT eq "DB" )
  ? db::DB_Handler->new(
  "db_name"     => $config->getValue( uc("db_name") ),
  "db_host"     => $config->getValue( uc("db_host") ),
  "db_user"     => $config->getValue( uc("db_user") ),
  "db_platform" => $config->getValue( uc("db_platform") ),
  "db_pass"     => $config->getValue( uc("db_password") ),
  "db_debug"    => "0"
  )
  : undef;
###
### classifier
###
my $blastout   = 0;
my $type       = $config->getValue("Type");
my $class      = "algo::$type";
my $classifier = $class->new(
  config   => $config,
  db_conn  => $dbConn,
  blastout => $blastout,
  count    => 3
);
###
### open output_file and logging
###
my $OUTFILE;
my $logFile = "$classifierDir/classification.$type.log";

if ( defined($outputfile) ) {
  $logFile = "$outputfile.$type.log";
  open( $OUTFILE, ">$outputfile" )
    or warn "Cannot open outputfile: $outputfile\n";
}
open( LOG, ">>$logFile" ) or die "Cannot open log file.\t$logFile\n";
print LOG "Classifier - $type " . localtime() . "\n";
###
### get input data
###
my $sequenceSql =
"select isdid, sequence from sequence where isdid in (select isdid from temp_sequence where c_type='"
  . lc($type) . "')";
my @resultRow;
eval {
  @resultRow =
    $IN eq "DB"
    ? @{ $dbConn->getResult($sequenceSql) }
    : @{ util::Utils::getSequenceFromFasta($inputFile) };
};

if ($@) {
  warn "Error in collection of result. $@\n";
  exit(1);
}
my $size = scalar(@resultRow);
print LOG "Total number of sequences: $size \n";
###
### setup for reference package using taxit
###
my $taxit = undef;
$taxit =
    $config->getValue("taxit")
  . " create -l $type -P <REFPKG>"
  . " --aln-fasta <ALIGN> "
  . " --tree-stats <STAT>"
  . " --tree-file <TREE>";

my $align  = $config->getValue("H5Align");
my $refpkg = $config->getValue("H5Refpkg");
my $stat   = $classifierDir . "/" . $config->getValue("H5Stat");
my $tree   = $classifierDir . "/" . $config->getValue("H5Tree");

$taxit =~ s/<ALIGN>/$align/;
$taxit =~ s/<REFPKG>/$refpkg/;
$taxit =~ s/<STAT>/$stat/;
$taxit =~ s/<TREE>/$tree/;
###
### classify the sequences
###
foreach my $row (@resultRow) {
  my $accession = $row->[0];
  my $seq       = util::Utils::trim( $row->[1] );
  my $accDir    = $classifierDir . "/" . $accession;

  chdir($accDir);
  ###
  ### generate reference package for accession
  ###
  my $refpkg = $config->getValue("H5Refpkg");
  if ( -e $refpkg ) {
    system("/bin/rm -fr $refpkg");
    my $status = $?;
    die "Could not remove reference package for $accession ($status)\n"
      if ($status);
  }
  print "$accession = $taxit\n";
  system("$taxit > $accession.taxit.std 2> $accession.taxit.err");
  my $status = $?;
  die "Failed to run taxit for $accession ($status)\n" if ($status);
  ###
  ### sequence input
  ###
  my $tempFile = "$accDir/$accession.fasta";
  open( SEQ, ">$tempFile" ) or die "Unable to open $tempFile:  $@\n";
  print SEQ ">$accession\n";
  print SEQ "$seq";
  close SEQ;
  ###
  ### classify sequence
  ###
  my $class = $classifier->getClassification( $tempFile, $accession );
  print LOG "$accession\t$class\n";
  print $OUTFILE "$accession\t$class\n" if ( defined($OUTFILE) );
  chdir($classifierDir);
}
###
### close files
###
close($OUTFILE) if ( defined($OUTFILE) );
print LOG "Classifier - $type " . localtime() . "\n";

$dbConn->setResult(
  "delete from temp_sequence where c_type='" . lc($type) . "'" )
  if ( $OUT eq "DB" );
$dbConn->close() if ( defined $dbConn );
close LOG;

