#!/usr/bin/perl -w

use Date::Parse;
use Data::Dumper qw(Dumper);
use POSIX 'strftime';

#global local time
#$currentTimestamp = time;
#$users_dir = "dataset-medium";
#search('Alexandre');

sub zIDtoName {
    my ($username) = @_;
    my $file = "$users_dir/$username/user.txt";
	my $fullname;
	
	if (open(F, "<$file")) {
		my @fullname = grep /^full_name=/, <F>;
		$fullname = $fullname[0];
		$fullname =~ s/^full_name=//;
		chomp $fullname;
		close(F);
	} else {
		#don't do anything
		$fullename = $username;
	}

	return $fullname;
}

sub get_avatar_link {
    my ($username) = @_;
    my $file = "$users_dir/$username/profile.jpg";
	
    #test if file exists
    if ( -e "$file") {
        return $file;
    } else {
        #return default avatar
        return "src/images/avatar_default.jpg";
    }
}

sub build_matelist_html {
	my ($userID, $matename, $profilepic) = @_;
    return if (isSuspended($userID));
	my $userLoc = getUserLoc($userID);
	$userLoc = "<br>" if (!$userLoc);
    
    if (!isFriend($userID) && isPrivate($userID,"interactions")) {
        $userLoc = "User has chosen to keep this private.";
    }
	return<<eof
	<li class="list-group-item">
		<a href="?action=profile&profile_id=$userID" class="thumb-sm pull-left m-r-sm">
		 <img src="$profilepic" class="img-circle">
		</a>
		<a href="?action=profile&profile_id=$userID" class="clear">
		 <strong class="block">$matename</strong>
		 <small>$userLoc</small>
		</a>
	</li>
eof
}

sub build_post_html {
    my ($authorID, $authorName, $timeStamp, $message,$commentCount, $postDir) = @_;
    return if (isSuspended($authorID));
    my $avatar = get_avatar_link($authorID);
    #convert timestamp to something readable
    my $postdate = strftime '%a, %d %b %y', localtime $timeStamp;
	$postDir =~ /$users_dir\/z\d{7}\/posts\/(.*)/;
	my $postID = $1;
return<<eof
    <div class="col-lg-12">
      <section class="panel">
        <div class="panel-body">
          <div class="clearfix m-b">
            <small class="text-muted pull-right">Posted on $postdate</small>
            <a href="#" class="thumb-sm pull-left m-r">
              <img src="$avatar" class="img-circle">
            </a>
            <div class="clear">
              <a href="?action=profile&profile_id=$authorID"><strong>$authorName</strong></a>
              <small class="block text-muted">Mate</small>
            </div>
          </div>
          <p>
            $message
          </p>
          <small class="">
            <a href="?action=post&a=$authorID&b=pid$postID"><i class="icon-comment-alt"></i> Comments ($commentCount)</a>
          </small>
        </div>
        <footer class="panel-footer pos-rlt">
          <span class="arrow top"></span>
          <form class="pull-out">
            <input type="text" class="form-control no-border input-lg text-sm" placeholder="Write a comment...">
          </form>
        </footer>
      </section>
    </div>
eof

}

sub get_commentCount {
	my ($postdir) = @_;
	my $commentCount = 0;
	$postdir .= "/comments";
	if (opendir DIR, $postdir) {
		while (my $file = readdir(DIR)) {	
			if (-d "$postdir/$file" && $file =~ /\d+/) {
				$commentCount++;
			}		
		}
		closedir DIR;
    }
	return $commentCount;	
}

sub get_matereq_html {
	my ($userID) = @_;
	my $avatar = get_avatar_link($userID);
	my $name = zIDtoName($userID);
	
	return <<eof
	<a href="?action=profile&profile_id=$userID" class="media list-group-item">
		<span class="pull-left thumb-sm">
		  <img src="$avatar" alt="$name" class="img-circle">
		</span>
		<span class="media-body block m-b-none">
		  $name wants to be your mate
		</span>
	</a>
eof

}

sub get_user_mates {
	my ($username) = @_;
	my $file = "$users_dir/$username/user.txt";
	open(F, "<$file");
	my @mates = grep /^mates=/, <F>;
	my $mates = $mates[0];
	@mates = $mates =~ m/(z\d{7})/g;
	close(F);
	return @mates;
}

