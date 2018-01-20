#!/usr/bin/perl -w

use Date::Parse;
use Data::Dumper qw(Dumper);
use POSIX 'strftime';

sub get_user_posts {
	my ($username) = @_;
	
	#get the user's posts
	my @posts= ();
	my %posts;
	my $postdir = "$users_dir/$username/posts";
	my %names;
	my %files;
	my @userposts = glob("$postdir/*");
	
	foreach (@userposts) {
		$files{$_}= 1;
	}
	
	foreach $post (keys %files) {

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
				$posts{$timeStamp}{$message} = $post;
			}
		}
	}

	return %posts;
}

sub sendMateRequest {
	my ($userID) = @_;
	# go to his file and append a request at last line	
	my $file = "$users_dir/$userID/user.txt";
	
	# check if i have sent him a request before
	if(open(F, "<$file")) {
		while (my $line = <F>) {
			if ($line =~ /^matereq=$logged_in_user/) {
				close(F);
				# most likely user has sent a request before. just ignore
				print page_header(1);
				print get_profile($userID);
				exit;
			}
		}
		close(F);
	}
	
	open(F, ">>$file") || return 0;
	print F "matereq=$logged_in_user\n";
	close F;
	
	return 1;
}

sub cancelRequest {
	my($userID) = @_;

	#make sure there's a pending request lol
	if (pendingReq($userID) == 1) {
		#remove request	
		#remove him from my mate list
		my $file = "$users_dir/$userID/user.txt";
		my $tmpfile = "$file.new";
		open(F, "<$file") || return 0;
		open G, ">$tmpfile" or return 0;
		
		while (my $line = <F>) {
			next if($line =~ /^matereq=$logged_in_user/);
			print G $line;
		}
		close F;
		close G;
		rename("$tmpfile", $file) or return 0;
	} else {
		print page_header(1);
		print get_profile($userID);
		exit;
	}
	return 1;
}

sub unfriend {
	my ($userID) = @_;
	my $newMates;
	
	#user tried to be funny
	if (!isFriend($userID)) {
		print page_header(1);
		print notify("error", "User is not your mate.");
		print get_profile($userID);
		exit;
	}
	
	#remove him from my mate list
	my $file = "$users_dir/$logged_in_user/user.txt";
	my $tmpfile = "$file.new";
	open(F, "<$file") || return 0;
	open G, ">$tmpfile" or return 0;
	
	while (my $line = <F>) {
		if($line =~ /^mates=/) {
			my ($mates) = ($line =~ /^mates=\s*\[(.*)\]/);
			my @mates = split /, /,$mates;
			my @newMates;
			while (@mates) {
				my $mate = pop @mates;
				push @newMates, $mate if ($mate ne $userID); 
			}
			$newMates = join(", ", @newMates);
			$line = "mates=[$newMates]\n";
		} 
		print G $line;
	}
	close F;
	close G;
	rename("$tmpfile", $file) or return 0;
	
	#remove me from his mate list
	$file = "$users_dir/$userID/user.txt";
	$tmpfile = "$file.new";
	open(F, "<$file") || return 0;
	open G, ">$tmpfile" or return 0;
	
	while (my $line = <F>) {
		if($line =~ /^mates=/) {
			my ($mates) = ($line =~ /^mates=\s*\[(.*)\]/);
			my @mates = split /, /,$mates;
			my @newMates;
			while (@mates) {
				my $mate = pop @mates;
				push @newMates, $mate if ($mate ne $logged_in_user); 
			}
			$newMates = join(", ", @newMates);
			$line = "mates=[$newMates]\n";
		} 
		print G $line;
	}
	
	close F;
	close G;
	rename("$tmpfile", $file) or return 0;
	
	return 1;
}

