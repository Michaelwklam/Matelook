#!/usr/bin/perl -w

# written by andrewt@cse.unsw.edu.au September 2016
# as a starting point for COMP2041/9041 assignment 2
# http://cgi.cse.unsw.edu.au/~cs2041/assignments/matelook/

use CGI qw/:all/;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Cookie;
use Data::Dumper qw(Dumper);
use URI;

require "src/timeline.pl";
require "src/profile.pl";
require "src/search.pl";
require "src/post.pl";
require "src/matefinder.pl";
require "src/signin.pl";
require "src/signup.pl";
require "src/settings.pl";

sub main() {

    # define some global variables
    $debug = 1;
    $users_dir = "dataset-medium";
	$thisURL = URI->new( CGI::url() );
	$thisURL->query( $ENV{QUERY_STRING} || $ENV{REDIRECT_QUERY_STRING} ) if url_param();
    
	#max file size for photos
    $CGI::POST_MAX = 1024 * 1000;
    $safe_filename_characters = "a-zA-Z0-9_.-";
    
	#check all params
	use CGI ':cgi-lib';

    #hash all our params
    my $queries = CGI->new;
    %params = $queries->Vars;

    #handle signups, logins, recoveries
    if (exists $params{'recovery_pwd'} && exists $params{'recovery_id'}) {
        resetPassword($params{'recovery_id'},$params{'recovery_pwd'});
        exit;
	} elsif (exists $params{'lost_pwd_user_zid'}) { #handle lost password
	# handle signups
        handleLostPwd();
        exit;
	} elsif ($params{'action'} eq 'recover' && exists $params{'id'} && exists $params{'token'}) {
        handleRecovery();
        exit;
    } elsif (exists $params{'signup_zID'} && exists $params{'signup_email'} && exists $params{'signup_password'}) {
        #signup page being showed
        handleSignup();
        exit;
    } elsif (exists $params{'signup'} && exists $params{'action'} && exists $params{'id'} && exists $params{'token'}){
		handleVerification();
        exit;
	}
    
    #check if user is logged in
    $logged_in_user = checkLogin();
	$logged_in_user_dp = get_avatar_link($logged_in_user) if ($logged_in_user);
	$logged_in_user_name = zIDtoName($logged_in_user) if ($logged_in_user);
    
    if (!$logged_in_user && exists $params{'signup'}){
		print page_header(1),signup_page();
	} elsif((!param('username') && !$logged_in_user) || 
		(!$logged_in_user && exists $params{'login'})) {
        print page_header(1),login_page();	
    } else {
        # handle all other params
        handleParams();
		# Now tell CGI::Carp to embed any warning in HTML
		warningsToBrowser(1); 
    }   

    print page_trailer();
}

