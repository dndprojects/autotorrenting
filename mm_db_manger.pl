#! /usr/bin/perl

use utf8;
use DBI;
use FindBin;      
use lib "$FindBin::Bin/.";
use File::Find qw(find);
use File::Basename;
use Cwd qw(abs_path);
my $path = abs_path($0);
$root_dir  = dirname($path);

print "Root dir $root_dir \n";

require "mm_check_sub.pl";

print "\nYour OS Type is $OSNAME ...\n";

$local_db = "/media/movies_local.db";
$remote_files = "http://";

#read user configure file
eval slurp("$root_dir/mm_check_options.pl");

# exit if no local_db
if (not -e $local_db or (-s $local_db == 0)) { print "Bad local_db db!\n"; exit()}

# read local db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$local_db","","",{ RaiseError => 1 },) or die $DBI::errstr;

$command = "";
while  ($command ne "q" ) {
  
  print "Please enter the table \"m\" for movies, \"t\" for TV, enter \"q\" for quit \n";
  my $command = <STDIN>;
  chomp $command;
  if ($command eq "q") {last;}
  my $local_row_table = $dbh->selectall_arrayref("SELECT * FROM movies");
  if ($command eq "t") {$table = "tv_series" ; $local_row_table = $dbh->selectall_arrayref("SELECT * FROM tv_series");}
  if ($command eq "m") {$table = "movies" ;$local_row_table = $dbh->selectall_arrayref("SELECT * FROM movies");}
  my $i = 0;
  foreach my $local_row (@$local_row_table) {
     my ($name,$t_link,$srt,$jpg,$t_name) = @$local_row;
	 $enrty_to_del[$i] = $name;
     printf("%s %-25s %25s\n" , $i,$name,$t_name);;
	 $i++;
  }
  print "Please enter line number to delete, \"q\" for quit \n";
  $line_to_del = <STDIN>;
  chomp $line_to_del;
  if ($line_to_del eq "q") {last;}
  $name = $enrty_to_del[$line_to_del];
  print "you selected to delete \"$name\" type \"y\" to continue\n";
  $aprove = <STDIN>;
  chomp $aprove;
   if ($aprove eq "y") {
      my $sql = 'DELETE from '. $table . ' WHERE name = ?';
      my $sth = $dbh->prepare($sql);
      $sth->execute($name);
  }
}
$dbh->disconnect();
