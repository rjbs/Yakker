package Xorn::Util;
use v5.20.0;
use warnings;

use experimental 'signatures';
use utf8;

use Path::Tiny ();
use Safe::Isa;
use Term::ANSIColor ();
use Try::Tiny;

use Sub::Exporter -setup => [ qw(
  activityloop

  cmderr
  cmdmissing
  cmdnext
  cmdlast

  matesay
  errsay
  okaysay

  colored
  colored_prompt
  edit_in_editor
  prefixes
  prefix_re
  tfu
) ];

sub matesay {
  say join q{ }, "🤖", colored('ping', $_[0]);
}

sub okaysay {
  say colored('okay', $_[0]);
}

sub errsay {
  say colored('error', $_[0]);
}

sub colored ($style, $text) {
  my $codes = ref $style ? $style : $Xorn::STYLE{$style};

  my $color = Term::ANSIColor::color(@$codes);

  my $reset = Term::ANSIColor::color('reset')
            . Term::ANSIColor::color(@{ $Xorn::STYLE{default} });

  return "$color$text$reset";
}

# Gnu's readline is known to have issues with colored prompts. This
# works around them per
# https://wiki.hackzine.org/development/misc/readline-color-prompt.html
# by putting RL_PROMPT_START_IGNORE and RL_PROMPT_END_IGNORE around
# the color escapes
sub colored_prompt {
  my ($style, $text) = @_;

  my $codes = ref $style ? $style : $Xorn::STYLE{$style};

  my $color = Term::ANSIColor::color(@$codes);

  my $reset = Term::ANSIColor::color('reset')
            . Term::ANSIColor::color(@{ $Xorn::STYLE{default} });

  return "\001$color\002$text\001$reset\002";
}

sub edit_in_editor {
  my ($str) = @_;
  $str //= q{};

  my $editor = $ENV{VISUAL} // $ENV{EDITOR};
  unless ($editor) {
    no warnings 'exiting';
    cmderr("You haven't set \$VISUAL or \$EDITOR.")
  }

  my $tmp = Path::Tiny->tempfile;
  $tmp->spew_utf8($str);

  system($editor, $tmp);

  if ($?) {
    no warnings 'exiting';
    cmderr("Something went wrong with your editor, I think.");
  }

  return $tmp->slurp_utf8;
}

sub tfu {
  my ($value, $true, $false, $undef) = @_;
  return $undef if ! defined $value;
  return $value ? $true : $false;
}

sub prefixes {
  my ($str, $delim) = @_;
  $delim //= '.';
  my @bits = split /\Q$delim/, $str;

  return map {; join q{}, @bits[ 0 .. $_ ] } (0 .. $#bits);
}

sub prefix_re {
  # e.st.imate -> qr{\A e ( st (imate)? )? \z}nx
  my ($str, $delim) = @_;
  $delim //= '.';
  my ($head, @rest) = split /\Q$delim/, $str;

  my $re = join q{},
    $head,
    (map {; "(?:\Q$_\E" } @rest),
    (')?') x @rest;

  return qr{\A$re\z};
}

# There's an activity stack.  We run through whatever is on top of it.
# Normally it will just loop over and over.  The current activity, though, can
# do any of these things:
#
# * declare it's done and should be popped off the stack
# * initiate a subactivity by pushing it onto the stack
# * replace itself by popping and pushing at the same time

sub activityloop (@stack) {
  INTERACTION: while (@stack) {
    try {
      $stack[-1]->interact;
    } catch {
      my $error = $_;

      my $jump = $error->$_isa('Xorn::LoopControl::Continue');
      @stack = () if $error->$_isa('Xorn::LoopControl::Empty');
      pop @stack if $error->$_isa('Xorn::LoopControl::Pop');
      push @stack, $error->activity if $error->$_isa('Xorn::LoopControl::Push');

      if ($jump) {
        no warnings 'exiting';
        next INTERACTION;
      }

      die $error;
    }
  }
}

sub cmdnext {
  Xorn::LoopControl::Continue->new->throw;
}

sub cmdlast {
  Xorn::LoopControl::Pop->new->throw;
}

sub cmderr {
  errsay($_[0]);
  cmdnext;
}

sub cmdmissing {
  say colored($Xorn::STYLE{missing}, $_[0]);
  cmdnext;
}

package Xorn::LoopControl::Continue {
  use Moo;
  sub throw { die $_[0]; }
  no Moo;
}

package Xorn::LoopControl::Pop {
  use Moo;
  extends 'Xorn::LoopControl::Continue';
  no Moo;
}

package Xorn::LoopControl::Push {
  use Moo;
  extends 'Xorn::LoopControl::Continue';
  has activity => (is => 'ro', required => 1);
  no Moo;
}

package Xorn::LoopControl::Swap {
  use Moo;
  # Note that Moo has a bug in how ->new works, so the order of the extends()
  # here is significant.  Really these should be roles, probably, but that was
  # a slight increase in complexity *except for this bug* so here we are!
  # -- rjbs, 2020-03-07
  extends 'Xorn::LoopControl::Push', 'Xorn::LoopControl::Pop';
  no Moo;
}

package Xorn::LoopControl::Empty {
  use Moo;
  extends 'Xorn::LoopControl::Continue';
  no Moo;
}

1;
