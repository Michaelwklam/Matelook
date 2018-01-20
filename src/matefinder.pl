#!/usr/bin/perl -w

use Data::Dumper qw(Dumper);
use Date::Parse;
use POSIX 'strftime';
use POSIX;
$pi = atan2(1,1) * 4;

sub get_Courses {
	my ($userID) = @_;
	my $file = "$users_dir/$userID/user.txt";
	open(F, "<$file") || return;
	my @courseline = grep /^courses=/, <F>;
	close(F);
	my $courseline = $courseline[0];
	
	#trim and split etc
	$courseline =~ s/^courses=\[(.*?)\]//;
	my $courses = $1;
	my @courses = split /, /,$courses;

	return @courses;
}

sub compareMyCoursesWithAll {
	my ($userID) = @_;
	
	my @mycourses = get_Courses($userID);
	my @allusers = glob("$users_dir/*");
	my @mymates = get_user_mates($userID);
	my %usersWithSameCourses;
	my $user;
	foreach $user (@allusers) {
		$user =~ s/$users_dir\///;
		chomp $user;
		#don't compare with ourself	
		next if ($user eq $userID);
		next if (inList($user, @mymates));
		my @userCourses = get_Courses($user);
		my $similarCourses = compareCourses(\@mycourses, \@userCourses);
		$usersWithSameCourses{$user} = $similarCourses;
	}
	return %usersWithSameCourses;
}

sub compareCourses {
	my ($set1_ref, $set2_ref) = @_;
	my @courses = @{ $set1_ref };   
    my @compareAgainst = @{ $set2_ref };
	my $similarCourses = "0";

	foreach my $course (@courses) {
		if (inList($course, @compareAgainst)) {
			$similarCourses++;
		}
	}
	return $similarCourses;
}

sub inList {
	my ($item, @list) = @_;

	for(@list){
	  if( $item eq $_ ){
		return 1;
	  }
	}
	return 0;
}
	
sub getUserCoord {
	my ($userID) = @_;
	my $file = "$users_dir/$userID/user.txt";
	my $lat = 0;
	my $long = 0;
	my %coordinate;
	# check if i have sent him a request before
	if(open(F, "<$file")) {
		while (my $line = <F>) {
			if ($line =~ /^home_latitude=/) {
				$lat = $line;
				$lat =~ s/^home_latitude=//;
				chomp $lat;
			} elsif ($line =~ /^home_longitude=/) {
				$long = $line;
				$long =~ s/^home_longitude=//;
				chomp $long;
			}
		}
		close(F);
	}
	if ($lat && $long) {
		$coordinate{'lat'} = $lat;
		$coordinate{'long'} = $long;
		return %coordinate;
	} else {
		return;
	}
}

sub compareDistanceWithAll{
	my ($userID) = @_;
	my %myCoord = getUserCoord($userID);
	my @mymates = get_user_mates($userID);
	# no point continuing if user doesn't even have coordinates
	return if(!exists $myCoord{'lat'} || !exists $myCoord{'long'});
	my @allusers = glob("$users_dir/*");
	my %user_distances;
	my $user;
	foreach $user (@allusers) {
		$user =~ s/$users_dir\///;
		chomp $user;
		next if ($user eq $userID);
		next if (inList($user, @mymates));
		my %userCoord = getUserCoord($user);
		if(exists $userCoord{'lat'} && exists $userCoord{'long'}) {		
			$user_distances{$user} = distance($myCoord{'lat'},$myCoord{'long'}, $userCoord{'lat'}, $userCoord{'long'}, "K");
		}
	}
	return %user_distances;
}

sub compareLocationWithAll {
	my ($userID) = @_;
	my $myLoc = getUserLoc($userID);
	my @mymates = get_user_mates($userID);
	
	my @allusers = glob("$users_dir/*");
	my %users_home_suburb_matching;
	my $user;
	foreach $user (@allusers) {
		$user =~ s/$users_dir\///;
		chomp $user;
		next if ($user eq $userID);
		next if (inList($user, @mymates));
		my $userLoc = getUserLoc($user);
		if ($myLoc eq $userLoc) {
			$users_home_suburb_matching{$user} = '1';
		} else {
			$users_home_suburb_matching{$user} = "0";
		}	
	}
	return %users_home_suburb_matching;
}

sub getMutualFriends {
	my ($user1ID, $user2ID) = @_;
	my @u1mates = get_user_mates($user1ID);
	my @u2mates = get_user_mates($user2ID);
	#reuse function - doesn't matter.
	my $mutualfriends = compareCourses(\@u1mates, \@u2mates);
	
	return $mutualfriends;
}

