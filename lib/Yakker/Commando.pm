package Yakker::Commando;
use Moo;
use v5.20.0;
use warnings;

use experimental qw(postderef signatures);
use utf8;

use Yakker::Util qw(cmdnext cmderr colored matesay prefixes);
use List::Util qw(max);

use Yakker::Commando::Completionist;

use Sub::Exporter -setup => {
  groups => {
    setup => \'_build_commando_group'
  }
};

sub _build_commando_group {
  my ($class, $group, $arg) = @_;

  my $Commando = Yakker::Commando->new({
    help_sections => $arg->{help_sections},
  });

  return {
    commando => sub { $Commando },
    command  => sub { $Commando->add_command(@_) },
  };
}

my %DEFAULT_COMMAND;
$DEFAULT_COMMAND{debug} = [
  completion => [
    Yakker::Commando::Completionist::array_completion([ qw(on off) ])
  ],
  help    => {
    args    => 'ON/OFF',
    summary => "turn the debugging pane off or on",
  },
  sub ($self, $cmd, $rest) {
    my $enabled = Yakker->debugging_is_enabled;

    unless (length $rest) {
      matesay sprintf "Debugging is %s.", $enabled ? 'on' : 'off';
      cmdnext;
    }

    if ($rest eq 'on') {
      if ($enabled) {
        matesay "Debugging is already on, though!";
        cmdnext;
      }
      if (Yakker->enable_debugging) {
        matesay "Debugging enabled!";
        cmdnext;
      }
      cmderr "Couldn't start debugging.  (You have to run under tmux.)";
    }

    if ($rest eq 'off') {
      unless ($enabled) {
        matesay "Debugging is already off, though!";
        cmdnext;
      }
      Yakker->disable_debugging;
      matesay "Debugging disabled!";
      cmdnext;
    }

    cmderr("Look, it's either off or on, nothing else");
  },
];

sub print_help_index ($self) {
  my @sections = $self->help_sections->@*;
  unshift @sections, { key => '', title => '' }
    unless grep {; $_->{key} eq '' } @sections;

  my %help = $self->help_registry->%*;

  my %seen = map {; $_->{key} => 1 } @sections;
  for my $entry (values %help) {
    next if $seen{ $entry->{section} }++;
    push @sections, {
      key   => $entry->{section},
      title => "\u$entry->{section} Commands",
    };
  }

  my $w = 2 + max map {; length } keys %help;

  for my $section (@sections) {
    my $seckey = $section->{key};
    my @keys   = sort grep {; $help{$_}{section} eq $seckey } keys %help;

    next unless @keys; # Skip empty sections.

    say q{};

    if ($section->{title}) {
      say colored('header', $section->{title});
    }

    for (@keys) {
      my $entry = $help{$_};

      say colored('help1', $entry->{namepair}[0])
        . colored('help2', $entry->{namepair}[1])
        . ($entry->{args}
            ? colored('bold', " $entry->{args}")
            : q{})
        . colored('dim', '･' x ($w - length $_))
        . $help{$_}{summary};
    }
  }
}

