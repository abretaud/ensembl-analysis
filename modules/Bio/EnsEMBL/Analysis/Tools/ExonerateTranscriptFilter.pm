# Ensembl module for Bio::EnsEMBL::Analysis::Tools::ExonerateTranscriptFilter
#
# Copyright (c) 2004 Ensembl
#

=head1 NAME

  Bio::EnsEMBL::Analysis::Tools::DefaultExonerateFilter

=head1 SYNOPSIS

  my $filter = new Bio::EnsEMBL::Analysis::Tools::ExonerateTranscriptFilter
  new->(
        -best_in_genome => 1,
        -reject_processed_pseudos => 0.01,
        -coverage => 80,
        -percent_id => 90,
       );

  my @filtered_results = @{$filter->filter_results(\@results)};

=head1 DESCRIPTION

This is the standard module used for filtering Exonerate transcripts

=cut


package Bio::EnsEMBL::Analysis::Tools::ExonerateTranscriptFilter;

use strict;
use warnings;

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Utils::Exception qw(verbose throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );


use vars qw (@ISA);

@ISA = qw(Bio::EnsEMBL::Root);



=head2 new

  Returntype: Bio::EnsEMBL::Analysis::Tools::ExonerateTranscriptFilter
  Exceptions: none
  Example   : 

=cut



sub new{
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  &verbose('WARNING');
  my ($min_score, 
      $min_coverage,
      $min_percent,
      $best_in_genome,
      $rpp) = 
        rearrange(['SCORE',
                   'COVERAGE',
                   'PERCENT_ID', 
                   'BEST_IN_GENOME',
                   'REJECT_PROCESSED_PSEUDOS',], @args); 

  ######################
  #SETTING THE DEFAULTS#
  ######################

  $self->min_score($min_score) if defined $min_score;
  $self->min_coverage($min_coverage) if defined $min_coverage;
  $self->min_percent($min_percent) if defined $min_percent;
  $self->best_in_genome($best_in_genome) if defined $best_in_genome;
  $self->reject_processed_pseudos($rpp) if defined $rpp;

  return $self;
}


#containers

=head2 container methods

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::FeatureFilter
  Arg [2]   : variable, generally int or string
  Function  : This describes the 6 container methods below
  min_score, max_pvalue, coverage, prune, hard_prune and 
  filter on coverage. The all take, store and return their give
  variable
  Returntype: int/string 
  Exceptions: none
  Example   : none

=cut


sub min_score{
  my $self = shift;
  $self->{'_min_score'} = shift if(@_);

  return exists($self->{'_min_score'}) ? $self->{'_min_score'} : undef;
}

sub min_coverage{
  my $self = shift;
  $self->{'_min_coverage'} = shift if(@_);

  return exists($self->{'_min_coverage'}) ? $self->{'_min_coverage'} : undef;
}

sub min_percent{
  my $self = shift;
  $self->{'_min_percent'} = shift if(@_);

  return exists($self->{'_min_percent'}) ? $self->{'_min_percent'} : undef;
}


sub best_in_genome{
  my $self = shift;
  $self->{'_best_in_genome'} = shift if(@_);

  return exists($self->{'_best_in_genome'}) ? $self->{'_best_in_genome'} : 0;
}

sub reject_processed_pseudos {
  my $self = shift;
  $self->{'_reject_processed_pseudos'} = shift if(@_);

  return exists($self->{'_reject_processed_pseudos'}) ? $self->{'_reject_processed_pseudos'} : 0;
}


#filter methods



=head2 filter_results

  Arg [1]   : Bio::EnsEMBL::Analysis::Tools::DefaultExonerateFilter
  Arg [2]   : arrayref of Trancripts
  Function  : filter the given Transcruipts in the tried and trusted manner
  Returntype: arrayref
  Exceptions: throws if passed nothing or not an arrayref
  Example   : 

=cut



