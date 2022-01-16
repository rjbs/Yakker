package Xorn::Commando::Completionist;

use v5.20.0;
use warnings;

use experimental qw(postderef signatures);

use Sub::Exporter -setup => [ qw(
  any_completion
  array_completion
  pos_completion
) ];

use List::MoreUtils ();
use List::Util qw(max);

# COMP-ARG := (TEXT, I)
# COMP-FN  := COMP-ARG -> [ STR | UNDEF ]
# GEN-ARG  := ACTIVITY, TEXT, LINE, START, END
# GEN-FN   := GEN-ARG -> COMP-FN

# [ ARRAY | CODE ] -> GEN-FN
sub array_completion ($arg) {
  if (ref $arg eq 'ARRAY') {
    return sub ($activity, $text, @) {
      my @opts = grep { /^\Q$text/ } @$arg;
      sub { shift @opts }
    }
  }

  if (ref $arg eq 'CODE') {
    return sub ($activity, $text, @) {
      my $arrayref = $arg->(@_);
      my @opts = grep { /^\Q$text/ } @$arrayref;
      sub { shift @opts };
    }
  }

  Carp::confess("bogus argument to array_completion: $arg");
}

# LIST< GEN-FN > -> GEN-FN
sub any_completion (@generators) {
  sub (@gen_arg) {
    my @completers = map {; $_->(@gen_arg) } @generators;

    # We will call all completion routines up front, sort and deduplicate, and
    # then return a simple list iterator.  This is pretty inefficient, but I
    # don't care right now.

    my @options;
    for my $completer (@completers) {
      my $i = 0;
      while (defined (my $option = $completer->($gen_arg[1], $i++))) {
        push @options, $option;
      }
    }

    @options = sort { $a cmp $b } List::MoreUtils::uniq @options;

    return sub { shift @options; }
  }
}

# You pass it (g1, g2, g3... gi) and maybe (\%arg)
#
# It will use gn for completing when you are on argument n.
#
# If gn is undef, it will refuse to complete.
#
# Valid args include:
#   tail => a generator to use for positions past i
sub pos_completion (@generators) {
  my $arg;
  if ($generators[-1] && ref $generators[-1] eq 'HASH') {
    $arg = pop @generators;
  }

  # This makes absolutely no concession for quoted strings, which is fine
  # because we don't use them yet, but eventually we will, so like… we'll come
  # back and fix this, right? -- rjbs, 2020-04-25
  return sub ($activity, $text, $line, $start, $end) {
    #   v----------------  0: pos 0
    #     v--------------  2: arg0 begins
    #         v----------  6: arg1 begins
    #             v------ 10: arg2 begins
    # >   eat pie --typ apple --when now
    #                 ^-- 15: insertion point after 'p'; n = 2
    #
    # For now, we'll only match at the very end of a word.
    #
    #   0  ''
    #   1  '  '
    #   2  'eat'
    #   3  ' '
    #   4  'pie'
    #   5  ' '
    #   6  '--typ'
    #   7  ' '
    #   8  'apple'
    #   9  ' '
    #  10  '--when'
    #  11  ' '
    #  12  'now'

    my @bits = split /(\s+)/, $line;
    shift @bits if @bits && $bits[0] eq '';

    my $n;

    if ($start == 0 && $end == 0) {
      $n = 0;
    } else {
      my $pos = 0;
      my %arg_ending_at;
      my %state_from = (0 => [ before => 0 ]);
      for my $bit (@bits) {
        $pos += length $bit;
        $arg_ending_at{ $pos } = 0 + keys %arg_ending_at if $bit =~ /\S/;
      }

      $n = $arg_ending_at{ $end };

      if ( ! defined $n && keys %arg_ending_at) {
        my $max_argn = max values %arg_ending_at;
        $n = $max_argn + 1 if $end > $max_argn;
      }
    }

    # No match, give up.
    return sub { undef } unless defined $n;

    # Past the end of our input:
    if ($n > $#generators) {
      return $arg->{tail}->($activity, $text, $line, $start, $end)
        if $arg->{tail};

      return sub { undef };
    }

    # Explicit undef means "never match."
    return sub { undef } unless $generators[$n];

    # There's a generator, so let's generate.
    return $generators[$n]->($activity, $text, $line, $start, $end);
  };
}

1;
