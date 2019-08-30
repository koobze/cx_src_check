use Data::Dumper;
use File::chdir;

if ( !defined($ARGV[0]) ) {
	print "Usage: src_analyzer.pl <path-to-source>\nThis script looks through the code identifying the extensions present and attempting to discover duplicate files/folders and 'test' functionality.\n";
	exit;
}

my $src_path = $ARGV[0];
$src_path = "." if ( $src_path =~ /^\s*$/ );


#open (DIRS, ">dirs.csv");

#rint DIRS "Dir1;# Files;Dir2;# Files;# files in common;\n";




$CWD = $src_path;
$src_path = $CWD;
$src_path_esc = $CWD;
$src_path_esc =~ s/\\/\\\\/g;

print "Checking source code in $src_path\n";


my @dir_list = `dir /-C /S`;


my @recommendations;

my %src_files;
my %filenames;
my @dupe_files;
my $total_files = 0;
my %src_dirs;
my $total_dirs = 0;
my %directories;
my %dir_links;


my $dir = '';
foreach my $entry ( @dir_list ) {
	if ( $entry =~ /Directory of (.*)\s*$/ ) {
		$dir = $1;
		$dir =~ s/$src_path_esc/./;
		
	} elsif ( $entry =~ m/^.*\s+\d+:\d+\s+([0-9]+)\s+([0-9a-zA-Z\._]\w+.*)\s*$/ ) {
		my ($size,$name) = ($1,$2);
		#print "$entry\n=> $dir;$name;$size;\n";
		addFile( $dir, $name, $size );
	} elsif ( $entry =~ m/<DIR>|Volume|Total Files|bytes free/ || $entry =~ m/File.*bytes\s*$/ || $entry =~ m/^\s*$/ ) {
	} else {
		print "What is $entry";
	}
}



print "Found $total_files files.\n";
my $root_dindex = $directories{".\\"};
print "Root dir is $src_path, contains ". $src_dirs{$root_dindex}{sfile_count} ." files total and ". $src_dirs{$root_dindex}{sdir_count} ." directories\n";

my $dupe_file_count = 0;

for my $dupe ( @dupe_files ) {
	my $dupe_count = $filenames{$dupe}{count};
	#print "\tFound possible $dupe $dupe_count times.\n";
	my %dupe_sizes;
	for my $dindex ( @{$filenames{$dupe}{files}} ) {
		#print $src_files{$dupe}{size} ." \t ". $src_files{$dupe}{dir} ."\n";
		if ( !defined $dupe_sizes{ $src_files{$dindex}{size} } ) {
			$dupe_sizes{ $src_files{$dindex}{size} } = [ $dindex ];
		} else {
			push @{$dupe_sizes{ $src_files{$dindex}{size} } }, $dindex;
		}
	}
	
	for my $size ( keys %dupe_sizes ) {
		if ( scalar @{$dupe_sizes{$size}} > 1 ) { # more than one file, same name, same size
			for my $dindex ( @{$dupe_sizes{$size}} ) {
				$src_files{$dindex}{is_dupe} = 1;
				for my $d2 ( @{$dupe_sizes{$size}} ) {
					next if ( int($dindex) > int($d2) );
					$dir_links{$dindex}{$d2} = 0 if ( !defined( $dir_links{$dindex}{$d2} ) );
					$dir_links{$dindex}{$d2}++;
				}
			}
		}
	}
}

my $unique_file_count = 0;
for my $file ( keys %src_files ) {
	if ( $src_files{$file}{is_dupe} != 1  ) {
		$unique_file_count++;
	} else {
		my $did = $src_files{$file}{dir};
		$src_dirs{$did}{file_dupe_count}++;
		while ( $did != -1 ) {
			$src_dirs{$did}{sfile_dupe_count}++;
			$did = $src_dirs{$did}{parent};
		}
	}	
}
my $dir_dupe_file_total_pct = 1; # notify if a folder contains more duplicate files than this % of total files
my $dir_dupe_file_pct = 80; # notify if a folder is this percent dupe
#for my $dir ( #sort { $src_dirs{$b}{sfile_dupe_count}/$src_dirs{$b}{sfile_count} <=> $src_dirs{$a}{sfile_dupe_count}/$src_dirs{$a}{sfile_count} } 
#			keys %src_dirs ) {
for ( my $dir = 1; $dir < $total_dirs; $dir++ ) {
	if ( $src_dirs{$dir}{sfile_count} > 0 ) {
		my $pct = 100 * $src_dirs{$dir}{sfile_dupe_count}/$total_files;
		my $local_pct = 100 * $src_dirs{$dir}{sfile_dupe_count}/$src_dirs{$dir}{sfile_count};
		if ( int($pct) > int($dir_dupe_file_total_pct) or int($local_pct) > int($dir_dupe_file_pct) ) {
			push @recommendations, int($local_pct)."% of ". $src_dirs{$dir}{dir} ." folder is duplicate files (".$src_dirs{$dir}{sfile_dupe_count}." duplicates, ".int($pct)."% of project total files)";
		}
	}
}