sub get_timeline {
    my ($username, %searchMode) = @_;
    my @mates;
    my $mates;
    my %posts;
    my %files;
    my $mate;
    my %names;
	my $printHtml;
	my %displayPics;
	my $matelist_html;
	
	#get user's display stuff
	$names{$username} = zIDtoName($username);
	my $profilepic = get_avatar_link($username);
	
	# find user's mates
	@mates = get_user_mates($username);
	
	#get links to all their profile pics
	foreach $mate (@mates) {
		# grab their names and hash it
		$names{$mate} = zIDtoName($mate) if(!exists $names{$mate});
		$displayPics{$mate} = get_avatar_link($mate);
	}
	
	#check user notifications
	#get mate requests
	my $notifications = "0";
	my @mateReqs = getMateRequests();
	my @mateReqhtml;
	my $noti_matereq_html;
	$notifications += scalar @mateReqs;
	
	foreach my $mateReq (@mateReqs) {
		push @mateReqhtml, get_matereq_html($mateReq);
	}
	$noti_matereq_html = join '',@mateReqhtml;
	
	#fetch all mate posts
	my @posts= ();
	foreach $mate (@mates) {
		my $postdir = "$users_dir/$mate/posts";
		my @userposts = glob("$postdir/*");
		foreach (@userposts) {
			$files{$mate}{$_}= 1;
		}
	}

	#print Dumper \%files;
	foreach $mate (keys %files) {
		foreach my $post (keys %{$files{$mate}}) {
			#try to open his post and make a post hash
			if(open(F, "<$post/post.txt")) {
				my $timeStamp = 0;
				my $message = 0;
		
				while (my $line = <F>) {
					#look for timestamp
					if($line =~ /^time=/) {
						chomp $line;
						(my $dateString = $line) =~ s/^time=//;
						$timeStamp = str2time($dateString);
					} elsif($line =~ /^message=/) {
						chomp $line;
						($message = $line) =~ s/^message=//;
						#sanitize this message
						$message =~ s/</&lt;/g;
						$message =~ s/>/&gt;/g;
						$message =~ s/\\n/<br>/g;
					}
				}
				close(F);
				#if we found the time and message in his posts, we hash it
				if($message && $timeStamp) {
					$message = convert_tags($message);
					$posts{$timeStamp}{$mate}{$message} = $post;
				}
			}
		}
	}
	
	my @html;
	#open up our disgusting hash to create html
	foreach my $timeStamp (reverse sort keys %posts) {
		foreach my $author (keys %{$posts{$timeStamp}}) {
			foreach my $message (keys %{$posts{$timeStamp}{$author}}) {
				my $commentCount = get_commentCount($posts{$timeStamp}{$author}{$message});
				my $postDir = $posts{$timeStamp}{$author}{$message};
				push @html, build_post_html($author, $names{$author}, $timeStamp, $message,$commentCount,$postDir);
			}
		}
	}
	$printHtml = join '',@html;
	
	my @matelist_html;
	# get html for mate names and profile pics
	foreach $mate (@mates) {
		push @matelist_html, build_matelist_html($mate, $names{$mate},$displayPics{$mate});
	}
		$matelist_html = join '',@matelist_html;
		#print Dumper \$matelist_html;exit;
    return <<eof
	<body>
      <section class="hbox stretch">
		<!-- .aside -->
		<aside class="bg-black dker aside-sm nav-vertical" id="nav">
		  <section class="vbox">
			<header class="bg-black nav-bar">
			  <a class="btn btn-link visible-xs" data-toggle="class:nav-off-screen" data-target="body">
				<i class="icon-reorder"></i>
			  </a>
			  <a href="#" class="dker nav-brand" data-toggle="fullscreen"><i class="icon-maxcdn"></i></a>
			  <a class="btn btn-link visible-xs" data-toggle="collapse" data-target=".navbar-collapse">
				<i class="icon-comment-alt"></i>
			  </a>
			</header>
			<section>
			  <!-- nav -->
			  <nav class="nav-primary hidden-xs">
				<ul class="nav">             
				  <li class="active">
					<a href="?action=timeline">
					  <i class="icon-time"></i>
					  <span>Timeline</span>
					</a>
				  </li>
				  <li>
					<a href="?action=discover">
					  <i class="icon-eye-open"></i>
					  <span>Discover</span>
					</a>
				  </li>
				</ul>
			  </nav>
			  <!-- / nav -->
			</section>
		  </section>
		</aside>
		<!-- /.aside -->
        <!-- .vbox -->
        <section id="content">
          <section class="vbox">
            <header class="header bg-black navbar navbar-inverse">
               <form class="navbar-form navbar-left m-t-sm" role="search">
				  <div class="form-group">
					<div class="input-group input-s">
					  <input type="text" name="search_users" class="form-control input-sm no-border bg-dark" placeholder="Search Users" required>
					  <span class="input-group-btn">
						<button type="submit" class="btn btn-sm btn-success btn-icon"><i class="icon-search"></i></button>
					  </span>
					</div>
				  </div>
				</form>
				<form class="navbar-form navbar-left m-t-sm" role="search_posts">
				  <div class="form-group">
					<div class="input-group input-s-xl">
					  <input type="text" name="search_posts" class="form-control input-sm no-border bg-dark" placeholder="Search Posts" required>
					  <span class="input-group-btn">
						<button type="submit" class="btn btn-sm btn-info btn-icon"><i class="icon-search"></i></button>
					  </span>
					</div>
				  </div>
				</form>
				<!-- top right menu -->
				<ul class="nav navbar-nav navbar-right">
				  <li class="hidden-xs">
					<a href="#" class="dropdown-toggle" data-toggle="dropdown">
					  <i class="icon-bell-alt text-white"></i>
					  <span class="badge up bg-info m-l-n-sm">$notifications</span>
					</a>
					<section class="dropdown-menu animated fadeInUp input-s-lg">
					  <section class="panel bg-white">
						<header class="panel-heading">
						  <strong>You have <span class="count-n">$notifications</span> notifications</strong>
						</header>
						<div class="list-group">
						  $noti_matereq_html
						</div>
					  </section>
					</section>
				  </li>
				  <li class="dropdown">
					<a href="#" class="dropdown-toggle" data-toggle="dropdown">
					  <span class="thumb-sm avatar pull-left m-t-n-xs m-r-xs">
						<img src="$profilepic">
					  </span>
					  $username <b class="caret"></b>
					</a>
					<ul class="dropdown-menu animated fadeInLeft">
					  <li>
						<a href="?action=settings">Settings</a>
					  </li>
					  <li>
						<a href="?action=profile">Profile</a>
					  </li>
					  <li>
						<a href="?action=logout">Logout</a>
					  </li>
					</ul>
				  </li>
				</ul>
				<!-- /top right menu -->
            </header>
            <section class="scrollable wrapper">
              <div class="row">
                <div class="col-lg-8">
                  <section class="panel">
                    <form>
                      <textarea class="form-control input-lg no-border" name ="new_post" rows="2" placeholder="What's up, $names{$username}?"></textarea>               
                    <footer class="panel-footer bg-light lter">
                      <button class="btn btn-info pull-right" type="submit">POST</button>
					</form>
                      <ul class="nav nav-pills">
                        <li><a href="#"><i class="icon-location-arrow"></i></a></li>
                        <li><a href="#"><i class="icon-camera"></i></a></li>
                        <li><a href="#"><i class="icon-facetime-video"></i></a></li>
                        <li><a href="#"><i class="icon-microphone"></i></a></li>
                      </ul>
                    </footer>
                  </section>
                  <div class="row">
                    $printHtml
                  </div>
                </div>
                <div class="col-lg-4">
					<section class="panel">
                      <h4 class="font-thin padder">My Mates</h4>
                      <ul class="list-group">
                        $matelist_html
                      </ul>
                    </section>			
                </div>
              </div>          
            </section>
          </section>
          <a href="#" class="hide nav-off-screen-block" data-toggle="class:nav-off-screen" data-target="body"></a>
        </section>
        <!-- /.vbox -->
      </section>
	    <script src="src/js/jquery.min.js"></script>
      <!-- Bootstrap -->
      <script src="src/js/bootstrap.js"></script>
      <!-- Sparkline Chart -->
      <script src="src/js/charts/sparkline/jquery.sparkline.min.js"></script>
      <!-- App -->
      <script src="src/js/app.js"></script>
      <script src="src/js/app.plugin.js"></script>
      <script src="src/js/app.data.js"></script>  

eof
}


1;
