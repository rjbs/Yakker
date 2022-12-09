package Yakker::Debug;

use v5.20.0;
use warnings;

use experimental qw(signatures);

use Digest::MD5 qw(md5);

my %color_for = ('Yakker::Debug' => 'bold bright_black');

sub str_color ($str) {
  # I know, I know, this is ludicrous, but guess what?  It's my Sunday and I
  # can spend it how I want.
  state $max = ($ENV{COLORTERM}//'') eq 'truecolor' ? 255 : 5;
  state $min = $max == 255 ? 384 : 5;
  state $inc = $max == 255 ?  16 : 1;
  state $fmt = $max == 255 ? 'r%ug%ub%u' : 'rgb%u%u%u';

  return $color_for{$str} //= do {
    my @rgb = map { $_ % $max } unpack 'CCC', md5($str);

    my $i = ($rgb[0] + $rgb[1] + $rgb[2]) % 3;
    while (1) {
      last if $rgb[0] + $rgb[1] + $rgb[2] >= $min;

      my $next = $i++ % 3;

      $rgb[$next] = abs($max - $rgb[$next]);
    }

    sprintf $fmt, @rgb;
  }
}

sub _kill_tmux_pane ($self, $id) {
  system {"tmux"} "tmux", "kill-pane", "-t", "%$id"
}

sub _tmux_window_pane_ids {
  my @lines = `tmux list-panes`;
  my @ids = map {; m/%([0-9]+)/ ? $1 : () } @lines;
  return @ids;
}

my $ORIGINAL_STDERR;
BEGIN { open $ORIGINAL_STDERR, '>&2' or die "could not dup stderr: $!" }

my $PANE_KILLER;

sub disable_debugging {
  unless ($ORIGINAL_STDERR) {
    warn "can't disable debugging because ... it was never enabled?";
    return;
  }

  $PANE_KILLER->() if $PANE_KILLER;

  *STDERR = $ORIGINAL_STDERR;
  delete $SIG{__WARN__};
}

sub enable_debugging {
  return unless $ENV{TMUX};

  require Data::Printer;
  require Path::Tiny;
  require Scope::Guard;
  require Term::ANSIColor;

  our $logfile = Path::Tiny->tempfile;
  open *STDERR, '>', "$logfile" or die "can't write to $logfile: $!";
  STDERR->autoflush(1);

  Data::Printer->import({
    colored => 1,
    return_value => 'dump',
    use_prototype => 0,
  });

  my %known_pane = map {; $_ => 1 } _tmux_window_pane_ids;

  system {"tmux"} "tmux", "split-window", "-d", "-p", "30", "tail -f $logfile";

  my ($new_pane_id) = grep { ! $known_pane{$_} } _tmux_window_pane_ids;

  die "couldn't determine new pane id!?" unless $new_pane_id;

  $PANE_KILLER = sub { __PACKAGE__->_kill_tmux_pane($new_pane_id) };
  state $guard = Scope::Guard->new($PANE_KILLER);
  Yakker->register_sigint_handler('pane-killer' => $PANE_KILLER);

  $SIG{__WARN__} = sub {
    my $package = caller;
    print {*STDERR} (
      Term::ANSIColor::color('bold bright_white'), '[',
      Term::ANSIColor::color(str_color($package)), $package,
      Term::ANSIColor::color('bold bright_white'), '] ',
      Term::ANSIColor::color('reset'),
    );

    if (@_ == 1 && ref $_[0]) {
      print {*STDERR} "(data structure follows)\n";
      print {*STDERR} p($_[0]), "\n";;
      return;
    }

    print {*STDERR} @_;
  };

  warn "Debugging mode engaged, tailing $logfile\n";

  return 1;
}

1;
