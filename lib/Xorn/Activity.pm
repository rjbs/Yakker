package Xorn::Activity;
use v5.20.0;
use Moo::Role;

use experimental qw(postderef signatures);

has app => (
  is => 'ro',
  required => 1,
);

requires 'interact';

no Moo::Role;
1;