sub handleParams {
    
    #default action
    if(!%params) {
        print page_header(1);
        print get_timeline($logged_in_user);
        return;
    }

    #actions
    if(exists $params{'action'}) {
        my $action = $params{'action'};

        if($action eq "timeline") {
            print page_header(1);
            print get_timeline($logged_in_user);
            return;
        } elsif($action eq "settings" && scalar keys %params == 1) {
            print page_header(1);
            print settingsPage($logged_in_user);
            return;
        } elsif($action eq "settings" && scalar keys %params > 1) {
            handleSettings();
            return;
        } elsif ($action eq 'logout') {
            #ignore
            if(!checkLogin()) {
                return;
            }
            #expire cookie
            my $q = CGI->new;
            my $cookie = $q->cookie (
                            -name    => 'matelook',
                            -value   => '',
                            -path    => '/',
                            -expires => '-1d'
             );
            print $q->header(-cookie => $cookie);
            #show login page
            print page_header(),login_page();
            return;
        } elsif ($action eq 'profile' && !exists $params{'profile_id'}) {
			#print user's own profile
			print page_header(1);
			print get_profile($logged_in_user);
			return;
		} elsif ($action eq 'profile' && exists $params{'profile_id'}) {
			#print specified profile
			my $profileID = param('profile_id') || '';
			print page_header(1);
			print get_profile($profileID);
			return;
		} elsif ($action eq 'post' && exists $params{'a'} && exists $params{'b'}) {
			print page_header(1);
			print get_Post();
			return;
		} elsif ($action eq 'unfriend' && exists $params{'id'}) {
			my $userID = param('id') || '';
			if ($userID) {
				if (unfriend($userID)) {
					print page_header(1);
					my $name = zIDtoName($userID);
					print notify("success", "You are no longer friends with $name.");
					print get_profile($userID);
					return;
				} else {
					print page_header(1);
					print notify("error", "An error occured.");
					print get_profile($userID);
					return;
				}
			}
		} elsif ($action eq 'reqfriend' && exists $params{'id'}) {
			my $userID = param('id') || '';
			if ($userID) {
				if (sendMateRequest($userID)) {
					print page_header(1);
					print notify("success", "Your mate request has been sent");
					print get_profile($userID);
					return;
				} else {
					print page_header(1);
					print notify("error", "An error occured.");
					print get_profile($userID);
					return;
				}
			}
		} elsif ($action eq 'cancelreq' && exists $params{'id'}) {
			my $userID = param('id') || '';
			if ($userID) {
				if (cancelRequest($userID)) {
					print page_header(1);
					print notify("success", "Your mate request has been cancelled");
					print get_profile($userID);
					return;
				} else {
					print page_header(1);
					print notify("error", "An error occured.");
					print get_profile($userID);
					return;
				}
			}
		} elsif ($action eq 'acceptfriend' && exists $params{'id'}) {
			my $userID = param('id') || '';
			if ($userID && !exists $params{'sid'}) {
				#default accept
				if (acceptMateRequest($userID, $logged_in_user)) {
					print page_header(1);
					my $name = zIDtoName($userID);
					print notify("success", "You are now friends with $name");
					print get_profile($userID);
					return;
				}
			}
		} elsif ($action eq 'discover') {
			#mate suggestions page
			print page_header(1);
			print getDiscover($logged_in_user);
			return;
		} elsif ($action eq 'deletePost' && exists $params{'src'}) {
			my $postSrc = param('src') || '';
			if ($postSrc && deletePost($postSrc)){
				print page_header(1);
				print notify("success", "Your post has been deleted.");
				print get_profile($logged_in_user);
				return;
			} else {
				print page_header(1);
				print notify("error", "An error occured. Are you sure you're allowed to delete that post?");
				print get_profile($logged_in_user);
				return;
			}
		} elsif ($action eq 'deleteComment' && exists $params{'src'}) {
			my $postSrc = param('src') || '';
			if ($postSrc && deleteComment($postSrc)){
				print page_header(1);
				print notify("success", "Your Comment has been deleted.");
                print get_timeline($logged_in_user);
				return;
			} else {
				print page_header(1);
				print notify("error", "An error occured. Are you sure you're allowed to delete that comment?");
				return;
			}
		} elsif ($action eq 'deleteReply' && exists $params{'src'}) {
			my $postSrc = param('src') || '';
			if ($postSrc && deleteReply($postSrc)){
				print page_header(1);
				print notify("success", "Your Reply has been deleted.");
                print get_timeline($logged_in_user);
				return;
			} else {
				print page_header(1);
				print notify("error", "An error occured. Are you sure you're allowed to delete that reply?");
				return;
			}
		} elsif ($action eq 'delete_dp') {
			if (deleteDP()) {
                print page_header(1);
                print notify("success", "Your profile picture has been deleted");
                print settingsPage($logged_in_user);
                return;
            } else {
                print page_header(1);
                print notify("error", "An error occured while deleting your profile pic. Try again later.");
                print settingsPage($logged_in_user);
                return;
            }
		} 
    }

    #for logins       
    if (exists $params{'username'} && exists $params{'password'}) {
        #login page being showed
        my $logged_in_user = handleLogin();
        if($logged_in_user) {
            print page_header();
            print get_timeline($logged_in_user);
            return;
        } else {
            print page_header(1);
            print notify("invalid", "Invalid Username/password"),login_page();
            return;
        }
    }
	
	#search users
	if (exists $params{'search_users'}) {
		my %foundUsers = search_users();
		print page_header(1);
		print get_search_results($logged_in_user, "user", %foundUsers);
		return;
	}
	
	#search posts
	if (exists $params{'search_posts'}) {
		my $search = param('search_posts') || '';
		my %foundPosts = search_posts();
		print page_header(1);
		print get_search_results($logged_in_user, "post", %foundPosts);
		return;
	}
    
	#modify user info
	if (exists $params{'User_Info_Edit'}) {
		if (handleUserInfoEdit()) {
		    print page_header(1);
			print notify("success", "Your profile text has been editted successfully.");
			print get_profile($logged_in_user);
			return;
		
		} else {
		    print page_header(1);
			print notify("error", "An error occured while modifying your profile text.");
			print get_profile($logged_in_user);
			return;
		}
		return;
	}
	
	#new post 
	if (exists $params{'new_post'}) {
		my $newPost = param('new_post');
		if(!$newPost) {
			print page_header(1);
			print notify("error", "It appears you are trying to post an empty post, please type something in and try again.");
			print get_timeline($logged_in_user);
			return;
		} else {
			#process his post
			if (newPost($newPost)) {
				print page_header(1);
				print notify("success", "Your post has been made.");
				print get_timeline($logged_in_user);
				return;
			} else {
				print page_header(1);
				print notify("error", "An error has occured while trying to make your post.");
				print get_timeline($logged_in_user);
				return;
			}
		}
	}
	
	#new comment on post
	if (exists $params{'comment_post'} && exists $params{'post_a'} && exists $params{'post_b'}) {
		my $post_author = param('post_a');
		my $post_pid = param('post_b');
		my $comment = param('comment_post');
		$post_pid =~ s/^pid//;
		
		if (!$comment) {
			print page_header(1);	
			print notify("error", "It appears you are trying to post an empty comment, please type something in and try again.");
			print get_Post($post_author, $post_pid);	
			return;
		} else {
			if(comment_on_post($post_author, $post_pid, $comment)) {
				print page_header(1);
				print notify("success", "Your comment has been posted.");
				print get_Post($post_author, $post_pid);
				return;
			} else {
				print page_header(1);	
				print notify("error", "An error occured while making your post. Please try again.");
				print get_Post($post_author, $post_pid);	
				return;
			}	
		}
	}
	
	#new reply comment
	if (exists $params{'reply_comment'} && exists $params{'src'}) {
		my $reply = param('reply_comment');
		my $commentSrc = $params{'src'};
		my $post_author = $params{'post_a'};
		my $post_pid = $params{'post_b'};
		$post_pid =~ s/^pid//;
		
		if (!$reply) {
			print page_header(1);	
			print notify("error", "It appears you are trying to post an empty comment, please type something in and try again.");
			print get_Post($post_author, $post_pid);	
			return;
		} else {
			if(reply_comment($commentSrc, $reply)) {
				print page_header(1);
				print notify("success", "Your comment has been posted.");
				print get_Post($post_author, $post_pid);
				return;
			} else {
				print page_header(1);	
				print notify("error", "An error occured while making your reply. Please try again.");
				print get_Post($post_author, $post_pid);	
				return;
			}
			
		}
	}
}

