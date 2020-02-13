#!/usr/bin/env perl

## author: reubwn Feb 2020

use strict;
use warnings;

use Bio::SeqIO;
use Data::Dumper;
use Getopt::Long;
use File::Basename;
use Sort::Naturally;

my $usage = "
SYNOPSIS:
  Collapse multiple BUSCO copies to single copy by random selection

OPTIONS:
  -b|--busco [PATH] : path to BUSCO results directory [required]
  -h|--help         : prints this help message
\n";

my ($busco_path, $help, $debug);

GetOptions (
  'b|busco=s' => \$busco_path,
  'h|help'    => \$help,
  'debug'     => \$debug
);

die $usage if $help;
die $usage unless ($busco_path);

############
## get prots
############

my %extracted_proteins_hash;
my @faa_files = glob ("$busco_path/augustus_output/extracted_proteins/*faa*");
foreach my $faa_file (@faa_files) {
  print STDERR "\r[INFO] Extracting proteins from $faa_file"; $|=1;
  ## BUSCO ID from filename
  my $busco_id = fileparse($faa_file, qr/\.faa\.\d+$/);
  my $in = Bio::SeqIO -> new ( -file => $faa_file, -format => "fasta");
  while ( my $seq_obj = $in -> next_seq() ) {
    my $header = $seq_obj->display_id(); ## eg. g1[ARIC00057:299830-304439]
    if ($header =~ m/g\d+\[(\w+)\:(\d+)\-(\d+)\]/) {
      my $contig = $1;
      my $start = $2;
      my $end = $3;
      my $construct = "$contig:$start-$end"; ## eg. ARIC00057:299830-304439; these will be unique to each extracted protein
      $extracted_proteins_hash{$busco_id}{$construct}{Seq} = $seq_obj->seq();;
      $extracted_proteins_hash{$busco_id}{$construct}{Length} = $seq_obj->length();
      # push ( @{$extracted_proteins_hash{$busco_id}{Header}}, $seq_obj->display_id() );
      # push ( @{$extracted_proteins_hash{$busco_id}{Seq}}, $seq_obj->seq() );
      # push ( @{$extracted_proteins_hash{$busco_id}{Length}}, length($seq_obj->seq()) );
      # push ( @{$extracted_proteins_hash{$busco_id}{Contig}}, $contig );
      # push ( @{$extracted_proteins_hash{$busco_id}{Start}}, $start );
      # push ( @{$extracted_proteins_hash{$busco_id}{End}}, $end );
      # push ( @{$extracted_proteins_hash{$busco_id}{Construct}}, $construct );
      #### HERE: i think just restructure this to be key=Construct; val=Seq, which can then be directly accessed from the code below?

    }
  }
}
print STDERR "\n[INFO] Extracted ".scalar(keys %extracted_proteins_hash)." proteins from $busco_path/augustus_output/extracted_proteins/\n";

## Dumper
print nsort Dumper(\%extracted_proteins_hash) if $debug;

####################
## parse BUSCO table
####################

my @full_table_file = glob ("$busco_path/full_table*tsv");
die "[ERROR] There are either zero or multiple full_table files!\n" if (@full_table_file != 1);

my $input_filename;
my %full_table_hash;
open (my $TAB, $full_table_file[0]) or die $!;
while (<$TAB>) {
  if (m/^\#/) {
    if (m/\-i\s(\S+)\s//) {
      $input_filename = $1;
      print STDERR "[INFO] Input file for BUSCO run was: $input_filename\n";
    } else { next; }
  } else {
    chomp;
    my @F = split (m/\s+/, $_);
    push ( @{ $full_table_hash{$F[0]}{Status} }, $F[1] );
    push ( @{ $full_table_hash{$F[0]}{Contigs} }, $F[2] );
    push ( @{ $full_table_hash{$F[0]}{Starts} }, $F[3] );
    push ( @{ $full_table_hash{$F[0]}{Ends} }, $F[4] );
    push ( @{ $full_table_hash{$F[0]}{Scores} }, $F[5] );
    push ( @{ $full_table_hash{$F[0]}{Lengths} }, $F[6] );

  }
}
close $TAB;

## Dumper
print nsort Dumper(\%full_table_hash) if $debug;

foreach my $busco_id (nsort keys %full_table_hash) {
  if ( scalar(@{$full_table_hash{$busco_id}{Status}}) > 1 ) { ## BUSCO is duplicated
    ## select the BUSCO copy with the highest Score
    my @scores = @{$full_table_hash{$busco_id}{Scores}};
    my $index = findMaxValueIndex(\@scores);
    ## fetch the winning Contig, Start and End
    my $contig = ${$full_table_hash{$busco_id}{Contigs}}[$index];
    my $start = ${$full_table_hash{$busco_id}{Starts}}[$index];
    my $end = ${$full_table_hash{$busco_id}{Ends}}[$index];
    my $construct = "$contig:$start-$end"; ## format to be equivalent to eg. ARIC00057:299830-304439

    print STDERR "[DEBUG] [$busco_id] Index $index wins with score $scores[$index]\n" if $debug;
    print STDERR "[DEBUG] [$busco_id] Winning construct is $construct\n" if $debug;

    ## pull the highest-scoring seq out of %extracted_proteins_hash
    print ">$busco_id:duplicated:$input_filename:$construct\n";
    print $extracted_proteins_hash{$busco_id}{$construct}{Seq} . "\n"
  }
}


############ SUBS

sub findMaxValueIndex {
  my @array = @{$_[0]};
  my ($index,$max) = (0,0);
  for (my $i=0; $i<scalar(@array); $i++) {
    if ($array[$i] > $max) {
      $max = $array[$i];
      $index = $i;
    }
  }
  return $index;
}