sub acceptMateRequest {
	my ($reqSender, $reqReceiver) = @_;
	
	#make sure there's a correct friend request first
	if (pendingReq($reqSender) != 2) {
		print page_header(1);
		print notify("error", "No Friend request to accept");
		print get_profile($reqSender);
		exit;
	}
	#remove friend request & add mate into receiver side
	my $file = "$users_dir/$reqReceiver/user.txt";
	my $tmpfile = "$file.new";
	open(F, "<$file") || return 0;
	open G, ">$tmpfile" or return 0;
	
	while (my $line = <F>) {
		if($line =~ /^mates=/) {
			my ($mates) = ($line =~ /^mates=\s*\[(.*)\]/);
			my @mates = split /, /,$mates;
			push @mates, $reqSender;
			my $newMates = join(", ", @mates);
			$line = "mates=[$newMates]\n";
		} elsif ($line =~ /^matereq=$reqSender/) {
			next;
		}
		print G $line;
	}
	close F;
	close G;
	rename("$tmpfile", $file) or return 0;
	
	#add mate into sender side
	$file = "$users_dir/$reqSender/user.txt";
	$tmpfile = "$file.new";
	open(F, "<$file") || return 0;
	open G, ">$tmpfile" or return 0;
	
	while (my $line = <F>) {
		if($line =~ /^mates=/) {
			my ($mates) = ($line =~ /^mates=\s*\[(.*)\]/);
			my @mates = split /, /,$mates;
			push @mates, $reqReceiver;
			my $newMates = join(", ", @mates);
			$line = "mates=[$newMates]\n";
		}
		print G $line;
	}
	close F;
	close G;
	rename("$tmpfile", $file) or return 0;
	
	return 1;
	
}

sub deletePost {
	my ($postSrc) = @_;
	my ($userID) = $postSrc =~ /(z\d{7})/;
	return 0 if ($userID ne $logged_in_user);
	#just delete every file inside, it's much simpler than having to change all the names
	unlink glob "$postSrc/*" or return 0;
	return 1;
}

#this is only for the logged in user
sub getMateRequests {
	#no servicing non logged in ppl
	return if (!$logged_in_user);
	
	my $file = "$users_dir/$logged_in_user/user.txt";
	open(F, "<$file") || die ("Corrupted account file");
	
    my @mateReqs = grep /^matereq=/, <F>;
	close F;
	
	#trim all
	foreach my $mateReq(@mateReqs){
		chomp $mateReq;
		$mateReq =~ s/matereq=//;
	}
	
    return @mateReqs;
}

sub getUserLoc {
    my ($username) = @_;
    my $file = "$users_dir/$username/user.txt";
    open(F, "<$file") || die ("Corrupted account file");
    my @location = grep /^home_suburb=/, <F>;
    my $location = $location[0];
    $location =~ s/^home_suburb=//;
    chomp $location;
	close F;
    return $location;
}

sub build_user_posts_html {
	my ($userID, $username, $profilepic, $message, $commentCount, $timeStamp, $postDir, $masterMode) = @_;
	my $postdate = strftime '%a, %d %b %y', localtime $timeStamp;
	$postDir =~ /$users_dir\/z\d{7}\/posts\/(.*)/;
    # convert into tags
    $message = convert_tags($message);
	my $postID = $1;
	if ($masterMode) {
		$masterMode = <<eof
		<a href="?action=deletePost&src=$postDir"><i class="icon-trash" title="Delete Post"></i></a>
eof
		
	;}
	return<<eof
	<li class="list-group-item">
	  <a href="#" class="thumb-sm pull-left m-r-sm">
		<img src="$profilepic" class="img-circle">
	  </a>
	  <a href="#" class="clear">
		<small class="pull-right">$postdate  $masterMode</small>
		<strong class="block">$username</strong>
	  </a>
		<small>$message</small>  
	  <p>
		  <small class="pull-right">
				<a href="?action=post&a=$userID&b=pid$postID"><i class="icon-comment-alt"></i> Comments ($commentCount)</a>
		  </small>
	  </p>
	</li>
eof

}

