#!/usr/bin/env perl

## author: reubwn April 2021

use strict;
use warnings;

use Getopt::Long;

my $usage = "
SYNOPSIS:
  Annotates a treefile containing UniRef sequence IDs with taxonomy information.

OPTIONS:
  -i|--infile     [FILE]   :
  -o|--outfile    [FILE]   :
  -s|--speclist   [FILE]   :
  -p|--path       [STRING] :
  -d|--depth      [INT]    : how deep to print taxonomy string (default: full string)
  -h|--help                : prints this help message
\n";

my ($infile,$speclist,$path_to_nodes,$help);
my $outfile = "$infile.tax.treefile";
my $depth_taxon = 0;

GetOptions (
  'i|infile=s'   => \$infile,
  'o|outfile:s'  => \$outfile,
  's|speclist=s' => \$speclist,
  'p|path=s'     => \$path_to_nodes,
  'd|depth:i'    => \$depth_taxon,
  'h|help'       => \$help,
);

die $usage if $help;
die $usage unless ($infile && $speclist && $path_to_nodes);

## parse treefile:
open (my $TREEFILE, $infile) or die $!;
while (<$TREEFILE>) {
  my @uniprot_ids ($_ =~ m/(\w+):/g);
  print STDERR join ("\n", @uniprot_ids);
}

## parse nodes and names:
my (%nodes_hash, %names_hash, %rank_hash);

print STDERR "[INFO] Building taxonomy databases from tax files in '$path'...\n";
open (my $NODES, "$path/nodes.dmp") or die $!;
while (<$NODES>) {
  chomp;
  next if /\#/;
  my @F = map { s/^\s+|\s+$//gr } split (m/\|/, $_); ## split nodes.dmp file on \s+|\s+ regex
  $nodes_hash{$F[0]} = $F[1]; ## key= child taxid; value= parent taxid
  $rank_hash{$F[0]} = $F[2]; ## key= taxid; value= rank
}
close $NODES;
open (my $NAMES, "$path/names.dmp") or die $!;
while (<$NAMES>) {
  chomp;
  next if /\#/;
  my @F = map { s/^\s+|\s+$//gr } split (m/\|/, $_);
  $names_hash{$F[0]} = $F[1] if ($F[3] eq "scientific name"); ## key= taxid; value= species name
}
close $NAMES;
if (-e "$path/merged.dmp") {
  open (my $MERGED, "$path/merged.dmp") or die $!;
  while (<$MERGED>) {
    chomp;
    next if /\#/;
    my @F = map { s/^\s+|\s+$//gr } split (m/\|/, $_);
    $nodes_hash{$F[0]} = $F[1]; ## key= old taxid; value= new taxid
    ## this will behave as if old taxid is a child of the new one, which is OK I guess
  }
}
print STDERR "[INFO] Nodes parsed: ".commify(scalar(keys %nodes_hash))."\n";

## parse speclist.txt (from uniprot.org):
my %uniprot_hash;

print STDERR "[INFO] Parsing UniProt taxonomy IDs from '$speclist'...\n";
open (my $SPECLIST, $speclist) or die $!;
while (<$SPECLIST>) {
  chomp;
  my @F = split (m/\s+/, $_);
  next if scalar(@F) < 3;
  next if $F[2] !~ m/\d+\:$/;
  $F[2] =~ s/://; ## remove trailing colon
  $uniprot_hash{$F[0]} = $F[2];
}
print STDERR "[INFO] IDs parsed: ".commify(scalar(keys %uniprot_hash))."\n";

###### SUBS

sub tax_walk_to_get_rank_to_species {
  my $taxid = $_[0];
  my $parent = $nodes_hash{$taxid};
  my $parent_rank = $rank_hash{$parent};
  my ($species,$genus,$family,$order,$class,$phylum,$kingdom,$superkingdom) = ("undef","undef","undef","undef","undef","undef","undef","undef");

  while (1) {
    if ($parent_rank eq "species") {
      $species = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "genus") {
      $genus = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "family") {
      $family = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "order") {
      $order = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "class") {
      $class = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "phylum") {
      $phylum = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "kingdom") {
      $kingdom = $names_hash{$parent};
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
      next;
    } elsif ($parent_rank eq "superkingdom") {
      $superkingdom = $names_hash{$parent};
      last;
    } elsif ($parent == 1) {
      last;
    } else {
      $parent = $nodes_hash{$parent};
      $parent_rank = $rank_hash{$parent};
    }
  }
  my $result = join (";",$superkingdom,$kingdom,$phylum,$class,$order,$family,$genus,$species);
  $result =~ s/\s+/\_/g; ## replace spaces with underscores
  return $result;
}

sub percentage {
    my $numerator = $_[0];
    my $denominator = $_[1];
    my $places = "\%.2f"; ## default is two decimal places
    if (exists $_[2]){$places = "\%.".$_[2]."f";};
    my $float = (($numerator / $denominator)*100);
    my $rounded = sprintf("$places",$float);
    return $rounded;
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
