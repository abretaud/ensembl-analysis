# Bio::EnsEMBL::Analysis::Config::GeneBuild::Bam2Genes;
# 
# Cared for by EnsEMBL (dev@ensembl.org)
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code


package Bio::EnsEMBL::Analysis::Config::GeneBuild::Bam2Genes;

use strict;
use vars qw( %Config );

# Hash containing config info
%Config = (

BAM2GENES_CONFIG_BY_LOGIC => 
     {
      DEFAULT => {
                  # databases are defined as hash keys from Bio::EnsEMBL::Analysis::Config::Databases
                  OUTPUT_DB    => '',
		  
		  # location of sorted and indexed bam file containing genomic alignments 
	          ALIGNMENT_BAM_FILE => '/lustre/scratch101/ensembl/rn6/platyfishI/xipmac.rnaseq.good_tissues.bam',
		  
		  # logic_name for repeats will be used to merge exons separated by repeats 
		  # leave blank if you don't want to fill in the gaps ( shouldn't be needed with BWA anyway )
                  REPEAT_LN  => '',	

                  # options for filtering out small gene models
                  MIN_LENGTH => 300,
                  MIN_EXONS  =>   1,
		  
		  # are you using paired reads?
		  PAIRED => 0,
		  # If using paired reads we need to remove the 1 or 2 tag from the end of the paired read names so 
		  # we can pair them by name, this regex will usually work but if you have
		  # reads with differently structured headers you may need to tweak it
		  PAIRING_REGEX => '_\d',
		  
		  # if we are using unpaired reads we use the max intron length to 
		  # join clusters of reads into transcripts
		  MAX_INTRON_LENGTH => 100000,
		  
		  # genes with a span < MIN_SPAN will also be considered single exon
		  MIN_SINGLE_EXON_LENGTH => 1000,
		  
                  # 'span' = genomic extent / cdna length
                  MIN_SPAN   =>   1.5,
                  },
      bam2genes => {
                     OUTPUT_DB    => 'RNASEQ_ROUGH_DB',
                     ALIGNMENT_BAM_FILE => '/lustre/scratch101/ensembl/rn6/platyfishI/xipmac.rnaseq.good_tissues.bam',
                     },
     }
);

sub import {
  my ($callpack) = caller(0); # Name of the calling package
  my $pack = shift; # Need to move package off @_

  # Get list of variables supplied, or else everything
  my @vars = @_ ? @_ : keys( %Config );
  return unless @vars;
  
  # Predeclare global variables in calling package
  eval "package $callpack; use vars qw("
    . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if ( defined $Config{$_} ) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Config{ $_ };
	} else {
	    die "Error: Config: $_ not known\n";
	}
    }
}

1;
