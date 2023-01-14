package Yakker;
# ABSTRACT: a framework for linewise terminal apps

use v5.20.0;
use warnings;
use experimental qw(postderef signatures);
use utf8;

sub _terminfo {
  require Term::Terminfo;
  state $ti = Term::Terminfo->new;
  return $ti;
}

my $DEBUGGING = 0;
sub enable_debugging {
  require Yakker::Debug;
  return if $DEBUGGING;
  my $ok = Yakker::Debug->enable_debugging;
  $DEBUGGING = $ok;
  return $ok;
}

sub disable_debugging {
  return unless $DEBUGGING;
  Yakker::Debug->disable_debugging;
  $DEBUGGING = 0;
}

sub debugging_is_enabled {
  return $DEBUGGING;
}

sub loop {
  require IO::Async::Loop;
  state $LOOP = IO::Async::Loop->new;
  return $LOOP;
}

our %INT_HANDLER;
$SIG{INT} = sub {
  eval { $_->() } for values %INT_HANDLER;
  exit 1;
};

sub register_sigint_handler ($class, $name, $code) {
  $INT_HANDLER{ $name } = $code;
}

sub deregister_sigint_handler ($class, $name) {
  delete $INT_HANDLER{ $name };
}

my %THEME_TEMPLATE = (
    default => undef,
    bold    => undef,
    header  => undef,
    ping    => undef,
    help1   => undef,
    help2   => undef,
    bumper  => undef,
    marker  => undef,
    ol_bul  => undef,

    dim     => undef,
    callout => undef,
    error   => undef,
    okay    => undef,
    missing => undef,
);

my %THEME = (
  dark => {
    default => [ 'bright_white' ],
    bold    => [ 'bold', 'bright_white' ],
    header  => [ 'bold', 'bright_white' ],
    ping    => [ 'bright_cyan' ],
    prompt  => [ 'cyan' ],
    help1   => [ 'ansi226' ],
    help2   => [ 'ansi172' ],
    bumper  => [ 'blue' ],
    marker  => [ 'bright_yellow' ],
    ol_bul  => [ 'bright_cyan' ],

    dim     => [ 'bright_black' ],
    callout => [ 'bright_green' ],
    error   => [ 'bright_red' ],
    okay    => [ 'bright_green' ],
    missing => [ 'bright_magenta' ],
  },
  light => {
    default => [ 'black' ],
    bold    => [ 'blue' ],
    header  => [ 'blue' ],
    ping    => [ 'cyan' ],
    prompt  => [ 'cyan' ],
    help1   => [ 'bright_red' ],
    help2   => [ 'red' ],
    bumper  => [ 'blue' ],
    marker  => [ 'yellow' ],
    ol_bul  => [ 'cyan' ],

    dim     => [ 'bright_black' ],
    callout => [ 'bright_green' ],
    error   => [ 'bright_red' ],
    okay    => [ 'bright_green' ],
    missing => [ 'magenta' ],
  },
  truedark => {
    default => [ 'ansi8' ], # ansi237
    bold    => [ 'bold', 'ansi8' ],
    header  => [ 'bold', 'ansi8' ],
    ping    => [ 'ansi243' ],
    prompt  => [ 'bold', 'ansi243' ],
    help1   => [ 'ansi247' ],
    help2   => [ 'ansi240' ],
    bumper  => [ 'ansi238' ],
    marker  => [ 'ansi247' ],
    ol_bul  => [ 'ansi239' ],

    dim     => [ 'ansi235' ],
    callout => [ 'ansi252' ],
    error   => [ 'ansi52' ],
    okay    => [ 'ansi28' ],
    missing => [ 'ansi241' ],
  },
  vantablack => {
    default => [ 'black' ], # ansi237
    bold    => [ 'black' ],
    header  => [ 'black' ],
    ping    => [ 'black' ],
    prompt  => [ 'black' ],
    help1   => [ 'black' ],
    help2   => [ 'black' ],
    bumper  => [ 'black' ],
    marker  => [ 'black' ],
    ol_bul  => [ 'black' ],

    dim     => [ 'black' ],
    callout => [ 'black' ],
    error   => [ 'black' ],
    okay    => [ 'black' ],
    missing => [ 'black' ],
  },
  ponies   => {
    default => [ 'ansi141' ],
    bold    => [ 'ansi219' ],
    header  => [ 'ansi219' ],
    ping    => [ 'ansi219' ],
    prompt  => [ 'bold', 'ansi219' ],
    help1   => [ 'ansi207' ],
    help2   => [ 'ansi171' ],
    bumper  => [ 'ansi238' ],
    marker  => [ 'ansi226' ],
    ol_bul  => [ 'ansi99' ],

    dim     => [ 'ansi55' ],
    callout => [ 'ansi252' ],
    error   => [ 'ansi196' ],
    okay    => [ 'ansi119' ],
    missing => [ 'ansi202' ],
  },
  steel   => {
    default => [ 'bright_white' ],
    bold    => [ 'bold', 'ansi75' ],
    header  => [ 'bold', 'ansi33' ],
    ping    => [ 'ansi220' ],
    prompt  => [ 'bold', 'ansi220' ],
    help1   => [ 'bold', 'ansi226' ],
    help2   => [ 'ansi186' ],
    bumper  => [ 'ansi27' ],
    marker  => [ 'bright_yellow' ],
    ol_bul  => [ 'ansi33' ],

    dim     => [ 'ansi20' ],
    callout => [ 'bright_green' ],
    error   => [ 'bright_red' ],
    okay    => [ 'bright_green' ],
    missing => [ 'bright_magenta' ],
  },
);

