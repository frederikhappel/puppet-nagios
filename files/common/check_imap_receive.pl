#!/usr/bin/perl
use strict;
my $VERSION = '0.6.0';
my $COPYRIGHT = 'Copyright (C) 2005-2008 Jonathan Buhacoff <jonathan@buhacoff.net>';
my $LICENSE = 'http://www.gnu.org/licenses/gpl.txt';
my %status = ( 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3 );

# look for required modules
exit $status{UNKNOWN} unless load_modules(qw/Getopt::Long Mail::IMAPClient/);

# get options from command line
Getopt::Long::Configure("bundling");
my $verbose = 0;
my $help = "";
my $help_usage = "";
my $show_version = "";
my $imap_server = "";
my $default_imap_port = "143";
my $default_imap_ssl_port = "993";
my $imap_port = "";
my $username = "";
my $password = "";
my $mailbox = "INBOX";
my @search = ();
my $search_critical_min = 1;
my $capture_max = "";
my $capture_min = "";
my $delete = 1;
my $no_delete_captured = "";
my $warntime = 15;
my $criticaltime = 30;
my $timeout = 60;
my $interval = 5;
my $max_retries = 10;
my $download = "";
my $download_max = "";
my $ssl = 0;
my $tls = 0;
my $ok;
$ok = Getopt::Long::GetOptions(
	"V|version"=>\$show_version,
	"v|verbose+"=>\$verbose,"h|help"=>\$help,"usage"=>\$help_usage,
	"w|warning=i"=>\$warntime,"c|critical=i"=>\$criticaltime,"t|timeout=i"=>\$timeout,
	# imap settings
	"H|hostname=s"=>\$imap_server,"p|port=i"=>\$imap_port,
	"U|username=s"=>\$username,"P|password=s"=>\$password, "m|mailbox=s"=>\$mailbox,
	"imap-check-interval=i"=>\$interval,"imap-retries=i"=>\$max_retries,
	"ssl!"=>\$ssl, "tls!"=>\$tls,
	# search settings
	"s|search=s"=>\@search,
	"search-critical-min=i"=>\$search_critical_min,
	"capture-max=s"=>\$capture_max, "capture-min=s"=>\$capture_min,
	"delete!"=>\$delete, "nodelete-captured"=>\$no_delete_captured,
	"download!"=>\$download, "download_max=i"=>\$download_max,
	);

if( $show_version ) {
	print "$VERSION\n";
	if( $verbose ) {
		print "Default warning threshold: $warntime seconds\n";
		print "Default critical threshold: $criticaltime seconds\n";
		print "Default timeout: $timeout seconds\n";
	}
	exit $status{UNKNOWN};
}

if( $help ) {
	exec "perldoc", $0 or print "Try `perldoc $0`\n";
	exit $status{UNKNOWN};
}

my @required_module = ();
push @required_module, 'IO::Socket::SSL' if ($ssl or $tls);
push @required_module, 'Email::Simple' if ($download);
exit $status{UNKNOWN} unless load_modules(@required_module);

if( $help_usage
	||
	( $imap_server eq "" || $username eq "" || $password eq "" || scalar(@search)==0 )
  ) {
	print "Usage: $0 -H host [-p port] -U username -P password -s HEADER -s X-Nagios -s 'ID: 1234.' [-w <seconds>] [-c <seconds>] [--imap-check-interval <seconds>] [--imap-retries <tries>]\n";
	exit $status{UNKNOWN};
}

# initialize
my $report = new PluginReport;
my $time_start = time;