sub print_help_for ($self, $str) {
  cmderr qq{Sorry, don't know the command "$str".}
    unless my $command = $self->command_for($str);

  my @help = (ref $command->{help} eq 'ARRAY') ? $command->{help}->@*
                                               : $command->{help};

  cmderr qq{Sorry, I've got no help for "$str".}
    unless @help;

  while (my $help = shift @help) {
    my $name = $help->{name} // (prefixes($command->{name}))[-1];

    print colored('bold', $name);
    print q{ } . $help->{args} if length $help->{args};
    print "\n";

    my $text = $help->{text} // $help->{summary};
    chomp $text;
    say $text;

    print "\n" if @help;
  }

  cmdnext;
}

$DEFAULT_COMMAND{'h.elp'} = [
  completion => [
    Yakker::Commando::Completionist::array_completion(sub ($activity, @) {
      [ $activity->commando->all_command_names ]
    })
  ],
  aliases => [ '?' ],
  help    => { summary => 'print this help' },
  sub ($self, $cmd, $rest) {
    if (length $rest) {
      $self->commando->print_help_for($rest);
    }

    $self->commando->print_help_index;
    cmdnext;
  },
];

# Possibly it would be faster to avoid the ENTERSUB of getting these registries
# and tables by having a global refhash in which each Commando was a key, and
# the value was the registry, replacing these attributes, effectively, with
# inside-out objects.  But it seems unlikely to ever matter.  Humans are way
# slower than computers. -- rjbs, 2020-03-07

has command_registry => (
  is => 'ro',
  default  => sub {  {}  },
  init_arg => undef,
);

# help_sections let's you split up help into sections to make it easier to
# scan, and it looks like this:
# [
#   { key => 'list', name => 'List-Manipulating Commands' },
#   { key => 'task', name => 'Task-Oriented Commands' },
# ]
#
# There is an implicit '' section with no name, unless '' is registered.
# Duplicates should be complained about during setup, eventually…
has help_sections => (
  is => 'ro',
  default => sub {  []  },
);

has help_registry => (
  is => 'ro',
  default  => sub {  {}  },
  init_arg => undef,
);

has _str_dispatch => (
  is => 'ro',
  default  => sub {  {}  },
  init_arg => undef,
);

has _re_dispatch => (
  is => 'ro',
  default  => sub {  {}  },
  init_arg => undef,
);

sub BUILD ($self, @) {
  $self->add_command($_, $DEFAULT_COMMAND{$_}->@*) for keys %DEFAULT_COMMAND;
}

sub add_command ($self, $name, @rest) {
  my $code = pop @rest if @rest and ref $rest[-1] eq 'CODE';

  my $COMMAND = $self->command_registry;
  my $HELP    = $self->help_registry;

  warn "command $name registered more than once" if $COMMAND->{$name};

  my $command = $COMMAND->{$name} = {
    @rest,
    name => $name,
    ($code ? (code => $code) : ()),
  };

  if ($command->{completion} && ref $command->{completion} eq 'ARRAY') {
    $command->{completion} = Yakker::Commando::Completionist::pos_completion(
      $command->{completion}->@*
    );
  }

  if ($command->{help}) {
    my @help = (ref $command->{help} eq 'ARRAY') ? $command->{help}->@*
                                                 : $command->{help};

    for my $help (@help) {
      my %entry;

      my $name  = $help->{name};
      my @hunks = $name;

      unless ($name) {
        @hunks = prefixes($command->{name});
        $name  = $hunks[-1];
      }

      $entry{section} = $help->{section} // '';

      $entry{name} = $name;
      $entry{args} = $help->{args};
      $entry{namepair} = $help->{namepair} // [
        $hunks[0],
        substr($hunks[-1], length $hunks[0])
      ];

      my $key = length $entry{args} ? "$name $entry{args}" : $name;

      $entry{summary} = $help->{summary} // '(no entry)';

      $HELP->{ $key } = \%entry;
    }
  }

  # Not a big fan.  Wouldn't it be better to allow both match and fixed
  # string?  But this leaves questions about "can you always match name, and
  # if so, what if you do not want as a typeable artifact."
  if ($command->{match}) {
    $self->_re_dispatch->{ $command->{name} } = $command->{match};
  } else {
    my $s_dispatch = $self->_str_dispatch;
    for my $entry ($command->{name}, @{ $command->{aliases} // [] }) {
      for my $str (prefixes($entry)) {
        warn "multiple commands registered to match $str" if $s_dispatch->{$str};
        $s_dispatch->{$str} = $command;
      }
    }
  }

  return;
};

sub command_for ($self, $cmd) {
  my $command;

  if ($command = $self->_str_dispatch->{$cmd}) {
    return $command;
  }

  my $re_dispatch = $self->_re_dispatch;
  if (my @matches = grep {; $cmd =~ $re_dispatch->{$_} } keys %$re_dispatch) {
    if (@matches > 1) {
      warn "Ambiguous dispatch, giving up: @matches\n";
      return undef;
      # XXX No errsay here anymore, so maybe we need a special value, or a
      # passed-in ambiguous case handler...
      #
      # errsay "Crikey, looks like I wanted to run more than one command.";
      # errsay "This really shouldn't happen, so I'm not going to do anything.";
      # errsay "The commands were: " . join(q{, }, sort @matches);
    }

    $command = $self->command_registry->{$matches[0]};
    return $command;
  }

  return undef;
}

# The "completer" property in a command definition is just a little mind-bendy,
# party because of how we drive Term::ReadLine::Gnu's tab completion.
#
# We expect our Yakker activity to register a rl_attempted_completion_function
# (RACF) that consults the Commando and either (a) match a command if editing
# arg0 or (b) look up the command currently being entered using command_for.
# That comand might provide a completer, C.  If so, RACF calls C, passing the
# Yakker activity and ($activity, $text, $line_buffer, $start, $end) — which
# is what you'd get in a generic RACF, except we've prepended $activity.
#
# C is expected to return a completion iterator, CI.  RACF will install CI as
# the current rl_completion_entry_function and return undef, meaning that CI
# will be called with ($word, $n), with increasing $n, until it returns undef.
# The strings returned by CI form the completion possibilities for the tab
# completion.

sub all_command_names ($self) {
  my %registry = $self->command_registry->%*;
  my @commands = map  { s/\.//gr }
                 grep { ! $registry{$_}{match} }
                 keys %registry;

  return @commands;
}

sub _build_completion_function ($self, $activity, $arg = {}) {
  # XXX: This is not right, but close enough for testing. -- rjbs, 2020-04-19
  my @commands = $self->all_command_names;

  my @specials = $arg->{specials} ? $arg->{specials}->@* : ();

  return sub ($text, $line_buffer, $start, $end) {
    for my $special (@specials) {
      if ($text =~ $special->[0]) {
        my $completer = $special->[1]->($activity, $text, $line_buffer, $start, $end);
        $activity->readline->Attribs->{completion_entry_function} = $completer;
        return undef;
      }
    }

    if (substr($line_buffer, 0, $start) =~ /\A\s*\z/) {
      my @options = grep { /^\Q$text/ } @commands;
      return $activity->_complete_from_array(\@options);
    }

    if ($line_buffer =~ s/\A(\s*)(\S+)(\s+)//) {
      my ($lspace, $cmd, $rspace) = ($1, $2, $3);
      $start -= length "$lspace$cmd$rspace";
      $end   -= length "$lspace$cmd$rspace";

      my $spec = $self->command_for($cmd);
      if (my $generator = $spec->{completion}) {
        my $completer = $activity->$generator($text, $line_buffer, $start, $end);
        $activity->readline->Attribs->{completion_entry_function} = $completer;
        return undef;
      }
    }

    # This prevents any kind of fallback behavior, like "complete based on
    # filenames in cwd," which kept cropping up when I used seemingly correct
    # solutions. -- rjbs, 2020-04-25
    return $activity->_complete_from_array([]);
  }
}

no Moo;
1;