sub build_user_comments_html {
	my ($userID, $username, $profilepic, $message, $postDir, $timeStamp) = @_;
	my $postdate = strftime '%a, %d %b %y', localtime $timeStamp;
	$postDir =~ /$users_dir\/z\d{7}\/posts\/(.*)/;
	my $postID = $1;
	return<<eof
	<li class="list-group-item">
	  <a href="?action=profile&profile_id=$userID" class="thumb-sm pull-left m-r-sm">
		<img src="$profilepic" class="img-circle">
	  </a>
	  <a href="?action=profile&profile_id=$userID" class="clear">
		<small class="pull-right">$postdate</small>
		<strong class="block">$username</strong>
	  </a>
		<small>$message</small> 
	  <p>
		  <small class="pull-right">
				<a href="?action=post&a=$userID&b=pid$postID"><i class="icon-comment-alt"></i> View Post</a>
		  </small>
	  </p>
	</li>
eof

}
sub getFriendButton {
	my($userID) = @_;
return <<eof
	
	<div class="btn-group" style="width:100%">
	  <button class="btn btn-success dropdown-toggle" style="width:100%" data-toggle="dropdown"><i class="icon-user-md"></i>Friends <span class="caret"></span></button>
	  <ul class="dropdown-menu">
		<li><a href="#">Block</a></li>
		<li class="divider"></li>
		<li><a href="?action=unfriend&id=$userID">Unfriend</a></li>
	  </ul>
	</div>
eof

}

sub getRequestButton {
	my($userID) = @_;
return<<eof
	<div class="btn-group btn-group-justified m-b">
	  <a class="btn btn-s-md btn-success " href="?action=reqfriend&id=$userID">
		  <i class="icon-user-md"></i> Send Mate Request
	  </a>  
	</div>
eof

}

sub getAcceptButton {
	my($userID) = @_;
return<<eof
	<div class="btn-group btn-group-justified m-b">
	  <a class="btn btn-s-md btn-success " href="?action=acceptfriend&id=$userID">
		  <i class="icon-user-md"></i> Accept Mate Request
	  </a>  
	</div>
eof

}

sub getRequestedButton {
	my($userID) = @_;
return <<eof
	
	<div class="btn-group" style="width:100%">
	  <button class="btn btn-success dropdown-toggle" style="width:100%" data-toggle="dropdown"><i class="icon-user-md"></i>Mate Request Sent <span class="caret"></span></button>
	  <ul class="dropdown-menu">
		<li><a href="?action=cancelreq&id=$userID">Cancel Request</a></li>
	  </ul>
	</div>
eof

}

sub isFriend {
	my ($userID) = @_;
	my @mates = get_user_mates($logged_in_user);
	
	for(@mates){
	  if( $userID eq $_ ){
		return 1;
	  }
	}
	return 0;
}

sub pendingReq {
	my ($userID) = @_;
	my $file = "$users_dir/$userID/user.txt";

	# check if i have sent him a request before
	if(open(F, "<$file")) {
		while (my $line = <F>) {
			if ($line =~ /^matereq=$logged_in_user/) {
				close(F);
				return 1;
			}
		}
		close(F);
	}
	
	#check if he sent me a request before
	$file = "$users_dir/$logged_in_user/user.txt";

	if(open(F, "<$file")) {
		while (my $line = <F>) {
			if ($line =~ /^matereq=$userID/) {
				close(F);
				return 2;
			}
		}
		close(F);
	}
	
	# no requests found
	return 0;
}

sub getUserInfo {
    my ($username) = @_;
    my $file = "$users_dir/$username/user.txt";
    open(F, "<$file") || die ("Corrupted account file");
    my @userInfo = grep /^user_info=/, <F>;
    my $userInfo = $userInfo[0];
    $userInfo =~ s/^user_info=//;
    chomp $userInfo;
	close F;
	
    return $userInfo;
}

sub getUserEmail {
    my ($username) = @_;
    my $file = "$users_dir/$username/user.txt";
    open(F, "<$file") || die ("Corrupted account file");
    my @email = grep /^email=/, <F>;
    my $email = $email[0];
    $email =~ s/^email=//;
    chomp $email;
	close F;
	
    return $email;
}

