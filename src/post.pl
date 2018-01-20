 #!/usr/bin/perl -w

use Date::Parse;
use Data::Dumper qw(Dumper);
use POSIX 'strftime';

sub fetch_comments {
	my ($postDir) = @_;
	my @comments = glob("$postDir/comments/*");
	my %comments;
	
	foreach my $commentSrc (@comments) {
		if(open(F, "<$commentSrc/comment.txt")) {
			my $timeStamp = 0;
			my $message = 0;
			my $from = 0;
			
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
				} elsif($line =~ /^from=/) {
					chomp $line;
					($from = $line) =~ s/^from=//;
				}
			}
			close(F);
			
			if($message && $timeStamp && $from) {
				# convert zID tags to real nametags
				$message = convert_tags($message);
				$comments{$timeStamp}{$from}{$commentSrc} = $message;
			}
		}
	}
	if (%comments) {
		return %comments;
	} else {
		return -1;
	}
}

sub deleteReply {
	my ($postSrc) = @_;	
    $postSrc .= "/reply.txt";
    
    my $tmpfile = "$postSrc.new";
    open(F, "<$postSrc") || return 0;
    open G, ">$tmpfile" or return 0;

    while (my $line = <F>) { 
        if ($line =~ /^from=(.*?)$/) {
            if ($logged_in_user !~ /\Q$1/) { #someone trying to be funny
                close F;
                close G;
                return 0;
            }
        } elsif($line =~ /^message=/) {
            $line = "message=[Reply has been deleted by user]\n";
        }
        print G $line;
    }
    
    close F;
    close G;
    rename("$tmpfile", $postSrc) or return 0; 
    
	return 1;
}

sub deleteComment {
	my ($postSrc) = @_;	
    $postSrc .= "/comment.txt";
    
    my $tmpfile = "$postSrc.new";
    open(F, "<$postSrc") || return 0;
    open G, ">$tmpfile" or return 0;

    while (my $line = <F>) { 
        if ($line =~ /^from=(.*?)$/) {
            if ($logged_in_user !~ /\Q$1/) { #someone trying to be funny
                close F;
                close G;
                return 0;
            }
        } elsif($line =~ /^message=/) {
            $line = "message=[comment has been deleted by user]\n";
        }
        print G $line;
    }
    
    close F;
    close G;
    rename("$tmpfile", $postSrc) or return 0; 
    
	return 1;
}

sub build_comments_reply_html {
	my ($timeStamp,$message,$author, $src) = @_;
	my $avatar = get_avatar_link($author);
	my $name = zIDtoName($author);
	my $postdate = strftime '%a, %d %b %y', localtime $timeStamp;
    my $master;
    
    #if post belongs to logged in user, mastermode gives delete button
    if ($author eq $logged_in_user && "deleted by user]" !~ /\Q$message/) {
        $master = "<a href=\"?action=deleteReply&src=$src\"><i class=\"icon-trash\" title=\"Delete Reply\"></i></a>";
    }
    
    #use global counter
    $commentReplies++;
    
	return<<eof
	<article id="comment-id-2" class="comment-item comment-reply">
	  <a class="pull-left thumb-sm" href="?action=profile&profile_id=$author">
		<img src="$avatar" class="img-rounded">
	  </a>
	  <section class="comment-body m-b">
		<header>
		  <a href="?action=profile&profile_id=$author"><strong>$name</strong></a>
		  <span class="text-muted text-xs block m-t-xs">$postdate $master</span> 
		</header>
		<div class="m-t-sm">$message</div>
	  </section>
	</article>
eof

}