# connect to IMAP server
my $imap;
eval {
	local $SIG{ALRM} = sub { die "exceeded timeout $timeout seconds\n" }; # NB: \n required, see `perldoc -f alarm`
	alarm $timeout;
	
	if( $ssl ) {
		$imap_port = $default_imap_ssl_port unless $imap_port;		
		my $socket = IO::Socket::SSL->new("$imap_server:$imap_port");
		die IO::Socket::SSL::errstr() unless $socket;
		$socket->autoflush(1);
		$imap = Mail::IMAPClient->new(Socket=>$socket, Debug => 0 );
		$imap->State(Mail::IMAPClient->Connected);
		$imap->_read_line() if "$Mail::IMAPClient::VERSION" le "2.2.9"; # necessary to remove the server's "ready" line from the input buffer for old versions of Mail::IMAPClient. Using string comparison for the version check because the numeric didn't work on Darwin and for Mail::IMAPClient the next version is 2.3.0 and then 3.00 so string comparison works
		$imap->User($username);
		$imap->Password($password);
		$imap->login() or die "$@";
	}
	elsif( $tls ) {
		# XXX  THIS PART IS NOT DONE YET ... NEED TO OPEN A REGULAR IMAP CONNECTION, THEN ISSUE THE "STARTTLS" COMMAND MANUALLY, SWITCHING THE SOCKET TO IO::SOCKET::SSL, AND THEN GIVING IT BACK TO MAIL::IMAPCLIENT ...
		$imap_port = $default_imap_port unless $imap_port;		
		$imap = Mail::IMAPClient->new(Debug => 0 );		
		$imap->Server("$imap_server:$imap_port");
		$imap->User($username);
		$imap->Password($password);
		$imap->connect() or die "$@";		
	}
	else {
		$imap_port = $default_imap_port unless $imap_port;		
		$imap = Mail::IMAPClient->new(Debug => 0 );		
		$imap->Server("$imap_server:$imap_port");
		$imap->User($username);
		$imap->Password($password);
		$imap->connect() or die "$@";
	}

	alarm 0;
};
if( $@ ) {
	chomp $@;
	print "IMAP RECEIVE CRITICAL - Could not connect to $imap_server port $imap_port: $@\n";
	exit $status{CRITICAL};	
}
unless( $imap ) {
	print "IMAP RECEIVE CRITICAL - Could not connect to $imap_server port $imap_port: $@\n";
	exit $status{CRITICAL};
}
my $time_connected = time;

# select a mailbox
unless( $imap->select($mailbox) ) {
	print "IMAP RECEIVE CRITICAL - Could not select $mailbox: $@ $!\n";
	$imap->logout();
	exit $status{CRITICAL};
}


# search for messages
my $tries = 0;
my @msgs;
until( scalar(@msgs) != 0 || $tries >= $max_retries ) {
	eval {
		$imap->select( $mailbox );
		# if download flag is on, we download recent messages and search ourselves
		if( $download )  {
			@msgs = download_and_search($imap,@search);
		}
		else {
			@msgs = $imap->search(@search);
			die "Invalid search parameters: $@" if $@;
		}		
	};
	if( $@ ) {
		chomp $@;
		print "Cannot search messages: $@\n";
		$imap->close();
		$imap->logout();
		exit $status{UNKNOWN};
	}	
	$report->{found} = scalar(@msgs);
	$tries++;
	sleep $interval unless (scalar(@msgs) != 0 || $tries >= $max_retries);
}

sub download_and_search {
	my ($imap,@search) = @_;
	my $ims = new ImapMessageSearch;
	$ims->querytokens(@search);	
	my @found = ();
	@msgs = $imap->messages or die "Cannot list messages: $@\n";
	@msgs = @msgs[0..$download_max-1] if $download_max;
	foreach my $m (@msgs) {
		my $message = $imap->message_string($m);		
		push @found, $m if $ims->match($message);
	}
	return @found;
}



# capture data in messages
my $captured_max_id = "";
my $captured_min_id = "";
if( $capture_max || $capture_min ) {
	my $max = undef;
	my $min = undef;
	my %captured = ();
	for (my $i=0;$i < scalar(@msgs); $i++) 	{
		my $message = $imap->message_string($msgs[$i]);
		if( $message =~ m/$capture_max/ ) {
			if( !defined($max) || $1 > $max ) {
				$captured{ $i } = 1;
				$max = $1;
				$captured_max_id = $msgs[$i];
			}
		}
		if( $message =~ m/$capture_min/ ) {
			if( !defined($min) || $1 < $min ) {
				$captured{ $i } = 1;
				$min = $1;
				$captured_min_id = $msgs[$i];
			}
		}
		print $message if $verbose > 1;
	}
	$report->{captured} = scalar keys %captured;
	$report->{max} = $max if defined $max;
	$report->{min} = $min if defined $min;
}

# delete messages
if( $delete ) {
	my $deleted = 0;
	for (my $i=0;$i < scalar(@msgs); $i++) 	{
		next if ($no_delete_captured && ($captured_max_id eq $msgs[$i]));
		next if ($no_delete_captured && ($captured_min_id eq $msgs[$i]));
		$imap->delete_message($msgs[$i]);
		$deleted++;
	}
	$report->{deleted} = $deleted;
	$imap->expunge() if $deleted;
}

# deselect the mailbox
$imap->close();

# disconnect from IMAP server
$imap->logout();

# calculate elapsed time and issue warnings
my $time_end = time;
my $elapsedtime = $time_end - $time_start;
$report->{seconds} = $elapsedtime;

