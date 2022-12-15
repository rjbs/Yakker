package Yakker::App;
use v5.20.0;
use Moo::Role;

use experimental qw(postderef signatures);

requires 'name';
requires 'activity_class';

sub run ($invocant, $arg = undef) {
  my $self;

  if (ref $invocant) {
    if ($arg) {
      Carp::confess("can't pass arguments to ->run on a Yakker::App");
    }

    $self = $invocant;
  } else {
    $self = $invocant->new($arg // {});
  }

  unless ($self->activity_class('boot')) {
    die "can't run app, no boot activity defined";
  }

  require Yakker::Util;
  Yakker::Util::activityloop($self->activity('boot'));
}

sub activity ($self, $name, $arg = {}) {
  my $class = $self->activity_class($name);

  unless ($class) {
    die "unknown activity $name";
  }

  return $class->new({
    %$arg,
    app => $self,
  });
}

no Moo::Role;
1;