sub build_comments_html {
	my ($timeStamp,$message,$author, $ori_author, $ori_ID, $commentSrc) = @_;
	my $avatar = get_avatar_link($author);
	my $name = zIDtoName($author);
	my $postdate = strftime '%a, %d %b %y', localtime $timeStamp;
	my $master;
    #if post belongs to logged in user, mastermode gives delete button
    if ($author eq $logged_in_user && "deleted by user]" !~ /\Q$message/) {
        $master = "<a href=\"?action=deleteComment&src=$commentSrc\"><i class=\"icon-trash\" title=\"Delete Comment\"></i></a>";
    }
	#fetch all the comment replies
	my $commentReplies_html;
	my @commentReplies = glob("$commentSrc/replies/*");
	my @html;
	my %commentreplies;
	my %commentreply_Src;
    
	foreach my $commentReplySrc (@commentReplies) {
		if(open(F, "<$commentReplySrc/reply.txt")) {
			my $timeStamp = 0;
			my $message = 0;
			my $from = 0;
			
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
				} elsif($line =~ /^from=/) {
					chomp $line;
					($from = $line) =~ s/^from=//;
				}
			}
			close(F);
			
			if($message && $timeStamp && $from) {
				# convert zID tags to real nametags
				$message = convert_tags($message);
				$commentreplies{$timeStamp}{$from} = $message;
                $commentreply_Src{$timeStamp}{$from} = $commentReplySrc;
			}
		}
	}
    
	#open up comments hash 
	foreach my $timeStamp (sort keys %commentreplies) {
		foreach my $author (keys %{$commentreplies{$timeStamp}}) {
			push @html, build_comments_reply_html($timeStamp, $commentreplies{$timeStamp}{$author}, $author, $commentreply_Src{$timeStamp}{$author});		
		}
	}
	$commentReplies_html = join '',@html;
	
	return<<eof

	<article id="comment-id-1" class="comment-item">
	  <a class="pull-left thumb-sm" href="?action=profile&profile_id=$author">
		<img src="$avatar" class="img-rounded">
	  </a>
	  <section class="comment-body m-b">
		<header>
		  <a href="?action=profile&profile_id=$author"><strong>$name</strong></a>
		  <span class="text-muted text-xs m-t-xs"> $postdate</span> 
		</header>
		<div class="m-t-sm">$message</div>
		<div>
			<a id="reply$commentSrc" href="javascript:toggle('form$commentSrc','reply$commentSrc');" ><i class="icon-mail-reply"></i>Reply</a>
            $master
		</div> 
	  </section>
	</article>
	<div id ="form$commentSrc" style="display: none;">
		<article id="comment-id-2" class="comment-item comment-reply">
		  <a class="pull-left thumb-sm" href="?action=profile&profile_id=$logged_in_user">
			<img src="$logged_in_user_dp" class="img-rounded">
		  </a>
		  <section class="comment-body m-b">
			<header>
			  <a href="?action=profile&profile_id=$author"><strong>Me</strong></a>
			</header>
				<form class="input-group" method="post">
					<input type="text" name="reply_comment" style="width: 500px;" class="form-control" placeholder="Reply $name">
					<input type="hidden" name="src" value="$commentSrc">
					<input type="hidden" name="post_a" value="$ori_author">
					<input type="hidden" name="post_b" value="pid$ori_ID">
				</form>
		  </section>
		</article>
	</div>
	$commentReplies_html
eof

}