my @warning = ();
my @critical = ();

push @warning, "no messages" if( scalar(@msgs) == 0 );
push @critical, "found less than $search_critical_min" if ( scalar(@msgs) < $search_critical_min );
push @warning, "connection time more than $warntime" if( $time_connected - $time_start > $warntime );
push @critical, "connection time more than $criticaltime" if( $time_connected - $time_start > $criticaltime );

# print report and exit with known status
my $short_report = $report->text(qw/seconds found captured max min deleted/);
if( scalar @critical ) {
	my $crit_alerts = join(", ", @critical);
	print "IMAP RECEIVE CRITICAL - $crit_alerts; $short_report\n";
	exit $status{CRITICAL};
}
if( scalar @warning ) {
	my $warn_alerts = join(", ", @warning);
	print "IMAP RECEIVE WARNING - $warn_alerts; $short_report\n";
	exit $status{WARNING};
}
print "IMAP RECEIVE OK - $short_report\n";
exit $status{OK};


# utility to load required modules. exits if unable to load one or more of the modules.
sub load_modules {
	my @missing_modules = ();
	foreach( @_ ) {
		eval "require $_";
		push @missing_modules, $_ if $@;	
	}
	if( @missing_modules ) {
		print "Missing perl modules: @missing_modules\n";
		return 0;
	}
	return 1;
}


# NAME
#	PluginReport
# SYNOPSIS
#	$report = new PluginReport;
#   $report->{label1} = "value1";
#   $report->{label2} = "value2";
#	print $report->text(qw/label1 label2/);
package PluginReport;

sub new {
	my ($proto,%p) = @_;
	my $class = ref($proto) || $proto;
	my $self  = bless {}, $class;
	$self->{$_} = $p{$_} foreach keys %p;
	return $self;
}

sub text {
	my ($self,@labels) = @_;
	my @report = map { "$self->{$_} $_" } grep { defined $self->{$_} } @labels;
	my $text = join(", ", @report);
	return $text;
}

package ImapMessageSearch;

require Email::Simple;

sub new {
	my ($proto,%p) = @_;
	my $class = ref($proto) || $proto;
	my $self  = bless {}, $class;
	$self->{querystring} = [];
	$self->{querytokens} = [];
	$self->{queryfnlist} = [];
	$self->{mimemessage} = undef;
	$self->{$_} = $p{$_} foreach keys %p;
	return $self;
}

sub querystring {
	my ($self,$string) = @_;
	$self->{querystring} = $string;
	return $self->querytokens( parseimapsearch($string) );
}

sub querytokens {
	my ($self,@tokens) = @_;
	$self->{querytokens} = [@tokens];
	$self->{queryfnlist} = [create_search_expressions(@search)];
	return $self;
}

sub match {
	my ($self,$message_string) = @_;
	my $message_mime = Email::Simple->new($message_string);
	return $self->matchmime($message_mime);
}

sub matchmime {
	my ($self,$message_mime) = @_;
	my $match = 1;
	foreach my $x (@{$self->{queryfnlist}}) {
		$match = $match and $x->($message_mime);
	}
	return $match;
}

# this should probably become its own Perl module... see also Net::IMAP::Server::Command::Search
sub create_search_expressions {
	my (@search) = @_;
	return () unless scalar(@search);
	my $token = shift @search;
	if( $token eq 'TEXT' ) {
		my $value = shift @search;
		return (sub {shift->as_string =~ /\Q$value\E/i},create_search_expressions(@search));
	}
	if( $token eq 'BODY' ) {
		my $value = shift @search;
		return (sub {shift->body =~ /\Q$value\E/i},create_search_expressions(@search));
	}
	if( $token eq 'SUBJECT' ) {
		my $value = shift @search;
		return (sub {shift->header('Subject') =~ /\Q$value\E/i},create_search_expressions(@search));		
	}
	if( $token eq 'HEADER' ) {
		my $name = shift @search;
		my $value = shift @search;
		return (sub {shift->header($name) =~ /\Q$value\E/i},create_search_expressions(@search));				
	}
	if( $token eq 'NOT' ) {
		my @exp = create_search_expressions(@search);
		my $next = shift @exp;
		return (sub { ! $next->(@_) }, @exp);
	}
	if( $token eq 'OR' ) {
		my @exp = create_search_expressions(@search);
		my $next1 = shift @exp;
		my $next2 = shift @exp;
		return (sub { $next1->(@_) or $next2->(@_) }, @exp);
	}
}

package main;
1;