sub compareMutualFriendsWithAll {
	my ($userID) = @_;
	my @mymates = get_user_mates($userID);
	
	my @allusers = glob("$users_dir/*");
	my %mutual_friends;
	my $user;
	foreach $user (@allusers) {
		$user =~ s/$users_dir\///;
		chomp $user;
		next if ($user eq $userID);
		next if (inList($user, @mymates));
		my @usermates = get_user_mates($user);
		# reuse function. lazy to do renaming
		my $mutualfriends = compareCourses(\@mymates, \@usermates);
		$mutual_friends{$user} = $mutualfriends;
	}
	return %mutual_friends;
}

sub build_materec_html {
	my($userID) = @_;
	my $name = zIDtoName($userID);
	my $avatar = get_avatar_link($userID);
	my @userMates = get_user_mates($userID);
	my $mateCount = scalar @userMates;
	my $postCount = get_user_postCount($userID);
	my $mutualFriends = getMutualFriends($logged_in_user, $userID);
	
	return<<eof
	<div class="col-sm-3">
		<section class="panel clearfix">
			<div class="panel-body">
			  <a href="?action=profile&profile_id=$userID" class="thumb pull-left m-r">
				<img src="$avatar" class="img-circle">
			  </a>
			  <div class="clear">
				<a href="?action=profile&profile_id=$userID" class="text-info">$name</a>
				<small class="block text-muted">$mateCount mates / $mutualFriends common</small>
				<small class="block text-muted">$postCount posts</small>
			  </div>
			</div>
		</section>
	</div>
eof

}

sub suggest_Mates {
	my ($userID) = @_;
	
	#compare user's courses with everyone else
	#Same courses = priority/best Ranked
	my %numSimilarCourses = compareMyCoursesWithAll($userID);
	my %sameSuburb = compareLocationWithAll($userID);
	my %distances = compareDistanceWithAll($userID);
	my %mutual_friends = compareMutualFriendsWithAll($userID);
	my %mateScore;

	# very simple algorithm that values mutual friends and mutual courses more
	#compute score for users - use keys from mutual friends since it should cover all users
	#Same course - 3 points per course
	#same suburb - 1 point
	#distance < 2 - 3 points
	#distance < 5 - 2 points
	#distance < 10 - 1 point
	#mutual friends 3 points per friends
	
	foreach my $mate (keys %mutual_friends) {
		$mateScore{$mate} += $numSimilarCourses{$mate} * 3 if (exists $numSimilarCourses{$mate});
		$mateScore{$mate} += $sameSuburb{$mate} if (exists $sameSuburb{$mate});
		
		if (exists $distances{$mate}) {
			if ($distances{$mate} < 2) {
				$mateScore{$mate} += 3; 
			} elsif ($distances{$mate} < 5) {
				$mateScore{$mate} += 2; 
			} elsif ($distances{$mate} < 10) {
				$mateScore{$mate} += 1; 
			}
		}
		$mateScore{$mate} += $mutual_friends{$mate} * 3 if (exists $mutual_friends{$mate});
	}
	
	#sort from highest to lowest and push into a list
	my @mateRec;
	foreach my $user (sort {$mateScore{$b} <=> $mateScore{$a}} keys %mateScore) {
		push @mateRec, $user;
    }
	
	return @mateRec;
}

sub getDiscover {
	my ($userID) = @_;
	
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
	
	# build mate recommendations html
	my @mateRec = suggest_Mates($userID);
	my @mateRecHtml;
	my $mateRec_html;
	foreach my $user (@mateRec) {
		push @mateRecHtml, build_materec_html($user);
	}
	$mateRec_html = join '',@mateRecHtml;	
	
	if (!$mateRec_html) {
		$mateRec_html = <<eof
		<div class="col-lg-6 col-sm-6">
			<h5>Wow it seems like you're friends with everyone. Good on you, Mr popular!</h5>
		</div>
eof
		;
	}
	return<<eof
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
				  <li class="active">
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
				<h4>People You might know</h4>
              <div class="row">
                $mateRec_html
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

# Lat & long calculator found here
# http://www.geodatasource.com/developers/perl
sub distance {
	my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;
	my $theta = $lon1 - $lon2;
	my $dist = sin(deg2rad($lat1)) * sin(deg2rad($lat2)) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
	  $dist  = acos($dist);
	  $dist = rad2deg($dist);
	  $dist = $dist * 60 * 1.1515;
	  if ($unit eq "K") {
		$dist = $dist * 1.609344;
	  } elsif ($unit eq "N") {
		$dist = $dist * 0.8684;
	  }
	return ($dist);
}
 
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function get the arccos function using arctan function   :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub acos {
	my ($rad) = @_;
	my $ret = atan2(sqrt(1 - $rad**2), $rad);
	return $ret;
}
 
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function converts decimal degrees to radians             :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub deg2rad {
	my ($deg) = @_;
	return ($deg * $pi / 180);
}
 
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::  This function converts radians to decimal degrees             :::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sub rad2deg {
	my ($rad) = @_;
	return ($rad * 180 / $pi);
}

1;