sub reply_comment {
	my ($commentSrc, $reply) = @_;
	print page_header(1);
	
	my $replyDir = "$commentSrc/replies";
	my $newReplynum;
	
    my ($author, $postID) = $commentSrc =~ /(z\d{7})\/posts\/(\d?)/;

    # handle notifications
    notify_tags($reply,"email_reply", $author, $postID);
    
	my @replies = glob("$commentSrc/replies/*");

	# in case there's no replies, make sure to make a new directory
	if(!@replies) {
		mkdir $replyDir unless -d $replyDir;
		$newReplynum = "0";
	} else {
		foreach (@replies) {
			$_ =~ s/.*?replies\///;
		}
		$newReplynum = $replies[$#replies] + 1;
	}	
	
	my $newReplyDir = "$replyDir/$newReplynum";
	if (-d $newReplyDir) {
		return 0;
	} else {
		mkdir $newReplyDir;
	}
	
	open my $fileHandle, ">>", "$newReplyDir/reply.txt" or return 0;
	
	# add message to the new file	
	
	my $now = time();
	my $tz = strftime("%z", localtime($now));
	$tz =~ s/(\d{2})(\d{2})/$1:$2/;
	
	# make ISO8601 timestamp
	
	my $currentTimestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz . "\n";
	
	my $fileprint = "time=$currentTimestamp\n";
	$fileprint .= "from=$logged_in_user\n";
	$fileprint .= "message=$reply\n";
	print $fileHandle $fileprint;
	close $fileHandle;
	
	return 1;

}

sub notify_tags {

	my ($message, $post_type, $linkauthor, $linkID) = @_;
	my (@tags) = ($message =~ /(z\d{7})/g);
	
	#use global hash to improve timing
	foreach my $tag (@tags) {
		if (isNotifyOn($tag,$post_type)) {
            #email him  
            sendNotificationMail($tag,$linkauthor, $linkID);
        }
	}
	
	return;
}

sub sendNotificationMail {
    my ($zID,$postAuthor, $postID) = @_;
    my $to = getUserEmail($zID);
	my $from = 'noReply@matelook.com';
	my $subject = 'You have been tagged on MateLook';
    my $url = stripUrlParams($thisURL);
	my $link = "$url?action=post&a=$postAuthor&b=pid$postID";
    my $authorname = zIDtoName($logged_in_user);
my $message = <<eof
<!DOCTYPE html>
<html lang="en">
<head></head>
<h1>$authorname tagged you in a post on Matelook</h1>
<p>View the post here</p>
<p><a href = "$link">$link</a></p>
<p>If you are unable to click on the link, just copy it into your browser. (
<p>Kind Regards,<br>
Matelook Admin</p>
<p>(Please do not reply to this email.)</p>
eof
	;
	
	$message .= end_html();
	open(MAIL, "|/usr/sbin/sendmail -t");
	 
	# Email Header
	print MAIL "To: $to\n";
	print MAIL "From: $from\n";
	print MAIL "Subject: $subject\n";
	print MAIL "Content-Type: text/html;charset=utf-8\n";

	# Email Body
	print MAIL $message;

	close(MAIL);
	return 1;
}

sub comment_on_post {
	my ($author, $postID, $comment) = @_;
	my $commentDir = "$users_dir/$author/posts/$postID/comments";
	my $newCommentnum;
	
    # handle notifications
    notify_tags($comment,"email_comment", $author, $postID);
    
	my @comments = glob("$commentDir/*");
	
	# in case there's no comments, make sure to make a new directory
	if(!@comments) {
		mkdir $commentDir unless -d $commentDir;
		$newCommentnum = "0";
	} else {
		foreach (@comments) {
			$_ =~ s/.*?comments\///;
		}
		$newCommentnum = $comments[$#comments] + 1;
	}	
	
	my $newCommentDir = "$commentDir/$newCommentnum";
	if (-d $newCommentDir) {
		return 0;
	} else {
		mkdir $newCommentDir;
	}
	
	open my $fileHandle, ">>", "$newCommentDir/comment.txt" or return 0;
	
	# add message to the new file	
	
	my $now = time();
	my $tz = strftime("%z", localtime($now));
	$tz =~ s/(\d{2})(\d{2})/$1:$2/;
	
	# make ISO8601 timestamp
	
	my $currentTimestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz . "\n";
	
	my $fileprint = "time=$currentTimestamp\n";
	$fileprint .= "from=$logged_in_user\n";
	$fileprint .= "message=$comment\n";
	print $fileHandle $fileprint;
	close $fileHandle;
	
	return 1;
}

sub newPost {
	my($post) = @_;
	my $postdir = "$users_dir/$logged_in_user/posts";
	my $newPostnum;
	my @userposts = glob("$postdir/*");

	if(!@userposts) {
		mkdir $postdir unless -d $postdir;
		$newPostnum = "0";
	} else {
		foreach (@userposts) {
			$_ =~ s/.*?posts\///;
		}
		$newPostnum = $userposts[$#userposts] + 1;
	}	
	
	my $newPostDir = "$postdir/$newPostnum";
	
	if (-d $newPostDir) {
		return 0;
	} else {
		mkdir $newPostDir;
	}
	
	open my $fileHandle, ">>", "$newPostDir/post.txt" or return 0;
	# add message to the new file	
	
	my $now = time();
	my $tz = strftime("%z", localtime($now));
	$tz =~ s/(\d{2})(\d{2})/$1:$2/;

	# make ISO8601 timestamp
	my $currentTimestamp = strftime("%Y-%m-%dT%H:%M:%S", localtime($now)) . $tz . "\n";
	
	my $fileprint = "time=$currentTimestamp\n";
	$fileprint .= "from=$logged_in_user\n";
	$fileprint .= "message=$post\n";
	print $fileHandle $fileprint;
	close $fileHandle;
	
    # handle notifications
    notify_tags($post,"email_post", $logged_in_user, $newPostnum);
    
	return 1;
	
}

sub get_Post {

	my ($author, $postID) = @_;
	my $profilepic = get_avatar_link($logged_in_user);
	
	if (!$author || !$postID) {
		$author = param('a') || '';
		#format = a=z1234567&b=pid[number]
		$postID = param('b') || '';	
		$postID =~ s/^pid//;
	}
	my $ori_author = $author;
	my $ori_ID = $postID;
    
	my $postDir = "$users_dir/$author/posts/$postID";
	my $authorDP = get_avatar_link($author);
	my $authorName = zIDtoName($author);
	my $timeStamp = 0;
	my $message = 0;
	my @html;
	my $comments_html;
	my %comments;
	my $numComments = 0;
    my $numReplies = 0;
    
	#global#
    $commentReplies = 0;
    #global#
    
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
	
	if(open(F, "<$postDir/post.txt")) {	
		
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
		
		# valid post
		if(!$message || !$timeStamp) {
			return "invalid post params";
		} else {
			#convert timestamp
			$timeStamp = strftime '%a, %d %b %y', localtime $timeStamp;
            #convert tags
            $message = convert_tags($message);
		}
		
		%comments = fetch_comments($postDir);
		if (exists $comments{'-1'}) {
			$numComments = 0;
		} else {
			$numComments = scalar keys %comments;
		}

		#open up comments hash 
		foreach my $timeStamp (reverse sort keys %comments) {
			foreach my $author (keys %{$comments{$timeStamp}}) {
				foreach my $commentSrc (keys %{$comments{$timeStamp}{$author}}) {
					push @html, build_comments_html($timeStamp, $comments{$timeStamp}{$author}{$commentSrc}, $author, $ori_author, $ori_ID, $commentSrc);
				}		
			}
		}
		$comments_html = join '',@html;
		
	} else {
		return "invalid post params";
	}
	
	if ($numComments > 1) {
		$numComments .= " Comments";
	} elsif ($numComments == 1){
		$numComments .= " Comment";
	} else {
		$numComments = "No comments yet";
	}

    if ($commentReplies > 1) {
		$numReplies = "$commentReplies Replies";
	} elsif ($commentReplies == 1){
		$numReplies = "$commentReplies Reply";
	} else {
        $numReplies = "0 Replies";
    }
    
	#global set it back to 0 in case #
    $commentReplies = 0;
	return<<eof
<body>
	<script language="javascript"> 
		function toggle(showHideDiv, switchTextDiv) {
			var ele = document.getElementById(showHideDiv);
			var text = document.getElementById(switchTextDiv);
			if(ele.style.display == "none") {
					ele.style.display = "block";
				text.innerHTML = "";
			}
		} 
	</script>
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
          <div class="row">
            <div class="col-sm-9">
              <div class="blog-post">
                <div class="post-item">
                  <div class="caption wrapper">
                    <div class="post-sum">
                       <p>
						$message
					   </p>
                    </div>
                    <div class="line line-lg"></div>
                    <div class="text-muted">
                      <i class="icon-user icon-muted"></i> <a href="?action=profile&profile_id=$author" class="m-r-sm"><img src="$authorDP" class="thumb-sm img-rounded"> $authorName</a>
                      <i class="icon-time icon-muted"></i> $timeStamp
                    </div>
                  </div>
                </div>
              </div>
              <h4 class="m-t-lg m-b">$numComments, $numReplies</h4>
              <section class="comment-list block">
                $comments_html
              </section>
              <form method="post">
                <div class="input-group">
				  <input type="text" name="comment_post" class="form-control" placeholder="Write a comment...">
				  <input type="hidden" name="post_a" value="$author">
				  <input type="hidden" name="post_b" value="pid$postID">
				  <span class="input-group-btn">
					<button class="btn btn-white" type="submit">Post</button>
				  </span>
				</div>
              </form>
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
  <!-- App -->
  <script src="src/js/app.js"></script>
  <script src="src/js/app.plugin.js"></script>
  <script src="src/js/app.data.js"></script>

eof

}

1;
