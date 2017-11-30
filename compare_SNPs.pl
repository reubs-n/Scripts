#!/usr/bin/env perl

## author: reubwn Nov 2017

use strict;
use warnings;

use Getopt::Long;
use Sort::Naturally;

my $usage = "
OPTIONS:
  -1|--file1 [FILE]
  -2|--file2 [FILE]
  -h|--help
\n";

my ($file1,$file2,$help);
my $outfile = "intersect";
my $processed = 0;

GetOptions (
  '1|file1=s' => \$file1,
  '2|file2=s' => \$file2,
  'o|out:s'   => \$outfile,
  'h|help'    => \$help,
);

die $usage if $help;
die $usage unless ($file1 && $file2);

my (%h1,%h2,%intersect,%uniq1,%uniq2);
my ($intersect,$uniq1,$uniq2) = (0,0,0);

## parse SNPs in file1/2:
open (my $FILE1, $file1) or die $!;
while (<$FILE1>) {
  chomp;
  my @F = split /\s+/;
  $h1{"$F[0].$F[1]"} = { 'chrom' => $F[0], 'pos' => $F[1], 'ref' => $F[2], 'alt' => $F[3], 'cov' => $F[4] }; ##key= pos; val= %{chrom...}
}
close $FILE1;
open (my $FILE2, $file2) or die $!;
while (<$FILE2>) {
  chomp;
  my @F = split /\s+/;
  $h2{"$F[0].$F[1]"} = { 'chrom' => $F[0], 'pos' => $F[1], 'ref' => $F[2], 'alt' => $F[3], 'cov' => $F[4] }; ##key= pos; val= %{chrom...}
}
close $FILE2;

open (my $INTERSECT, ">$outfile.intersect") or die $!;
foreach my $k1 (nsort keys %h1) {
  if ( (exists($h2{$k1})) and ($h1{$k1}{chrom} eq $h2{$k1}{chrom}) ) { ##SNP exists in same position on same CHROM
    print $INTERSECT join (
      "\t",
      $h1{$k1}{chrom},
      $h1{$k1}{pos},
      $h1{$k1}{ref},
      $h1{$k1}{alt},
      $h1{$k1}{cov},
      $h2{$k1}{chrom},
      $h2{$k1}{pos},
      $h2{$k1}{ref},
      $h2{$k1}{alt},
      $h2{$k1}{cov},
      "\n"
    );
    $intersect++;
  }
}
close $INTERSECT;

print STDERR "[INFO] # SNPs in $file1: ".(keys %h1)."\n";
print STDERR "[INFO] # SNPs in $file2: ".(keys %h2)."\n";
print STDERR "[INFO] # SNPs common to both files: $intersect\n";
print STDERR "[INFO]   % SNPs $file1: ".percentage($intersect,scalar(keys %h1))."\n";
print STDERR "[INFO]   % SNPs $file2: ".percentage($intersect,scalar(keys %h2))."\n";

################### SUBS

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub percentage {
    my $numerator = $_[0];
    my $denominator = $_[1];
    my $places = "\%.2f"; ## default is two decimal places
    if (exists $_[2]){$places = "\%.".$_[2]."f";};
    my $float = (($numerator / $denominator)*100);
    my $rounded = sprintf("$places",$float);
    return "$rounded\%";
}