sub notify {
	my ($type, $message) = @_;
	
	if ($type eq "error") {
		return<<eof
		<div class="alert alert-danger">
			<button type="button" class="close" data-dismiss="alert"><i class="icon-remove"></i></button>
			<i class="icon-ban-circle"></i>$message
		</div>
eof

	} elsif ($type eq "success") {
		return<<eof
		<div class="alert alert-success">
			<button type="button" class="close" data-dismiss="alert"><i class="icon-remove"></i></button>
			<i class="icon-check"></i>$message
		</div>
eof
	
	} elsif ($type eq "invalid") {
		return<<eof
		<div class="alert alert-danger">
			<button type="button" class="close" data-dismiss="alert"><i class="icon-remove"></i></button>
			<i class="icon-exclamation-sign"></i>$message
		</div>
eof
	
	}
}


#super simple function that returns the time and process number as unique ID
sub generateID {
	my $id = time()."$$";
	return $id;
}

sub checkLogin {

    %cookies = CGI::Cookie->fetch;
    $username = $cookies{'matelook'}->value if($cookies{'matelook'});

    if ($username) {       
        return $username;
    } else {
        return 0;
    } 
}

sub close_html{
	return<<eof
	</body>
</html>
eof

}
#
# HTML placed at the top of every page
#
sub page_header {
    my ($printcontentline) = @_;

    my $contentline = "Content-Type: text/html;charset=utf-8\n";
    $contentline = "" if(!$printcontentline);

    return <<eof
$contentline
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>MateLook</title>
    <meta name="description" content="app, web app, responsive, admin dashboard, admin, flat, flat ui, ui kit, off screen nav" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
    <link rel="stylesheet" href="src/css/matelook.css" type="text/css" />
    <link rel="stylesheet" href="src/css/bootstrap.css" type="text/css" />
    <link rel="stylesheet" href="src/css/animate.css" type="text/css" />
    <link rel="stylesheet" href="src/css/font-awesome.min.css" type="text/css" />
    <link rel="stylesheet" href="src/css/font.css" type="text/css" cache="false" />
    <link rel="stylesheet" href="src/css/plugin.css" type="text/css" />
    <link rel="stylesheet" href="src/css/app.css" type="text/css" />  
    <link rel="stylesheet" href="src/js/select2/select2.css" type="text/css" />
    <link rel="stylesheet" href="src/js/fuelux/fuelux.css" type="text/css" />
    <link rel="stylesheet" href="src/js/datepicker/datepicker.css" type="text/css" />
    <link rel="stylesheet" href="src/js/slider/slider.css" type="text/css" />
    <link rel="stylesheet" href="src/css/plugin.css" type="text/css" />
    <link rel="stylesheet" href="src/css/app.css" type="text/css" />
    <!--[if lt IE 9]>
    <script src="src/js/ie/respond.min.js" cache="false"></script>
    <script src="src/js/ie/html5.js" cache="false"></script>
    <script src="src/js/ie/fix.js" cache="false"></script>
    <![endif]-->
</head>
eof
}

