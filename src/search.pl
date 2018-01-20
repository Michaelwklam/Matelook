#!/usr/bin/perl -w

use Data::Dumper qw(Dumper);
use Date::Parse;
use POSIX 'strftime';

sub build_search_users_html {
	my ($userID, $name) = @_;
	my $avatar = get_avatar_link($userID);
	my @userMates = get_user_mates($userID);
	my $mateCount = scalar @userMates;
	my $postCount = get_user_postCount($userID);
	
	return<<eof
	<div class="col-lg-12">
		<section class="panel clearfix">
			<div class="panel-body">
			  <a href="?action=profile&profile_id=$userID" class="thumb pull-left m-r">
				<img src="$avatar" class="img-circle">
			  </a>
			  <div class="clear">
				<a href="?action=profile&profile_id=$userID" class="text-info">$name</a>
				<small class="block text-muted">$mateCount mates / $postCount posts</small>
				<a href="?action=profile&profile_id=$userID" class="btn btn-xs btn-success m-t-xs">Follow</a>
			  </div>
			</div>
		</section>
	</div>
eof
}

sub get_user_postCount {
	my ($username) = @_;
	
	my $postdir = "$users_dir/$username/posts";
	my @userposts = glob("$postdir/*");

	return scalar @userposts;
}

sub search_comments {
	my ($searchTerm) = @_;
	
	my @users = glob("$users_dir/*");
	my %foundComments;

	#user level
	foreach my $user (@users) {
		my $postdir = "$user/posts";
		my @userposts = glob("$postdir/*");
		
		#post level
		foreach my $post(@userposts) {
			my $commentdir = "$post/comments";
			my @usercomments = glob("$commentdir/*");
			
			#comment level
			foreach my $comment (@usercomments) {
				if(open(F, "<$comment/comment.txt")) {
			
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
					#if we found the time and message in his posts, we check if message
					#contains user's search term
					
					if(($message && $timeStamp) && $message =~ /$searchTerm/i) {
						# extract userID
						(my $userID) = $user =~ /(z\d{7})/i;
						# convert zID tags to real nametags
						$message = convert_tags($message);
						$foundComments{$timeStamp}{$userID}{$message} = $post;
					}
				
				}
							
			}
		}
	}

	if (%foundComments) {
		return %foundComments;
	} else {
		return -1;
	}
}

sub convert_tags {

	my ($message) = @_;
	my (@tags) = ($message =~ /(z\d{7})/g);
	
	#use global hash to improve timing
	foreach my $tag (@tags) {
		$names{$tag} = zIDtoName($tag) if(!exists $names{$tag});
	}
	
	$message =~ s/(z\d{7})/<a href="?action=profile&profile_id=$1">\@$names{$1}<\/a>/g if (@tags);
	return $message;
}
	
sub search_posts {
	my ($searchTerm) = @_;
	
	if (!$searchTerm) {
		$searchTerm = param('search_posts') || '';
	}
	
	my @users = glob("$users_dir/*");
	my %foundPosts;

	foreach my $user (@users) {
		my $postdir = "$user/posts";
		my @userposts = glob("$postdir/*");
		
		foreach my $post(@userposts) {
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
				#if we found the time and message in his posts, we check if message
				#contains user's search term
				
				if(($message && $timeStamp) && $message =~ /$searchTerm/i) {
					# extract userID
					(my $userID) = $user =~ /(z\d{7})/i;
					$message = convert_tags($message);
					$foundPosts{$timeStamp}{$userID}{$message} = $post;
				}
			}
		}
	}

	if (%foundPosts) {
		return %foundPosts;
	} else {
		return -1;
	}
}

sub search_users {

	my $searchTerm = param('search_users') || '';
	my @users = glob("$users_dir/*");
	my %foundUsers;
	
	foreach my $user (@users) {
		if(open(F, "<$user/user.txt")) {
			my @fullname = grep /full_name=/, <F>;
			my $fullname = $fullname[0];
			$fullname =~ s/^full_name=//;
			chomp $fullname;
			if($fullname =~ /$searchTerm/i) {
				#get his id
				(my $userID = $user) =~ s/$users_dir\///;
                if (!isSuspended($userID)) {
                    $foundUsers{$userID} = $fullname;
                }
			}
			close(F);
		}
	}
	
	if (%foundUsers) {
		return %foundUsers;
	} else {
		return -1;
	}
}

sub get_search_results {
	my ($username, $searchType, %searchHash) = @_;

	my @html;
	my $printHtml;
	my %names;
	my $profilepic = get_avatar_link($logged_in_user);
	
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
	
	if ($searchType eq "user") {
		if (exists $searchHash{'-1'}) {
			$printHtml = <<eof
				<div class="col-lg-12">
					<div class="alert alert-danger">
					<button type="button" class="close" data-dismiss="alert"><i class="icon-remove"></i></button>
					<i class="icon-ban-circle"></i><strong>Oh snap!</strong> Didn't find any user with that name. Try another search, perhaps?
					</div>
				</div>
eof
		} else {
		
			foreach $userID (keys %searchHash) {
				push @html, build_search_users_html($userID, $searchHash{$userID});
			}
			$printHtml = join '',@html;
		}	

	} elsif ($searchType eq "post") {
	
		if (exists $searchHash{'-1'}) {
			$printHtml = <<eof
				<div class="col-lg-12">
					<div class="alert alert-danger">
					<button type="button" class="close" data-dismiss="alert"><i class="icon-remove"></i></button>
					<i class="icon-ban-circle"></i><strong>Oh snap!</strong> Didn't find any posts looking like what you asked for. Try another search, perhaps?
					</div>
				</div>
eof
		} else {
			#open up our disgusting hash to create html
			foreach my $timeStamp (reverse sort keys %searchHash) {
				foreach my $author (keys %{$searchHash{$timeStamp}}) {
					$names{$author} = zIDtoName($author) if(!exists $names{$author});
					foreach my $message (keys %{$searchHash{$timeStamp}{$author}}) {
						my $commentCount = get_commentCount($searchHash{$timeStamp}{$author}{$message});
						my $postDir = $searchHash{$timeStamp}{$author}{$message};
						push @html, build_post_html($author, $names{$author}, $timeStamp, $message, $commentCount,$postDir);
					}
				}
			}

			$printHtml = join '',@html;	
		}	
		
	}
	
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
				  <li>
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
				<h4>Search Results</h4>
              <div class="row">
                <div class="col-lg-8">
                  <div class="row">
                    $printHtml
                  </div>
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