my %exts;
for my $file ( keys %filenames  ) {
	my $ext = lc $file;
	$ext =~ s/^.*\.//g;
	$exts{$ext} = 0 if ( !defined( $exts{$ext} ) );
	$exts{$ext} += $filenames{$file}{count};
}

print "List of File Extensions:\n";
my $misc_pct = 0;
for my $ext ( sort { $exts{$b} <=> $exts{$a} } keys %exts ) {
	my $pct = 100 * $exts{$ext}/$total_files;
	if ( $pct > 10 ) {
		print "\t~". int($pct) ."% $ext\n";
	} else {
		$misc_pct += $pct;
	}
}

if ( $misc_pct > 0 ) {
	print "\t~". int ($misc_pct) ."% misc\n";
}


print "\nThere are $unique_file_count unique files - ". int( 100 * $unique_file_count/$total_files ) ."% of all files\n";


#close FILES;
#close DIRS;

##############################################################################
# wrap up
##############################################################################

if ( scalar @recommendations > 0 ) {
	print "Consider the following recommendations:\n";
	for my $rec ( @recommendations ) {
		print " * $rec\n";
	}
}


##############################################################################
# end
##############################################################################






sub addFile {
	my ( $dir, $file, $size ) = ( shift, shift, shift );
	
	#print "Adding file $file\n";
	$total_files++;
	$dir_index = 0;
	if ( !defined( $directories{$dir} ) ) {
		$dir_index = addDir( $dir );
	} else {
		$dir_index = $directories{$dir};		
	}
	
	$src_files{$total_files}{size} = $size;
	$src_files{$total_files}{dir} = $dir_index;
	$src_files{$total_files}{file} = $file;
	
	
	addFileToDir( $total_files, $dir_index );
	
	#print "$total_files $dir$file\n";
	if ( !defined $filenames{$file} ) {
		$filenames{$file}{files} = [ $total_files ];
		$filenames{$file}{count} = 1;
	} else {
		push @dupe_files, $file if ( $filenames{$file}{count} == 1 );
		push @{$filenames{$file}{files}}, $total_files;
		$filenames{$file}{count}++;
	}	
}

sub addFileToDir {
	my ($fid, $did) = (shift,shift);
	
	$src_dirs{$did}{file_count}++;
	push @{$src_dirs{$did}{files}}, $fid;
		
	#print "Adding $fid to $did\n";
	#print "->". $src_dirs{$did}{dir} ." \ ". $src_files{$fid}{file} ." \n";
	
	my $tid = $did;
	while ( $tid != -1 ) {
		$src_dirs{$tid}{sfile_count}++;
		$tid = $src_dirs{$tid}{parent};
	}
}

sub addDir {
	my $dir = shift;
	
	my @dirs = split /\\/, $dir;
	#print "Dir is $dir. Breaks down into:\n";
	my $path = "";
	my $parent = -1;
	
	
	my $dindex = 0;
		
	for my $td ( @dirs ) {
		$path .= $td ."\\";
		#print "-> $path\n";
		
		
		if ( !defined( $directories{$path} ) ) {			
			$total_dirs ++;	
			$dindex = $total_dirs;
			
			$src_dirs{$dindex}{dir} = $path;
			$src_dirs{$dindex}{files} = [];
			$src_dirs{$dindex}{file_count} = 0;
			$src_dirs{$dindex}{sfile_count} = 0;
			$src_dirs{$dindex}{dirs} = [];
			$src_dirs{$dindex}{dir_count} = 0;
			$src_dirs{$dindex}{sdir_count} = 0;
			$src_dirs{$dindex}{file_dupe_count} = 0;
			$src_dirs{$dindex}{sfile_dupe_count} = 0;
			$src_dirs{$dindex}{parent} = $parent;
			$directories{$path} = $dindex;
			if ( $parent != -1 ) { # new directory, add to immediate parent's dir count
				$src_dirs{$parent}{dir_count}++; 
				push @{$src_dirs{$parent}{dirs}}, $dindex;
				
				
				my $tp = $parent;
				while ( $tp != -1 ) {
					$src_dirs{$tp}{sdir_count}++; 
					$tp = $src_dirs{$tp}{parent};
				}
			}
			
			push @recommendations, "Remove $path if it contains test code" if ( $td=~ /test/i );
			
			#print "Created dir $dindex: $path\n";
		} else {
			$dindex = $directories{$path};
		}
		
		
		$parent = $dindex;		
	}	
	
	return $dindex;
}