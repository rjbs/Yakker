package Xorn::Role::Readline;
use v5.20.0;

use Moo::Role;

with 'Xorn::Activity';

use experimental qw(postderef signatures);
use utf8;

use Encode qw(decode);
use Term::ReadLine;

has readline => (
  is    => 'ro',
  lazy  => 1,
  init_arg  => undef,
  builder   => 'build_readline',
);

sub build_readline ($self) {
  my $term = Term::ReadLine->new($self->app->name);

  $term->Attribs->ornaments(0);

  $term->add_defun(
    'issue-marker',
    sub {
      return unless Xorn->debugging_is_enabled;
      warn "marker line requested\n";
    },
    ord "\cF",
  );

  $term->add_defun(
    'toggle-clim8-debugging',
    sub {
      if (Xorn->debugging_is_enabled) {
        Xorn->disable_debugging;
      } else {
        return if Xorn->enable_debugging;
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

no Moo::Role;
1;
