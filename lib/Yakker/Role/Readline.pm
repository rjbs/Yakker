package Yakker::Role::Readline;
use v5.20.0;

use Moo::Role;

with 'Yakker::Activity';

use experimental qw(postderef signatures);
use utf8;

use Encode qw(decode);
use Term::ReadLine;

sub readline ($self) {
  state $initialized_app = $self->app->name;

  if ($self->app->name ne $initialized_app) {
    warn "Woah!  You have two Yakker apps using ReadLine at once.  This may get weird.\n";
  }

  state $term;

  return $term if $term;

  $term = Term::ReadLine->new($self->app->name);

  $term->Attribs->ornaments(0);

  $term->add_defun(
    'issue-marker',
    sub {
      return unless Yakker->debugging_is_enabled;
      warn "marker line requested\n";
    },
    ord "\cF",
  );

  $term->add_defun(
    'toggle-clim8-debugging',
    sub {
      if (Yakker->debugging_is_enabled) {
        Yakker->disable_debugging;
      } else {
        return if Yakker->enable_debugging;
        warn "Couldn't start debugging.  (You have to run under tmux.)\n";
      }
    },
    ord "\cO",
  );

  return $term;
}

sub get_input ($self, $prompt) {
  my $input = $self->readline->readline($prompt);

  return undef unless defined $input;

  $input = decode('utf-8', $input, Encode::FB_CROAK);

  $input =~ s/\A\s+//g;
  $input =~ s/\s+\z//g;

  return $input;
}

sub _complete_from_array ($self, $array_ref) {
  my @array = @$array_ref;
  $self->readline->Attribs->{completion_entry_function} = sub { shift @array; };

  return undef;
}

no Moo::Role;
1;
