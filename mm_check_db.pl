#!/usr/bin/perl


use DBI;
use English qw' -no_match_vars ';
use FindBin;      
use File::Basename;
use lib "$FindBin::Bin/.";
use Cwd qw(abs_path);
my $path = abs_path($0);
$root_dir  = dirname($path);

print "Root dir $root_dir \n";

require "mm_check_sub.pl";

printf "\n";
print "Your OS Type is $OSNAME ...\n";

$remote_files = "http://";
$remote_db = "/tmp/remote_movies.db";
$local_db = "/media/movies_local.db";
$check_for_tv = "false";
$use_iconv = "false"; # recommended for windows users this will change srt Unicode to ANSI
$use_convert = "false" ; # recommended for WDTV resize poster to 720x1080
$preferd_poster = "en" ; # options is "he" or "en"
$start_transmission_cmd = 'systemctl start transmission';


# read user configure file
eval slurp("$root_dir/mm_check_options.pl");

$http_remote_db  = "${remote_files}/sqlite/movies.db" ;

print "\nchecking transmission dir .. ";
if (-d $transmission_dir) {print "OK\n\n";
} else {print "not ok pls fix you options file\n\n"; exit()}

print "checking movie dir .. ";
if (-d $movies_dir) {print "OK\n\n";
} else {print "not ok pls fix you options file\n\n"; exit()}

print "checking tv series dir .. ";
if (-d $tv_series_dir) {print "OK\n\n";
} else {print "not ok will not check for tv\n\n"; $check_for_tv = "false"}

# delete remote_db file before new download
if (-e $remote_db) { print "Dwonloading remote db file from $http_remote_db \n\n"; unlink $remote_db}
my $cmd = "/usr/bin/wget $http_remote_db -O $remote_db";
my ($status, $output) = executeCommand($cmd);
#print "$output\n";

# exit if no remote_db
if (not -e $remote_db or (-s $remote_db == 0)) { print "Bad remote db!\n"; exit()}

if (not -e $local_db or (-s $local_db == 0)) { print "Bad local db re-downloading db!\n";
 mywget($http_remote_db,$local_db);
}


# read remote db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$remote_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $remote_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $remote_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");
$dbh->disconnect();

# read local db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$local_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $local_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $local_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");
#$dbh->disconnect();

#name,t_link,srt,jpg,t_name,status,info,num,imdb_genre,imdb_rating,imdb_id,imdb_rated,imdb_year,imdb_he_jpg,imdb_en_jpg,imdb_trailer
#check for new movie
print "checking for new movie ...\n\n";
foreach my $remote_row (@$remote_movies_row) {
   my ($name,$t_link,$srt,$jpg,$t_name,$status,$info,$num,$imdb_genre,$imdb_rating,$imdb_id,$imdb_rated,$imdb_year,$imdb_he_jpg,$imdb_en_jpg,$imdb_trailer) = @$remote_row;
   #name	t_link	srt	jpg	t_name	status	info	num	imdb_genre	imdb_rating	imdb_id	imdb_rated	imdb_year	imdb_he_jpg	imdb_en_jpg	imdb_trailer
   foreach my $local_row (@$local_movies_row) {
    my ($local_movie,$l_t_link,$l_srt,$l_jpg,$l_t_name,$local_status,$l_info) = @$local_row;
	if ($name eq $local_movie){
	     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
	     my $l_srt_file = ${name} . ".srt"; 
	    # redownload new srt
		#  print "$local_movie $status $local_status $movies_dir/$l_srt_file\n";
      if ($status eq "srt.redownload" and $local_status eq "done") {
         if (-e "$movies_dir/$l_srt_file") { unlink "$movies_dir/$l_srt_file";}
		     mywget("$remote_files/$srt/$srt_file","$movies_dir/$l_srt_file");
             $statement = "UPDATE movies SET status = ? WHERE name = ?";
			 $dbh->do($statement, undef, "done.redownload.srt", $name); 
      } 
	 	      $name = "";
              last;
    }
   }
   if ($name ne "" and $t_link ne "") {
     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
     my $jpg_file = $t_name =~ s/.mkv/.jpg/r; 
	 my $remore_torrent_file = $t_name =~ s/.mkv/.torrent/r; 

   #  print "$name \n";
	  print "$name  $srt_file\n";
	  $resulte = add_new_torrent($t_link);
	  if ($resulte eq "failed") { 
	    $t_link = "$remote_files/srt/torrents/$remore_torrent_file";
	    $resulte = add_new_torrent($t_link);
		#print "$resulte --> $t_link";
	  }
     if ($resulte eq "success") {
	    #wget srt/jpg to tmp 
		 print "Start Dwonloading \"$name\" Movie Over transmission \n\n";
		 mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file);
		 #chose  poster ...
         if ($preferd_poster eq "he" and ! -e "/tmp/$jpg_file") {print "downloading he posrt \n" ; mywget($imdb_he_jpg,'/tmp/'.$jpg_file);}
		 if ($preferd_poster eq "en" and ! -e "/tmp/$jpg_file") {print "downloading en posrt \n" ;mywget($imdb_en_jpg,'/tmp/'.$jpg_file);}
		 if (! -e "/tmp/$jpg_file")    {print "downloading defualt posrt \n" ;mywget("$remote_files/$srt/$jpg_file",'/tmp/'.$jpg_file);}
		 #if convert 
		 if ($use_convert eq "true" and -e "/tmp/$jpg_file") {
		  my $cmd = "convert $imdb_he_jpg -resize 720x1080! '/tmp/'$jpg_file";
          executeCommand($cmd);
		 }
        # update local db with new movie
		$status ="downloading";
        $dbh->do('INSERT INTO movies (name,t_link,srt,jpg,t_name,status,info,num,imdb_genre,imdb_rating,imdb_id,imdb_rated,imdb_year,imdb_he_jpg,imdb_en_jpg,imdb_trailer) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',  undef, $name,$t_link,$srt,$jpg,$t_name,$status,$info,$num,$imdb_genre,$imdb_rating,$imdb_id,$imdb_rated,$imdb_year,$imdb_he_jpg,$imdb_en_jpg,$imdb_trailer);
		print "\n$name add to your local db..\n\n";
     } else {print "transmission faild on $name\n"}
  }
 
}

    if ($check_for_tv eq "false") {
        print "not cheaking for new tv show !\n";
       $dbh->disconnect();
       exit();
    }

 # check for new tv
