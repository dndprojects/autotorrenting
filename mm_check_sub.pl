
sub myunrar

{

# for example let location be tmp
my $location=$_[0];
my $path2 = abs_path $location;
search_all_folder_rar($path2);

foreach my $a (@my_rar_files) {
    my $movie_file = (split/,/,$a)[0];
	my $movie_folder = (split/,/,$a)[1];
	# need to add code to cheek if file is still active:
	#open(my $out, '>', $outfile) or die "Cannot open file '$outfile' for writing: $!";
	search_all_folder_part($movie_folder);
	#print $#my_part_files + 1 . "\n"; # second way to print array size
    if ($#my_part_files + 1 > 0 ) { last;}
	$cmd = "unrar lt \"$movie_folder/$movie_file\"";
	my ($status, $output) = executeCommand($cmd);
    my @ans = split(/\n/, $output);
     foreach my $line ( @ans ) {
       if ($line =~ /Name:/){$name = (split/\s+/,$line)[2] ; last}
    }  
       if	($name =~ m/\.mkv$/ or $name =~ m/\.avi$/ or $name =~ m/\.mp4$/ ) {
        push @my_rar_movies, $movie_file.",".$name.",".$movie_folder;
	   }
}

}

sub search_all_folder_part
{
my ($folder) = @_;
    if ( -d $folder ) {
        chdir $folder;
        opendir my $dh, $folder or die "can't open the directory: $!";
        while (defined( my $file = readdir($dh) ) ) {
             chomp $file;
             next if $file eq '.' or $file eq '..';
             search_all_folder_part("$folder/$file");  ## recursive call
			 next unless ($file =~ m/\.part$/ or $file =~ m/\.unrar.log$/);
			 push @my_part_files, $file . "," .$folder;
        }
        closedir $dh or die "can't close directory: $!";
    }
	#print "$folder\n";
}

sub search_all_folder_rar
{
my ($folder) = @_;
    if ( -d $folder ) {
        chdir $folder;
        opendir my $dh, $folder or die "can't open the directory: $!";
        while (defined( my $file = readdir($dh) ) ) {
             chomp $file;
             next if $file eq '.' or $file eq '..';
             search_all_folder_rar("$folder/$file");  ## recursive call
			 next unless ($file =~ m/\.rar$/ );
           #  print "$folder $file \n ";
			 push @my_rar_files, $file . "," .$folder;
        }
        closedir $dh or die "can't close directory: $!";
    }
	#print "$folder\n";
}

sub mywget 
{
     my $my_wget_file = $_[0];
	 my $my_local_file = $_[1];
	 my $cmd = "/usr/bin/wget --timeout=30 \"$my_wget_file\" -O \"$my_local_file\"";
	# print "$cmd\n";
     my ($status, $output) = executeCommand($cmd);
     if (-z $my_local_file) { 
	 print "Bad file $my_local_file removing it!\n"; 
	 print "check your wget cmd line: $cmd\n\n";
	 unlink $my_local_file or warn "Unable to remove '$my_local_file': $!";
	 $mywget = "false";
    } else {
	     print "file $my_local_file downloaded\n\n"; 
		 $mywget = "true";
	}
}
sub add_new_torrent 
{    
    my $t_file = $_[0];
	if ($OSNAME eq "linux") {
	if ($start_transmission_cmd ne "") {($t_status, $t_output) = executeCommand($start_transmission_cmd);}
	 $cmd = 'transmission-remote -a ';
	}
    if ($OSNAME eq "cygwin") {
     $cmd = $transmission_bin . '/transmission-remote -a ' ;
	# $t_file = $_[0] =~ s/\&/^&/gr;
	# print "$t_file\n";
    }
   
	$transmission_cmd = $cmd . "\"". $t_file . "\"";
	#print "$transmission_cmd\n";
    local ($t_status, $t_output) = executeCommand($transmission_cmd);
	#print "$t_output\n";
	my $test_torrent = "failed";
	if ($t_output =~ /success/) {$test_torrent = "success";}
    if ($t_output =~ /duplicate torrent/) {$test_torrent = "success";}
	# Error: duplicate torrent
	# Error: invalid or corrupt torrent file
	# localhost:9091/transmission/rpc/ responded: "success"
	# [2015-05-29 17:14:52.428 IDT] transmission-remote: Couldn't connect to server	
	$add_new_torrent = $test_torrent;
	#if ($test_torrent eq "failed") {print "$transmission_cmd \n$t_output\n";}
}

## slurp - read a file into a scalar or list
sub slurp {
    my $file = shift;
    local *F;
    open F, "< $file" or die "Error opening '$file' for read: $!";
    if(not wantarray){
        local $/ = undef;
        my $string = <F>;
        close F;
        return $string;
    }
    local $/ = "";
    my @a = <F>;
    close F;
    return @a;
}


sub search_all_folder
{
my ($folder) = @_;
    if ( -d $folder ) {
        chdir $folder;
        opendir my $dh, $folder or die "can't open the directory: $!";
        while ( defined( my $file = readdir($dh) ) ) {
             chomp $file;
             next if $file eq '.' or $file eq '..';
             search_all_folder("$folder/$file");  ## recursive call
			 next unless ($file =~ m/\.mkv$/ or $file =~ m/\.avi$/ or $file =~ m/\.mp4$/ );
            # print "$folder $file \n ";
			 push @my_movie_files, $file . "," .$folder;
        }
        closedir $dh or die "can't close directory: $!";
    }
	
}

#clean torrent
sub clean_torrent_by_file
{
   my $t_file = $_[0];
   if ($OSNAME eq "linux") {
         $cmd = 'transmission-remote -l ';
        }
    if ($OSNAME eq "cygwin") {
       $cmd =  $transmission_bin . '/transmission-remote -l  ' ;
    }
  # my $cmd = "transmission-remote -l";
   my ($status, $output) = executeCommand($cmd);
   my @ans = split(/\n/, $output);
 foreach my $line ( @ans ) {
   if ($line =~ /100%/){
    my @id = split(/\s+/, $line);
         if ($OSNAME eq "linux") {
         $cmd = 'transmission-remote -t -if $id[1]';
        }
    if ($OSNAME eq "cygwin") {
      $cmd = $transmission_bin . '/transmission-remote -t -if $id[1]  ' ;
    }
     #my $cmd = "transmission-remote -t -if $id[1]";
     my ($status, $output) = executeCommand($cmd);
     my @ans2 = split(/\n/, $output);
          foreach my $line2 ( @ans2 ) {
           if ($line2 =~ /100%/ and $line2 =~ /\Q$t_file\E/){}
            #   print "clean for $t_file id: $id[1]\n";
           clean_torrent_by_id($id[1]);
      last;
          }

   }
 }
}

sub clean_torrent_by_id
{    
    my $t = $_[0];
	if ($OSNAME eq "linux") {
	 $transmission_cmd = 'transmission-remote -t '.$t.' -r';
	}
    if ($OSNAME eq "cygwin") {
     $transmission_cmd = $transmission_bin . '/transmission-remote -t '.$t.' -r  ' ;
    } 
	print "$transmission_cmd\n";
    local ($t_status, $t_output) = executeCommand($transmission_cmd);
}
sub executeCommand
{
 $alarm_time = 60;
 my $command = join ' ', @_;
 if ($command =~ /unrar/) {$alarm_time = 3600; }
 if ($command =~ /transmission/) {$alarm_time = 600; }
 local $SIG{ALRM} = sub { die "Timeout\n" };
 eval {
   alarm $alarm_time; # change to timeout length
   ($? >> 8, $_ = qx{$command 2>&1});
  # alarm 0;
 };
}


sub use_iconv_on_srt
{
       $srt_file = $_[0];
      if (-e "/usr/bin/iconv") {
	    my $cmd = '/usr/bin/iconv -t "WINDOWS-1255" ' . $srt_file . ' > /tmp/tmp_iconv.srt';
        print "$cmd\n\n";
		my ($status, $output) = executeCommand($cmd); 	
        rename  "/tmp/tmp_iconv.srt" , $srt_file;
       }
}

sub clean_dir
{
       $dir = $_[1];
	   chdir  "/tmp" ;
	   $root_dir = $_[0];
            opendir(DIR, $dir);
             my @mkvfiles = grep(/\.mkv$/,readdir(DIR));
			 my @mkvfiles = grep(!/sample/,@mkvfiles);
			 my @mkvfiles = grep(!/Extras/,@mkvfiles);
			 closedir(DIR); opendir(DIR, $dir);
			 my @partfiles = grep(/\.part$/,readdir(DIR));
            closedir(DIR);
	    print "@mkvfiles @partfiles\n";
	   if ($root_dir ne $dir) {
	    if ($dir =~ /$root_dir/ && !@mkvfiles && !@partfiles)  {
	     print "deleteing dir $dir\n";
		 rmtree([ "$dir" ]);
	    }
	   }
	   
}
sub shell_email
 {
    #shell_email($info,$jpg,$send_mail_alias,$movies_dir,$name,"movie");
	print "sending mail to $send_mail_alias ...\n\n";
    $info = $_[0];
	$jpg = $_[1];
	$send_mail_alias = $_[2];
	$movies_dir = $_[3];
	$type = $_[5];
	$subject = " -s ";
	if ($type eq "tv") {$subject = "-s \"פרק חדש  --> $_[4] \" ";}
	if ($type eq "movie") {$subject = "-s \"סרט חדש --> $_[4] \" ";}
	
     if ($OSNAME eq "linux") {
        $email_cmd = 'env LANG=he_IL.UTF-8 mail '; 
     }
     if ($OSNAME eq "cygwin") {
       $email_cmd = "email ";
	   $send_mail_alias = $_[2] =~ s/ /\,/gr;
    }    
            #fix by Leon because of local
			my ($status, $output) = executeCommand('df -h ' . $movies_dir . '| tail -1' );
			#my ($status, $output) = executeCommand('df -h ' . $movies_dir . '| grep -v Filesystem' );
			$t =(split/\s+/,$output)[1];
			$n = (split/\s+/,$output)[3];
	        $info = $_[0] =~ s/\"/\\"/gr;
		    $total_disk =  "TOTAL DISK Left $n Out of $t\n";
		    $email_cmd = 'printf "'. $total_disk .' \n\n ' . $info . ' \n\n '. $jpg . ' "| '. $email_cmd . $subject .$send_mail_alias;
		  #  print "$email_cmd\n";
		  	my ($status, $output) =  executeCommand($email_cmd);
		#	print "$output\n";
}

 1;
