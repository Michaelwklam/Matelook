#!/usr/bin/perl -w

sub handleSignup {
	my $zID = param('signup_zID') || '';
    my $email = param('signup_email') || '';
	my $password = param('signup_password') || '';
	
	#make it lower case
	$zID = lc $zID;
	
	#check if zID valid
	if ($zID !~ /z\d{7}/) {
		print page_header(1);
		print notify("invalid", "Invalid zID");
		print signup_page($zID, $email, $password),page_trailer();
		exit;
	} elsif(-d "$users_dir/$zID") {#user already exists
		print page_header(1);
		print notify("invalid", "User already exists. Are you sure this is your zID?");
		print signup_page($zID, $email, $password),page_trailer();
		exit;
	} else {
		my $profilesrc = "$users_dir/$zID";
		mkdir $profilesrc unless -d $profilesrc;
		open my $fileHandle, ">", "$profilesrc/user.txt" or return 0;

		my $fileprint = "zid=$zID\n";
		$fileprint .= "password=$password\n";
		$fileprint .= "email=$email\n";
        $fileprint .= "full_name=\n";
        $fileprint .= "home_suburb=\n";
        $fileprint .= "home_latitude=\n";
        $fileprint .= "home_longtitude=\n";
        $fileprint .= "program=\n";
        $fileprint .= "birthday=\n";
        $fileprint .= "mates=\n";
        $fileprint .= "courses=\n";
		print $fileHandle $fileprint;
		close $fileHandle;
		
		# write verification ID
		my $verificationID = generateID();
		open $fileHandle, ">", "$profilesrc/verification.txt" or return 0;
		$fileprint = "$verificationID";
		print $fileHandle $fileprint;
		close $fileHandle;
		
		#send mail to user
		if (sendVerificationMail($email,$zID,$verificationID)){
			print page_header(1);
			print notify("success", "Thank you for signing up with us. You will receive an email to activate your account shortly.");
			print signup_page(),page_trailer();
			exit;
		}
	}
	return;
}

sub handleVerification() {

    return 0 if (param('action') != "verify");
    my $zID = param('id') || '';
	my $token = param('token') || '';

    if(-d "$users_dir/$zID") { #user exists
        my $file = "$users_dir/$zID/verification.txt";
  
        if(open(F, "<$file")) {
            my $authToken = <F>;
            chomp $authToken;

            if ($authToken eq $token) { #successfully verified
                close F;
                unlink $file;
                print page_header(1);
                print notify("success", "Thank you. Your email is now verified.");
                print login_page(),page_trailer();	
                exit;
            } else {
                print page_header(1);
                print notify("error", "Invalid Token");
                print signup_page(),page_trailer();
                exit; 
            }     
            close F;
        } else {
            print page_header(1);
            print notify("error", "This account is already verified.");
            print signup_page(),page_trailer();
            exit;
        }
    } else {
        print page_header(1);
        print notify("error", "Invalid User");
        print signup_page(),page_trailer();
        exit;
    }
}

sub sendVerificationMail {
	
	my ($to, $zID, $verificationID) = @_;

	my $from = 'noReply@matelook.com';
	my $subject = 'Welcome to Matelook';
	my $verifyurl = "$thisURL&action=verify&id=$zID&token=$verificationID";
my $message = <<eof
<!DOCTYPE html>
<html lang="en">
<head></head>
<h1>Welcome to Matelook</h1>
<p>Thank you for joining us and letting us connect you with your mates. In order to complete the account registration,
 please click on the link below to verify your email.</p>
<p><a href = "$verifyurl">$verifyurl</a></p>
<p>If you are unable to click on the link, just copy it into your browser.</p>

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

sub signup_page {
	my ($zID, $email, $password) = @_;
	return <<eof
	<body>
  <section id="content" class="m-t-lg wrapper-md animated fadeInDown">
    <a class="nav-brand" href="matelook.cgi">MateLook</a>
    <div class="row m-n">
      <div class="col-md-4 col-md-offset-4 m-t-lg">
        <section class="panel">
          <header class="panel-heading bg bg-primary text-center">
            Sign up
          </header>
          <form data-validate="parsley" action="" class="panel-body" method="POST">
            <div class="form-group">
              <label class="control-label">zID</label>
              <input type="text" placeholder="Enter a valid zID" class="form-control" name="signup_zID" value="$zID" data-required="true">
            </div>
            <div class="form-group">
              <label class="control-label">Email address</label>
              <input type="email" placeholder="test&#64;example.com" class="form-control" name="signup_email" value="$email" data-required="true">
            </div>
            <div class="form-group">
              <label class="control-label">Password</label>
              <input type="password" id="inputPassword" placeholder="Password" class="form-control" name="signup_password" value="$password" data-required="true">
            </div>
            <button type="submit" class="btn btn-info">Sign up</button>
            <div class="line line-dashed"></div>
            <p class="text-muted text-center"><small>Already have an account?</small></p>
            <a href="?login=1" class="btn btn-white btn-block">Sign in</a>
          </form>
        </section>
      </div>
    </div>
  </section>
  <!-- footer -->
  <footer id="footer">
    <div class="text-center padder clearfix">
      <p>
        <small>COMP2041 Project<br>&copy; Michael Lam</small>
      </p>
    </div>
  </footer>
  <!-- / footer -->
	<script src="src/js/jquery.min.js"></script>
  <!-- Bootstrap -->
  <script src="src/js/bootstrap.js"></script>
  <!-- app -->
  <script src="src/js/app.js"></script>
  <script src="src/js/app.plugin.js"></script>
  <script src="src/js/app.data.js"></script>
  <!-- parsley -->
  <script src="src/js/parsley/parsley.min.js" cache="false"></script>
  <script src="src/js/parsley/parsley.extend.js" cache="false"></script>
eof

}

1;
