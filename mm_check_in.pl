#!/usr/bin/perl

#use strict;
use DBI;
use Cwd qw(abs_path);
use English qw' -no_match_vars ';
use File::Copy;
use File::Path 'rmtree';
use File::Find qw(find);
use File::Basename;
use Cwd qw(abs_path);
my $path = abs_path($0);
$root_dir  = dirname($path);

print "\nRoot dir $root_dir \n";

# read sub routines
use FindBin;      
use lib "$FindBin::Bin/.";
require "mm_check_sub.pl";

print "\nYour OS Type is $OSNAME ...\n";

$remote_files = "http://";
$remote_db = "/tmp/remote_movies.db";
$local_db = "/media/movies_local.db";
$check_for_tv = "false";
$use_iconv = "false"; # recommended for windows users this will change srt Unicode to ANSI
$use_convert = "false" ; # recommended for WDTV resize poster to 720x1080
$preferd_poster = "en" ; # options is "he" or "en"


# read user configure file
eval slurp("$root_dir/mm_check_options.pl");
$http_remote_db  = "${remote_files}/sqlite/movies.db" ;

# check movie / tv dir 
print "\nchecking transmission dir .. ";
if (-d $transmission_dir) {print "OK\n\n";
} else {print "not ok pls fix you options file\n\n"; exit()}

print "checking movie dir .. ";
if (-d $movies_dir) {print "OK\n\n";
} else {print "not ok pls fix you options file\n\n"; exit()}

print "checking tv series dir .. ";
if (-d $tv_series_dir) {print "OK\n\n";
} else {print "not ok will not check for tv\n\n"; $check_for_tv = "false"}

# exit if no local_db
if (not -e $local_db or (-s $local_db == 0)) { print "Bad local_db db!\n"; exit()}

# read local db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$local_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $local_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $local_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");


#unrar files
myunrar($transmission_dir);
foreach $a (@my_rar_movies){
    my $rar_file = (split/,/,$a)[0];
	my $movie_name = (split/,/,$a)[1];
    my $rar_dir = (split/,/,$a)[2];
	#print "$rar_file $movie_name $rar_dir\n";
	clean_torrent_by_file($rar_file);
	    foreach my $local_row (@$local_movies_row) {
             my ($name,$t_link,$srt,$jpg,$t_name) = @$local_row;
              if ($movie_name eq $t_name){
			   my $movie_rar_log = $t_name =~ s/.mkv/.unrar.log/r;
			   print "\nFound rar movie $name\n";
			   $cmd = "cd $rar_dir ; unrar e  -y $rar_file > $movie_rar_log ; rm -rf $movie_rar_log";
			    my ($status, $output) = executeCommand($cmd);
			     print "$output \n";
			  }
		}	
}


my $path = abs_path $transmission_dir;
search_all_folder($path);

