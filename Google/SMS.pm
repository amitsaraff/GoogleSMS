package Google::SMS;
use strict;
use warnings;

use Carp;
use WWW::Mechanize;
use WWW::Mechanize::Plugin::FollowMetaRedirect;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies; 
use URI::Escape;

our (@ISA, $VERSION, @EXPORT_OK);
use constant {
	_LOGIN_URL  => 'https://www.google.com/accounts/ServiceLogin?' . 
	               'ltmpl=bluebar&service=grandcentral&continue=https://www.google.com/voice/account/signin',
	_USER_AGENT => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.1.7) Gecko/20100106 Ubuntu/9.10 (karmic) Firefox/3.5.7',
	_SMS_URL    => 'https://www.google.com/voice/sms/send/',
};

my ($_cookie_jar, $_rnr_se);
my $_login_status = 0;

@ISA       = qw( );
@EXPORT_OK = qw( );
$VERSION   = '0.1';

sub new {
	my $class = shift;
	my $self  = __parse_args(@_);

	$_cookie_jar = HTTP::Cookies->new();

	bless $self, $class;
	return $self;
}

#__parse_args(): Parse the user-specific login data and
# return a hash reference
sub __parse_args {
	my %args = @_;
	return \%args;
}

 
#login(): Perform login to grab current cookie-state
# which we will use when sending the POST url with the SMS
sub login {
	my $self = shift;
	my %args = @_;

	my $mech = WWW::Mechanize->new();
	$mech->cookie_jar($_cookie_jar);
	$mech->agent(_USER_AGENT);
	$mech->get(_LOGIN_URL);
	$mech->follow_meta_redirect( ignore_wait => 1 );
	##TODO: Add in a self-defined timeout mechanism above and beyond IP stacks

	if (! $mech->success) {
		croak "#ERR(SMS.pm): Unable to get login page\n";
	}

	if (! defined $mech->form_number(1)) {
		croak "#ERR(SMS.pm): Unable to locate form\n";
	}

	#Fill in the form details, and click on submit
	$mech->field(Email  => (exists $args{USERNAME} ? $args{USERNAME} : $self->{USERNAME}));
	$mech->field(Passwd => (exists $args{PASSWORD} ? $args{PASSWORD} : $self->{PASSWORD}));

	#my $resp = $mech->click();
	my $resp = $mech->click_button(name => 'signIn');

	if (!$resp->is_success) {
		croak "#ERR(SMS.pm): Unable to login\n";
	}

	my $output_page = $mech->content();

	#TODO:Meta-tag follow seems to lead us to a false URL, need to verify this
	#if ($output_page =~ m#<meta#) {
	#	$mech->follow_link(tag => 'meta');
	#	$output_page = $mech->content();
	#}

	if ($output_page =~ m/The username or password you entered is incorrect/) {
		croak "#ERR(SMS.pm): Username or password is incorrect\n";
	}
						    
    if ($output_page =~ m/rnr_se.*value=\"(.*?)\"/) {
		$_rnr_se = uri_escape($1);
	} 
	else {
		croak "#ERR(SMS.pm): Unable to get the rnr_se value\n";
    }

	$_login_status = 1;
}



sub sms {
	my ($self, $number, $message) = @_;
	my ($client, $request, $response, $postdata);


	if ( $_login_status == 0 ) {
		$self->login();
	}

	#Create a new useragent that is going to POST the sms request
	$client = LWP::UserAgent->new();
	$client->agent(_USER_AGENT);
	$client->timeout(30);
	$client->cookie_jar($_cookie_jar);


	#Create a HTTP Request with requisite POST information
	$postdata = "id=&phoneNumber=" . $number . "&text=" . uri_escape($message) . "&_rnr_se=" . $_rnr_se;

	$request = HTTP::Request->new(POST => _SMS_URL);
	$request->content_type('application/x-www-form-urlencoded');
	$request->content($postdata);

	#and send...
	$response = $client->request($request);


	if ($response->is_success) {
		return 1;
	}
	else {	
		croak "#ERR(SMS.pm): Failed to send message - ". $response->status_line . "\n";
	}

	return ;
}

1;
