#!/usr/bin/perl -w

sub handleLogin {
    my $username = param('username') || '';
    my $password = param('password') || '';
    
    return 0 if(!$username || !$password);

    if(-d "$users_dir/$username") { #user exists
        my $file = "$users_dir/$username/user.txt";
        open(F, "<$file") || die ("Corrupted account file");
        my @pwdonfile = grep /password=/, <F>;
        # only take first one (assume file is valid)
        my $pwd = $pwdonfile[0];
        chomp $pwd;
        $pwd =~ s/^password=//;
        
        if($password eq $pwd) {

            #set cookie
            my $cgi = CGI->new;
            print $cgi->header(
                            -cookie => CGI::Cookie->new(
                            -name    => 'matelook',
                            -value   => $username,
                            -expires => '+4h',
                        ),
                    );  
            #authenticated, return timeline           
            return $username;
        } else {
            $pageType = "login";
            print page_header(1);
            print notify("invalid", "Invalid username/password. Please try again."),login_page($username,$password);
			print page_trailer;
			exit;
        }
    } else {
        $pageType = "login";
		print page_header(1);
		print notify("invalid", "Invalid username/password. Please try again."),login_page($username,$password);
		print page_trailer;
		exit;
    }

    #by default return 0
    return 0;
}

sub login_page {
	my ($username,$password) = @_;
	
	return <<eof
	<body>
  <section id="content" class="m-t-lg wrapper-md animated fadeInUp">
    <a class="nav-brand" href="matelook.cgi">MateLook</a>
    <div class="row m-n">
      <div class="col-md-4 col-md-offset-4 m-t-lg">
        <section class="panel">
          <header class="panel-heading text-center">
            Login to use MateLook
          </header>
          
          <form data-validate="parsley" id="loginform" class="panel-body" action="" method="POST">
            <div class="form-group">
              <label class="control-label">zID</label>
              <input type="text" name="username" id="username" data-required="true" placeholder="Z55555555" class="form-control" value = "$username">
            </div>
            <div class="form-group">
              <label class="control-label">Password</label>
              <input type="password" name="password" id="password" placeholder="Password" class="form-control" value="$password" data-required="true">
            </div>
            <div class="checkbox">
              <label>
                <input type="checkbox" name="stay_logged_in" checked data-required="false"> Keep me logged in
              </label>
            </div>
            <a href="#lost_password" class="pull-right m-t-xs" data-toggle="modal"><small>Forgot password?</small></a>
            <input type="submit" value="Login" id="login" class="btn btn-info"/>
            <div class="line line-dashed"></div>
            <p class="text-muted text-center"><small>Do not have an account?</small></p>
            <a href="?signup=1" class="btn btn-white btn-block">Create an account</a>
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
  <!-- Modal for forgot password -->
	   <div class="modal fade" id="lost_password">
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-body">
              <div class="row">
                <div class="col-sm-12">
                  <form role="form" method="POST" data-validate="parsley">
                    <div class="form-group">
                      <label>Please confirm your zID</label>
                      <input type="text" class="form-control" name="lost_pwd_user_zid" data-required="true">
                    </div>
                    <div class="form-group">
                      <button type="submit" class="btn btn-sm btn-success pull-right text-uc m-t-n-xs"><strong>Recover</strong></button>              
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
  <!-- parsley -->
  <script src="src/js/parsley/parsley.min.js" cache="false"></script>
  <script src="src/js/parsley/parsley.extend.js" cache="false"></script>
  
eof

}

sub recovery_page {
	my ($zID) = @_;
	return <<eof
	<body>
  <section id="content" class="m-t-lg wrapper-md animated fadeInUp">
    <a class="nav-brand" href="matelook.cgi">MateLook</a>
    <div class="row m-n">
      <div class="col-md-4 col-md-offset-4 m-t-lg">
        <section class="panel">
          <header class="panel-heading text-center">
            Reset your password now
          </header>  
          <form data-validate="parsley" id="loginform" class="panel-body" action="" method="POST">
            <div class="form-group pull-in clearfix">
              <div class="col-sm-6">
                <label>Enter password</label>
                <input type="password" class="form-control" data-required="true" id="pwd">   
              </div>
              <div class="col-sm-6">
                <label>Confirm password</label>
                <input type="password" class="form-control" data-equalto="#pwd" name="recovery_pwd" data-required="true">      
              </div>   
            </div>
            <input type="hidden" name="recovery_id" value="$zID"> 
            <input type="submit" value="Reset" id="reset" class="btn btn-info pull-right"/>
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
  <!-- Modal for forgot password -->
	   <div class="modal fade" id="lost_password">
        <div class="modal-dialog">
          <div class="modal-content">
            <div class="modal-body">
              <div class="row">
                <div class="col-sm-12">
                  <form role="form" method="POST" data-validate="parsley">
                    <div class="form-group">
                      <label>Please confirm your zID</label>
                      <input type="text" class="form-control" name="lost_pwd_user_zid" data-required="true">
                    </div>
                    <div class="form-group">
                      <button type="submit" class="btn btn-sm btn-success pull-right text-uc m-t-n-xs"><strong>Recover</strong></button>              
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
  <!-- parsley -->
  <script src="src/js/parsley/parsley.min.js" cache="false"></script>
  <script src="src/js/parsley/parsley.extend.js" cache="false"></script>
  
eof

}

1;