sub sanitise {
    my ($mode, $message) = @_;
    
    # default full cleaning
    $message =~ s/</&lt;/g;
    $message =~ s/>/&gt;/g;
    $message =~ s/"/&#34;/g;
    
    #sanitize this message for display
    if ($mode eq "half") {
        #allow a hrefs
	    $message =~ s/&lt;\s*(a\s*href=.*?)&gt;/<$1>/g;
	    $message =~ s/&lt;\s*\/a\s*&gt;/<\/a>/g;
	    #allow bold
	    $message =~ s/&lt;\s*b\s*&gt;/<b>/g;
	    $message =~ s/&lt;\s*\/b\s*&gt;/<\/b>/g;
	    #allow <br>
	    $message =~ s/&lt;\s*br\s*&gt;/<b>/g;
    }
	
	
	
    return $message;
}

sub handleUserInfoEdit {
    my $edit = param('User_Info_Edit') || '';			
			
    my $file = "$users_dir/$logged_in_user/user.txt";
    my $newLine = "user_info=$edit\n";
    
    # if user already has a user_info line
    if (getUserInfo($logged_in_user)) {   
	    my $tmpfile = "$file.new";
	    open(F, "<$file") || return 0;
	    open G, ">$tmpfile" or return 0;
	
	    while (my $line = <F>) {
		    if($line =~ /^user_info=/) {
			    $line = $newLine;
		    }
		    print G $line;
	    }
	    
	    close F;
	    close G;
	    rename("$tmpfile", $file) or return 0;    
    } else {
        open G, ">>$file" or return 0;
        print G $newLine;
    }
    
    return 1;
}

