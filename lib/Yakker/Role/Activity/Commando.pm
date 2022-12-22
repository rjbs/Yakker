package Yakker::Role::Activity::Commando;
use v5.20.0;
use Moo::Role;

use experimental qw(postderef signatures);

use Yakker::Util qw(cmderr cmdlast cmdnext);

with 'Yakker::Role::Activity', 'Yakker::Role::Readline';

requires 'commando';
requires 'prompt_string';

sub interact ($self) {
  say q{};
  my $input  = $self->get_input($self->prompt_string);

  cmdlast unless defined $input;
  cmdnext unless length $input;

  my ($cmd, $rest) = split /\s+/, $input, 2;
  if (my $command = $self->commando->command_for($cmd)) {
    my $code = $command->{code};
    $self->$code($cmd, $rest);
    cmdnext;
  }

  cmderr("I don't know what you wanted to do!");

  return $self;
}

no Moo::Role;
1;
