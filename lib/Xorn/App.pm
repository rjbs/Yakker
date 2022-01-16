package Xorn::App;
use v5.20.0;
use Moo::Role;

use experimental qw(postderef signatures);

requires 'name';

no Moo::Role;
1;
