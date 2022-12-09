package Yakker::Role::Queue;
use v5.20.0;

use Moo::Role;

use experimental qw(postderef signatures);

requires 'inflate';

has items => (is => 'ro', required => 1);
has pos   => (is => 'rw', default  => 0);
has query => (is => 'ro', required => 1);

sub at_first  { $_[0]->pos == 0 }
sub at_last   { $_[0]->pos == $_[0]->items->$#* }
sub count     { 0 + $_[0]->items->@* }

sub maybe_next {
  return if $_[0]->at_last;
  $_[0]->pos( $_[0]->pos + 1 );
  return 1;
}

sub maybe_prev {
  return if $_[0]->at_first;
  $_[0]->pos( $_[0]->pos - 1 );
  return 1;
}

sub get_i ($self, $i) {
  return unless $self->count > 0;
  return unless $i >= 0;
  return unless $i < $self->count;
  return $self->_get_i($i);
}

sub get_current {
  return $_[0]->get_i($_[0]->pos);
}

sub invalidate_current ($self) {
  my $i = $self->pos;
  return unless my $t = $self->items->[$i];
  return unless ref $t;
  $self->items->[$i] = $t->{id};
  return;
}

sub _get_i ($self, $i) {
  my $item = $self->items->[$i];

  if (defined $item and not ref $item) {
    $item = $self->inflate($item);

    die "Something went wrong fetching the task!\n" unless $item;
    $self->items->[$i] = $item;
  }

  return $item;
}

no Moo::Role;
1;