sub get_profile {
	my ($username) = @_;
    if (isSuspended($username)) {
        print "Error 404: nothing here.";
        print page_trailer();
        exit;
    }
	my $masterMode = 0;
	my $myButton;
	my $editInfoButton;
	my $pendingRequestState = pendingReq($username);
	
	if ($username eq $logged_in_user) {
		$masterMode = 1;
		$editInfoButton = "<a href=\"#\" data-target=\"#edit_info\" data-toggle=\"modal\"><i class=\"icon-edit\" title=\"Edit Info\"></i></a>";
	} elsif (isFriend($username)) {
		$myButton = getFriendButton($username);
	} elsif ($pendingRequestState) {
		$myButton = getRequestedButton($username) if ($pendingRequestState == 1);
		$myButton = getAcceptButton($username) if ($pendingRequestState == 2);
	} else {
		$myButton = getRequestButton($username);
	}
	
	my $profilepic = get_avatar_link($username);
	my $logged_in_user_dp = get_avatar_link($logged_in_user);
	$names{$username} = zIDtoName($username);
	my $userLoc = getUserLoc($username);
	my $userInfo = getUserInfo($username);
	my @user_mates = get_user_mates($username);
	$userLoc = "No Location Shared" if (!$userLoc);
	
	# handle empty user info and backslash double quotes
    $userInfo = "No Info Provided" if (!$userInfo);
    
    #handle html cleaning
    $userInfo = sanitise("half", $userInfo);
	$userInfoSanitized = sanitise("full", $userInfo);
	
	#check user notifications
	#get mate requests
	my $notifications = "0";
	my @mateReqs = getMateRequests();
	my @mateReqhtml;
	my $noti_matereq_html;
	
	# add mate requests as notifications
	$notifications += scalar @mateReqs;
	
	foreach my $mateReq (@mateReqs) {
		push @mateReqhtml, get_matereq_html($mateReq);
	}
	$noti_matereq_html = join '',@mateReqhtml;
	
	
	#handle mate list
	foreach $mate (@user_mates) {
		# grab their names and hash it
		$names{$mate} = zIDtoName($mate) if(!exists $names{$mate});
		$displayPics{$mate} = get_avatar_link($mate) if(!exists $displayPics{$mate});
	}
	
	my @matelist_html;
	# get html for mate names and profile pics
	foreach $mate (@user_mates) {
		push @matelist_html, build_matelist_html($mate, $names{$mate},$displayPics{$mate});
	}
	my $matelist_html = join '',@matelist_html;
			
	#fetch my posts and interactions
	my %posts = get_user_posts($username);
	my %tagged_posts = search_posts($username);
	my %tagged_comments = search_comments($username);
	
	my @post_html;
	my @tagged_posts_html;
	my @tagged_comments_html;
	
	foreach my $timeStamp(reverse sort keys %posts) {
		foreach my $message (keys %{$posts{$timeStamp}}) {
			my $commentCount = get_commentCount($posts{$timeStamp}{$message});
			push @post_html, build_user_posts_html($username, $names{$username}, $profilepic, $message, $commentCount, $timeStamp, $posts{$timeStamp}{$message}, $masterMode);
		}
	}
	my $user_posts_html = join '', @post_html;
	
	#create tagged posts html
	foreach my $timeStamp (reverse sort keys %tagged_posts) {
		foreach my $author (keys %{$tagged_posts{$timeStamp}}) {
			$names{$author} = zIDtoName($author) if(!exists $names{$author});
			foreach my $message (keys %{$tagged_posts{$timeStamp}{$author}}) {
				my $commentCount = get_commentCount($tagged_posts{$timeStamp}{$author}{$message});
				my $postDir = $tagged_posts{$timeStamp}{$author}{$message};
				push @tagged_posts_html, build_user_posts_html($author, $names{$author}, get_avatar_link($author), $message, $commentCount, $timeStamp,$postDir);
			}
		}
	}

	my $tagged_posts_html = join '',@tagged_posts_html;	
	$tagged_posts_html = "User hasn't been tagged in any posts" if (!$tagged_posts_html);
	
	#create tagged comments html
	foreach my $timeStamp (reverse sort keys %tagged_comments) {
		foreach my $author (keys %{$tagged_comments{$timeStamp}}) {
			$names{$author} = zIDtoName($author) if(!exists $names{$author});
			foreach my $message (keys %{$tagged_comments{$timeStamp}{$author}}) {
				my $oriPost = $tagged_comments{$timeStamp}{$author}{$message};
				push @tagged_comments_html, build_user_comments_html($author, $names{$author}, get_avatar_link($author), $message, $oriPost, $timeStamp);
			}
		}
	}
	
	my $tagged_comments_html = join '',@tagged_comments_html;	
	$tagged_comments_html = "User hasn't been tagged in any comments" if (!$tagged_comments_html);
	
    #privacy controls and masking (not efficient but i have no more time)    
    if (!$masterMode && !isFriend($username)) {
        $matelist_html = "<h6 class=\"font-thin padder\">User has chosen to keep this private.</h6>" if (isPrivate($username, "mates"));
        $user_posts_html = "<h6 class=\"font-thin padder\">User has chosen to keep this private.</h6>" if (isPrivate($username, "posts"));
        if (isPrivate($username, "interactions")) {
            $tagged_comments_html = "<h6 class=\"font-thin padder\">User has chosen to keep this private.</h6>";
            $tagged_posts_html = "<h6 class=\"font-thin padder\">User has chosen to keep this private.</h6>";
        }
        $userLoc = "Private Info" if (isPrivate($username, "location"));
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
						<img src="$logged_in_user_dp">
					  </span>
					  $logged_in_user<b class="caret"></b>
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
			<section class="scrollable">
			  <section class="hbox stretch">
				<aside class="aside-lg bg-light lter b-r">
				  <section class="vbox">
					<section class="scrollable">
					  <div class="wrapper">
						<div class="clearfix m-b">
						  <a href="#" class="pull-left thumb m-r">
							<img src="$profilepic" class="img-circle"></img>
						  </a>
						  <div class="clear">
							<div class="h3 m-t-xs m-b-xs">$names{$username}</div>
							<small class="text-muted"><i class="icon-map-marker"></i> $userLoc</small>
						  </div>                
						</div>
						<div>
						  <small class="text-uc text-xs text-muted">about me</small>
						  $editInfoButton
						  <p>$userInfo</p>
						  <div class="line"></div>
						</div>
						$myButton
					  </div>
					</section>
				  </section>
				</aside>
				<aside class="bg-white">
				  <section class="vbox">
					<header class="header bg-light bg-gradient">
					  <ul class="nav nav-tabs nav-white">
						<li class="active"><a href="#posts" data-toggle="tab">Posts</a></li>
						<li class=""><a href="#interaction" data-toggle="tab">Interaction</a></li>
					  </ul>
					</header>
					<section class="scrollable">
					  <div class="tab-content">
						<div class="tab-pane active" id="posts">
						  <ul class="list-group no-radius m-b-none m-t-n-xxs list-group-lg no-border">
							$user_posts_html
						  </ul>
						</div>
						<div class="tab-pane" id="interaction">
							<section class="panel">
							  <header class="panel-heading">                    
								<span class="label bg-dark">Posts</span>
							  </header>
							  <section class="panel-body slim-scroll">
								<ul class="list-group no-radius m-b-none m-t-n-xxs list-group-lg">
									$tagged_posts_html
								</ul>
							  </section>
							</section>
							<section class="panel">
							  <header class="panel-heading">                    
								<span class="label bg-dark">Comments</span>
							  </header>
							  <section class="panel-body slim-scroll">
								<ul class="list-group no-radius m-b-none m-t-n-xxs list-group-lg">
									$tagged_comments_html
								</ul>
							  </section>
						</div>
					  </div>
					</section>
				  </section>
				</aside>
				<aside class="col-lg-4 b-l">
				  <section class="vbox">
					<section class="scrollable">
					  <div class="wrapper">
						<section class="panel">
						  <form>
							<textarea class="form-control no-border" rows="5" placeholder="Post a comment on $names{$username}'s wall"></textarea>
						  </form>
						  <footer class="panel-footer bg-light lter">
							<button class="btn btn-info pull-right btn-sm">POST</button>
							<ul class="nav nav-pills nav-sm">
							  <li><a href="#"><i class="icon-camera"></i></a></li>
							  <li><a href="#"><i class="icon-facetime-video"></i></a></li>
							</ul>
						  </footer>
						</section>
						<section class="panel">
							<h4 class="font-thin padder">Mates</h4>
							  <ul class="list-group">
								$matelist_html
							  </ul>	
						</section>
					  </div>
					</section>
				  </section>              
				</aside>
			  </section>
			</section>
		  </section>
		  <a href="#" class="hide nav-off-screen-block" data-toggle="class:nav-off-screen" data-target="body"></a>
		</section>
		<!-- /.vbox -->
	  </section>
	  <!-- Modal for edit profile -->
	   <div id="edit_info" class="modal fade" >
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-body">
              <div class="row">
                <div class="col-sm-12">
                  <form role="form" method="POST">
                    <div class="form-group">
                      <label>Edit your Profile Text</label>
                      <small class="text-xs text-muted"> - Allowed HTML tags: &lt;a href&gt;,&lt;b&gt;,&lt;br&gt;</small>
                      <input type="text" class="form-control" name="User_Info_Edit" value="$userInfoSanitized">
                    </div>
                    <div class="form-group">
                      <button type="submit" class="btn btn-sm btn-success pull-right text-uc m-t-n-xs"><strong>Edit</strong></button>              
                  </form>
                </div>
              </div>          
            </div>
          </div><!-- /.modal-content -->
        </div><!-- /.modal-dialog -->
      </div>
      <!-- end modal -->
	  <script src="src/js/jquery.min.js"></script>
      <!-- Bootstrap -->
      <script src="src/js/bootstrap.js"></script>
      <!-- app -->
      <script src="src/js/app.js"></script>
      <script src="src/js/app.plugin.js"></script>
      <script src="src/js/app.data.js"></script>
      <!-- wysiwyg -->
      <script src="src/js/wysiwyg/jquery.hotkeys.js" cache="false"></script>
      <script src="src/js/wysiwyg/bootstrap-wysiwyg.js" cache="false"></script>
      <script src="src/js/wysiwyg/demo.js" cache="false"></script>
eof
}

1;
