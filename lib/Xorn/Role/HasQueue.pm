package Xorn::Role::HasQueue;
use v5.20.0;

use Moo::Role;

use experimental qw(postderef signatures);

use Xorn::Util qw(
  cmderr
  cmdnext

  colored
);

use SelectSaver;
use Term::ReadKey ();

requires 'queue';

requires 'queue_item_noun';
requires 'maybe_describe_item';

sub add_queue_commands ($self) {
  my $noun = $self->queue_item_noun;
  my $commando = $self->commando;

  $commando->add_command('p.rev',
    help => {
      section => 'nav',
      summary => "move back to the previous $noun",
    },
    sub ($self, $cmd, $rest) {
      $self->assert_queue_not_empty;
      cmderr("You're already at the first $noun.") unless $self->queue->maybe_prev;
      cmdnext;
    },
  );

  $commando->add_command('n.ext',
    help => {
      section => 'nav',
      summary => "move on to the next $noun",
    },
    sub ($self, $cmd, $rest) {
      $self->assert_queue_not_empty;
      cmderr("You're already at the last $noun.") unless $self->queue->maybe_next;
      cmdnext;
    }
  );

  $commando->add_command('l.ist',
    help => {
      section => 'nav',
      args    => '[SUBSTR]',
      summary => "list each $noun in the queue, optionally limited by name",
    },
    sub ($self, $cmd, $rest) {
      $self->assert_queue_not_empty;
      my $item  = $self->queue->get_current;
      my $count = $self->queue->count;
      my $w     = length($count - 1);
      my $pos   = $self->queue->pos;
      my $last;

      my $needle = defined $rest ? fc $rest : undef;

      my @lines;

      for (0 .. ($count - 1)) {
        my $item_i = $self->queue->get_i($_);

        my $desc = $self->maybe_describe_item($item_i, $needle);

        next unless defined $desc;

        if (($last->{section} // '') ne ($desc->{section} // '')) {
          push @lines, $desc->{section} // '📑 Unfiled';
        }

        push @lines, sprintf "%s %s. %s",
          ($_ == $pos ? colored('marker', '*') : ' '),
          colored('ol_bul', sprintf '%*s', $w, $_ + 1),
          $desc->{brief};

        $last = $desc;
      }

      my (undef, $height) = Term::ReadKey::GetTerminalSize();

      my $select;
      if (@lines  >  $height - 3) {
        open my $less, "|-", "less", "-M";
        binmode $less, ':encoding(UTF-8)';
        $select = SelectSaver->new($less);
      }

      say for @lines;

      cmdnext;
    }
  );

  $commando->add_command('jump-n',
    match => qr{\A[0-9]+\z},
    help  => {
      section => 'nav',
      name    => '[NUMBER]',
      summary => qq{jump to a specific $noun by its list position (see "list")},
    },
    sub ($self, $cmd, $rest) {
      $self->assert_queue_not_empty;
      cmderr("You can't pass arguments while switching $noun.") if length $rest;

      if ($cmd < 1 or $cmd > $self->queue->count) {
        cmderr("Segmentation violation.  You are a bad person.");
      }

      $self->queue->pos($cmd - 1);
      cmdnext;
    }
  );

  return;
}

no Moo::Role;
1;