foreach $a (@my_movie_files){
    my $movie_file = (split/,/,$a)[0];
	my $movie_folder = (split/,/,$a)[1];
    print "checking if movie in db: $movie_file\n";
	# check if file in movie db
	foreach my $local_row (@$local_movies_row) {
     my ($name,$t_link,$srt,$jpg,$t_name,$status,$info,$num,$imdb_genre,$imdb_rating,$imdb_id,$imdb_rated,$imdb_year,$imdb_he_jpg,$imdb_en_jpg,$imdb_trailer) = @$local_row;
     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
     my $jpg_file = $t_name =~ s/.mkv/.jpg/r; 
     my $movie_rar_log = $t_name =~ s/.mkv/.unrar.log/r;
	 if ($movie_file eq $t_name and (! -e "$movie_folder/$movie_rar_log")){
	 print "\nstart check-in for $t_name\n";
	 #shell_email($info,$jpg,$send_mail_alias,$movies_dir,$name,"movie");
	 clean_torrent_by_file($t_name);
     move($movie_folder .'/'. $movie_file, $transmission_dir.'/'.$t_name);
     clean_dir($transmission_dir,$movie_folder);
	 #srt
	 if (! -e "/tmp/$srt_file") {print "re-dwonloading srt for $name\n"; mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file); }
	 if (-e "/tmp/$srt_file") {
	    if ($use_iconv eq "true") {use_iconv_on_srt('/tmp/'.$srt_file);}
	    #move movie file:
		move($transmission_dir .'/'. $movie_file, $movies_dir.'/'.$name.'.mkv');
		#copy srt
		copy('/tmp/'.$srt_file, $movies_dir.'/'.$name.'.he.srt');
		move('/tmp/'.$srt_file, $movies_dir.'/'.$name.'.srt');
	    #jpg
		 if (! -e "/tmp/$jpg_file") { print "re-dwonloading jpg\n";
		 if ($preferd_poster eq "he" and ! -e "/tmp/$jpg_file") {print "downloading he poster \n" ; mywget($imdb_he_jpg,'/tmp/'.$jpg_file);}
		 if ($preferd_poster eq "en" and ! -e "/tmp/$jpg_file") {print "downloading en poster \n" ;mywget($imdb_en_jpg,'/tmp/'.$jpg_file);}
		 if (! -e "/tmp/$jpg_file")    {print "downloading defualt poster \n" ;mywget("$remote_files/$srt/$jpg_file",'/tmp/'.$jpg_file);}
		 #if convert 
		 if ($use_convert eq "true" and -e "/tmp/$jpg_file") {
		  my $cmd = "convert $imdb_he_jpg -resize 720x1080! '/tmp/'$jpg_file";
          my ($status, $output) = executeCommand($cmd);
          #print "$output\n";
		  }
		}
		 move('/tmp/'.$jpg_file, $movies_dir.'/'.$name.'.jpg');
	    #update db
	    $statement = "UPDATE movies SET status = ? WHERE name = ?";
	    $dbh->do($statement, undef, "done", $name); 
         shell_email($info,$jpg,$send_mail_alias,$movies_dir,$name,"movie");
	 } else { print "NO SRT for $name Movie ... exiting\n"; last;}
	 } 
	}

 if ($check_for_tv eq "true") {
         
 # check if file in tv db
   print "\nchecking if is  tv series is in db\n";
   foreach my $local_row (@$local_tv_row) {
    my ($name,$t_link,$srt,$jpg,$t_name,$status,$local_floder,$info,$num) = @$local_row;
	 if ($movie_file eq $t_name){
	  my @pf = split(/\./, $local_floder);
      my $spf= $pf[$#pf]; 
      my $top_folder = $local_floder =~ s/\.$spf//r; 
   	  my $srt_file = $t_name =~ s/.mkv/.srt/r; 
      print "\nstart check-in $t_name\n";
       clean_torrent_by_file($t_name);
       move($movie_folder .'/'. $movie_file, $transmission_dir.'/'.$t_name);
	   clean_dir($transmission_dir,$movie_folder);
	  #srt
	  if (! -e "/tmp/$srt_file") {print "re-dwonloading srt for $name\n"; mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file); }
      if (-e "/tmp/$srt_file") {
	     if ($use_iconv eq "true") {use_iconv_on_srt('/tmp/'.$srt_file);}
	   	 #move movie file:
		  if ( ! -d "$tv_series_dir/$top_folder/$local_floder" ) {
              mkdir ($tv_series_dir.'/'.$top_folder.'/'.$local_floder) or die "Failed to create path ..";
          } 
	      move($transmission_dir.'/'.$movie_file, $tv_series_dir.'/'.$top_folder.'/'.$local_floder.'/'.$name.'.mkv');
	     #copy srt
		  copy('/tmp/'.$srt_file, $tv_series_dir.'/'.$top_folder.'/'.$local_floder.'/'.$name.'.he.srt');	 
		  move('/tmp/'.$srt_file, $tv_series_dir.'/'.$top_folder.'/'.$local_floder.'/'.$name.'.srt');	 
	     #update db
	      $statement = "UPDATE tv_series SET status = ? WHERE name = ?";
          $dbh->do($statement, undef, "done", $name); 
          shell_email($info,$jpg,$send_mail_alias,$movies_dir,$name,"tv");
	      last;
	 } else { print "NO SRT for $name Movie ... exiting\n"; last;}
	} 
   }
   
 }
}

$dbh->disconnect();