# Helpers

sub handleRecovery {

    return 0 if (param('action') != "recover");
    my $zID = param('id') || '';
	my $token = param('token') || '';

    if(-d "$users_dir/$zID") { #user exists
        my $file = "$users_dir/$zID/recovery.txt";
  
        if(open(F, "<$file")) {
            my $authToken = <F>;
            chomp $authToken;

            if ($authToken eq $token) { #successfully recover
                close F;
                unlink $file;
                print page_header(1),recovery_page($zID),page_trailer();
                exit;
            } else {
                print page_header(1);
                print notify("error", "Invalid Token");
                print login_page(),page_trailer();
                exit; 
            }     
            close F;
        } else {
            print page_header(1);
            print notify("error", "Invalid Request");
            print login_page(),page_trailer();
            exit;
        }
    } else {
        print page_header(1);
        print notify("error", "Invalid User");
        print login_page(),page_trailer();
        exit;
    }

}

sub stripUrlParams {
    my ($url) = @_;
    $url =~ s/matelook.cgi.*/matelook.cgi/;
    return $url;
}

sub handleLostPwd {
    my $zID = param('lost_pwd_user_zid') || '';
    my $profilesrc = "$users_dir/$zID";
    my $resetToken = generateID();
    
    #found user file
    if(-d "$profilesrc") {
		# make a recovery filefield
        open $fileHandle, ">", "$profilesrc/recovery.txt" or return 0;
        my $fileprint = "$resetToken\n";
		print $fileHandle $fileprint;
		close $fileHandle;
        if (sendRecoveryMail($zID, $resetToken)){    
            print page_header(1);
            print notify("success", "Instructions on how to recover your account has been emailed to you.");
            print login_page();	
        } else {
            print page_header(1);
            print notify("error", "Unable to send you the recovery mail");
            print login_page();	
        }
	} else {
        print page_header(1);
        print notify("error", "Unable to find the zID specified.");
        print login_page();	
    }
    return;
}

sub resetPassword {
    my ($zID,$newPwd) = @_;
    my $file = "$users_dir/$zID/user.txt";
    my $newLine = "password=$newPwd\n";
    
    #write his password to file
    my $tmpfile = "$file.new";
    open(F, "<$file") || return 0;
    open G, ">$tmpfile" or return 0;

    while (my $line = <F>) {
        if($line =~ /^password=/) {
            $line = $newLine;
        }
        print G $line;
    }
    
    close F;
    close G;
    rename("$tmpfile", $file) or return 0; 
    
    print page_header(1);
    print notify("success", "Thank you. Your password has been updated.");
    print login_page($zID);	
    print page_trailer();
}

sub sendRecoveryMail {
	
	my ($zID, $recoveryID) = @_;

    my $to = getUserEmail($zID);
	my $from = 'noReply@matelook.com';
	my $subject = 'Password Recovery';
    my $url = stripUrlParams($thisURL);
	my $recoveryurl = "$url?action=recover&id=$zID&token=$recoveryID";
my $message = <<eof
<!DOCTYPE html>
<html lang="en">
<head></head>
<h1>Password Recovery</h1>
<p>You've requested a password recovery. To do so, click on the link below and follow the instructions.</p>
<p><a href = "$recoveryurl">$recoveryurl</a></p>
<p>If you are unable to click on the link, just copy it into your browser. (NOTE: You will only be able to access this url <b>once</b>.)</p>
<p>If you have not requested this, please ignore this email and change your password.</p>
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

#
# HTML placed at the bottom of every page
# It includes all supplied parameter values as a HTML comment
# if global variable $debug is set
#
sub page_trailer {
    my $html = "";
    $html .= join("", map("<!-- $_=".param($_)." -->\n", param())) if $debug;
    $html .= end_html;
    return $html;
}

main();