sub filter_results{
  my ($self, $transcripts) = @_;
  
  # results are Bio::EnsEMBL::Transcripts with exons and supp_features
  
  my @good_matches;

  my %matches;

TRAN:
  foreach my $transcript (@$transcripts ){
    my $score    = $self->_coverage($transcript);
    my $perc_id  = $self->_percent_id($transcript);

    ##########################################
    # lower bound: 40% identity, 40% coverage
    # to avoid unnecessary processing
    ##########################################
    next TRAN unless ( $score >= 40 && $perc_id >= 40 );

    my $id = $self->_evidence_id($transcript);
    push ( @{$matches{$id}}, $transcript );
  }
  
  my %matches_sorted_by_coverage;
  my %selected_matches;
 
 RNA:
  foreach my $rna_id ( keys( %matches ) ){
    
    @{$matches_sorted_by_coverage{$rna_id}} = 
        sort { my $result = ( $self->_coverage($b) <=> $self->_coverage($a) );
               if ( $result){
                 return $result;
               } else{
                 my $result2 = ( scalar(@{$b->get_all_Exons}) <=> scalar(@{$a->get_all_Exons}) );
                 if ( $result2 ){
                   return $result2;
                 }
                 else{
                   return ( $self->_percent_id($b) <=> $self->_percent_id($a) );
                 }
               }
             } @{$matches{$rna_id}} ;
    
    my $count = 0;
    my $is_spliced = 0;
    my $max_score;
    my $perc_id_of_best;
    my $best_has_been_seen = 0;
    
    #print STDERR "####################\n";
    #print STDERR "Matches for $rna_id:\n";
    
  TRANSCRIPT:
    foreach my $transcript ( @{$matches_sorted_by_coverage{$rna_id}} ){
      $count++;
      unless ($max_score){
	$max_score = $self->_coverage($transcript);
      }
      unless ( $perc_id_of_best ){
	$perc_id_of_best = $self->_percent_id($transcript);
      }

      my $score   = $self->_coverage($transcript);
      my $perc_id = $self->_percent_id($transcript);
      
      my @exons  = sort { $a->start <=> $b->start } @{$transcript->get_all_Exons};
      my $start  = $exons[0]->start;
      my $end    = $exons[$#exons]->end;
      my $strand = $exons[0]->strand;
      my $seqname= $exons[0]->seqname;
      $seqname   =~ s/\.\d+-\d+$//;
      my $extent = $seqname.".".$start."-".$end;
      
      my $label;
      if ( $count == 1 ){
	$label = 'best_match';
      }
      elsif ( $count > 1 
	      && $is_spliced 
	      && ! $self->_is_spliced( $transcript )
	    ){
	$label = 'potential_processed_pseudogene';
      }
      else{
	$label = $count;
      }
      
      if ( $count == 1 && $self->_is_spliced( $transcript ) ){
	$is_spliced = 1;
      }
      
      my $accept;
      
      if ( $self->best_in_genome ){
	if ( ( $score  == $max_score && 
	       $score >= $self->min_coverage && 
	       $perc_id >= $self->min_percent
               )
	     ||
	     ( $score == $max_score &&
	       $score >= (1 + 5/100) * $self->min_coverage &&
	       $perc_id >= ( 1 - 3/100) * $self->min_percent
	     )
	   ){
	  if ( $self->reject_processed_pseudos
	       && $count > 1 
	       && $is_spliced 
	       && ! $self->_is_spliced( $transcript )
	     ){
	    $accept = 'NO';
	  }
	  else{
	    $accept = 'YES';
	    push( @good_matches, $transcript);
	  }
	}
	else{
	  $accept = 'NO';
	}
	#print STDERR "match:$rna_id coverage:$score perc_id:$perc_id extent:$extent strand:$strand comment:$label accept:$accept\n";
	
	#print STDERR "--------------------\n";
	
      }
      else{
	############################################################
	# we keep anything which is 
	# within the 2% of the best score
	# with score >= $EST_MIN_COVERAGE and percent_id >= $EST_MIN_PERCENT_ID
	if ( ( $score >= (0.98 * $max_score) && 
	       $score >= $self->min_coverage && 
	       $perc_id >= $self->min_percent )
	     ||
	     ( $score >= (0.98 * $max_score) &&
	       $score >= (1 + 5/100) * $self->min_coverage &&
	       $perc_id >= (1 - 3/100) * $self->min_percent
	     )
	   ){
	  
	  ############################################################
	  # non-best matches are kept only if they are not unspliced with the
	  # best match being spliced - otherwise they could be processed pseudogenes
	  if ( $self->reject_processed_pseudos
	       && $count > 1 
	       && $is_spliced 
	       && ! $self->_is_spliced( $transcript )
	     ){
	    $accept = 'NO';
	  }
	  else{
	    $accept = 'YES';
	    push( @good_matches, $transcript);
	  }
	}
	else{
	  $accept = 'NO';
	}
	#print STDERR "match:$rna_id coverage:$score perc_id:$perc_id extent:$extent strand:$strand comment:$label accept:$accept\n";
	
	#print STDERR "--------------------\n";
      }
    }
  }
  
  return \@good_matches;

}

############################################################

sub _coverage{
  my ($self,$tran) = @_;
  my @exons = @{$tran->get_all_Exons};
  my @evi = @{$exons[0]->get_all_supporting_features};
  return $evi[0]->score;
}

############################################################

sub _percent_id{
  my ($self,$tran) = @_;
  my @exons = @{$tran->get_all_Exons};
  my @evi = @{$exons[0]->get_all_supporting_features};
  return $evi[0]->percent_id;
}

############################################################

sub _evidence_id{
  my ($self,$tran) = @_;
  my @exons = @{$tran->get_all_Exons};
  my @evi = @{$exons[0]->get_all_supporting_features};
  return $evi[0]->hseqname;
}

############################################################

sub _is_spliced {
  my ($self, $tran) = @_;

  my @exons = sort { $a->start <=> $b->start } @{$tran->get_all_Exons};

  if ( scalar (@exons) > 1 ){    
    # check that there are non "frameshift" introns
    for(my $i=0; $i < @exons - 1; $i++){
      my $intron_len = $exons[$i+1]->start - $exons[$i]->end - 1;
      if ( $intron_len > 9 ){
        return 1;
      }
    }
  }

  return 0;
}



1;