our %STYLE = $THEME{ $ENV{YAKKER_THEME} // 'dark' }->%*;

sub _expand_theme ($self, $theme) {
  # TODO: follow symbolic references

  return $theme;
}

sub set_theme ($self, $theme_name) {
  die "unknown theme: $theme_name\n" unless my $theme = $THEME{$theme_name};
  my $expanded = $self->_expand_theme($theme_name);
  %STYLE = %$theme;
}

my @SPINNERS = (
   ["🛌", "🔥", "🛌"],
   ["🔥", "💸", "🔥"],
   ["🤜", "🏉", "🤛"],
   ["🌎", "📧", "🌏"],
   ["🌭", "🥨", "🌭"],
   ["🐈", "🧶", "🐈"],
   ["🤠", "🍺", "🤠"],
   ["🧛", "🧄", "🧛"],
   ["🏝", "🌊", "🏝" ],
   ["🌀", "⛑️", "🌀"],
   ["😭", "😐", "😄"],
   ["😷", "🦠", "😷"],
);

sub wait_with_spinner {
  my ($self, $future, $arg) = @_;
  $arg //= {};

  my ($L, $M, $R) = @{ $SPINNERS[ rand @SPINNERS ] };

  require IO::Async::Timer::Periodic;
  my $timer = IO::Async::Timer::Periodic->new(
    interval => 0.05,
    on_tick  => sub {
      state $pos = 0;
      state $dir = 1;
      state $str = $M . (q{ } x 39);

      print "\33[2K\r$L $str $R";
      print " $arg->{label}" if length $arg->{label};

      substr $str, $pos, 1, " ";
      $pos += $dir;
      if ($pos >= 40 || $pos < 0) { $dir *= -1; $pos += $dir }
      substr $str, $pos, 1, $M;

      (select)->flush
    },
  );

  my $hide_cursor = $self->_terminfo->getstr('civis');
  my $show_cursor = $self->_terminfo->getstr('cnorm');

  $self->register_sigint_handler(show_cursor => sub {
    print $show_cursor if $show_cursor;
  });

  print $hide_cursor if $hide_cursor && $show_cursor;

  $timer->start;

  Yakker->loop->add($timer);

  $future->get;

  Yakker->loop->remove($timer);

  print $show_cursor if $hide_cursor && $show_cursor;

  $self->deregister_sigint_handler('show_cursor');

  my $len = 50;
  $len += (1 + length $arg->{label}) if length $arg->{label};

  print "\r", " " x $len, "\r";

  return $future;
}

1;