print "checking for new tv series ...\n\n";

foreach my $remote_row (@$remote_tv_row) {
  
   my ($name,$t_link,$srt,$jpg,$t_name,$status,$folder,$info,$num) = @$remote_row;
   my @pf = split(/\./, $folder);
   my $spf= $pf[$#pf]; 
   my $top_folder = $folder =~ s/\.$spf//r; 
   
   foreach my $local_row (@$local_tv_row) {
    my ($local_tv,$l_t_link,$l_srt,$l_jpg,$l_t_name,$local_status,$l_local_floder,$l_info,$l_num) = @$local_row;
	if ($local_tv eq $name){
	   my $srt_file = $t_name =~ s/.mkv/.srt/r; 
	   my $l_srt_file = ${name} . ".srt"; 
	    # re download new srt
      if ($status eq "srt.redownload" and $local_status eq "done") {
         if (-e "$tv_series_dir/$l_srt_file") { unlink "$tv_series_dir/$top_folder/$folder/$l_srt_file";}
		     mywget("$remote_files/$srt/$srt_file","$tv_series_dir/$top_folder/$folder/$l_srt_file");
             $statement = "UPDATE tv_series SET status = ? WHERE name = ?";                             
			 $dbh->do($statement, undef, "done.redownload.srt", $name); 
      } 	 
	   # fix bad mkv name	   
	       if ($status eq "t_name.reread" and $local_status eq "downloading") {    
             print "fixing mkv name or $name\n";		   
             $statement = "UPDATE tv_series SET t_name = ? WHERE name = ?";                             
			 $dbh->do($statement, undef, $t_name, $name); 
      } 
	 $name = "";
     last;
	 }
	}
	
	 $my_tv_folder =   "$tv_series_dir/$top_folder";
	 #print "$name  $tv_series_dir/$top_folder  $t_link\n";
    if ($name ne "" and $t_link ne "" and -d $my_tv_folder ) {
     $resulte = add_new_torrent($t_link);
    if ($resulte eq "failed") { 
	    $remore_torrent_file = $t_name =~ s/.mkv/.torrent/r; 
		$t_link = "$remote_files/srt/torrents/$remore_torrent_file";
	    $resulte = add_new_torrent($t_link);
		#print "$resulte --> $t_link";
	}
	 print "$resulte\n";
	 if ($resulte eq "success") {
	    #wget srt/jpg to tmp
     	 my $srt_file = $t_name =~ s/.mkv/.srt/r; 
		 mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file);
        # update local db with new tv_series
		$status ="downloading";
        $dbh->do('INSERT INTO tv_series (name,t_link,srt,jpg,t_name,status,folder,info,num) VALUES (?,?,?,?,?,?,?,?,?)',  undef, $name,$t_link,$srt,$jpg,$t_name,$status,$folder,$info,$num);
         print "\n$name add to your local db..\n\n";
   }
   }
}


$dbh->disconnect();
