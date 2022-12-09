package Yakker::ParseUtil;
use v5.20.0;
use warnings;

use experimental 'signatures';
use utf8;

use Sub::Exporter -setup => [ qw(
  parse_colonstrings
) ];

# Even a quoted string can't contain control characters.  Get real.
our $qstring  = qr{[“"]( (?: \\["“”] | [^\pC"“”] )+ )[”"]}x;
our $ident_re = qr{[-a-zA-Z][-_a-zA-Z0-9]*};

sub parse_colonstrings ($text, $arg) {
  my @hunks;

  state $switch_re = qr{
    \A
    ($ident_re)
    (
      (?: : (?: $qstring | [^\s:"“”]+ ))+
    )
    (?: \s | \z )
  }x;

  my $last = q{};
  TOKEN: while (length $text) {
    $text =~ s/^\s+//;

    # Abort!  Shouldn't happen. -- rjbs, 2018-06-30
    return undef if $last eq $text;

    $last = $text;

    if ($text =~ s/$switch_re//) {
      my @hunk = ($1);
      my $rest = $2;

      while ($rest =~ s{\A : (?: $qstring | ([^\s:"“”]+) ) }{}x) {
        push @hunk, length $1 ? ($1 =~ s/\\(["“”])/$1/gr) : $2;
      }

      push @hunks, \@hunk;

      next TOKEN;
    }

    push @hunks, $arg->{fallback}->(\$text) if $arg->{fallback};
  }

  return \@hunks;
}

1;
