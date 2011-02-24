use strict;
use warnings;
use 5.010;
use POE qw(Component::IRC Component::IRC::Plugin::AutoJoin);
use Data::Dumper;
use lib 'lib';
use MLDBM;
use POSIX qw( :fcntl_h);
use Regexp::Common qw/ URI /;


# IRC stuff
# mostly taken from the POE::Component::IRC's SYNOPSIS

my $nickname = 'aalt';
my $ircname = 'ooold';
my $server = 'irc.nerd2nerd.org';

my @channels = ('#geeks');

# We create a new PoCo-IRC object
my $irc = POE::Component::IRC->spawn(
        nick    => $nickname,
        ircname => $ircname,
        server  => $server,
        port    => 6697,
        UseSSL  => 1,
) or die "Oh noooo! $!";

POE::Session->create(
    package_states => [
        main => [ qw(_default _start irc_001 ) ],
    ],
    heap => { irc => $irc },
);


sub _start {
    my $heap = $_[HEAP];

# retrieve our component's object from the heap where we
# stashed it
    my $irc = $heap->{irc};

    $irc->plugin_add('AutoJoin', POE::Component::IRC::Plugin::AutoJoin->new(
                Channels => {map {$_ => ''} @channels} )
            );
    $irc->yield( register => 'all' );
    $irc->yield( register => 'whois' );
    $irc->yield( connect => { } );
    return;
}

sub irc_001 {
    my $sender = $_[SENDER];

# Since this is an irc_* event, we can get the component's
# object by
# accessing the heap of the sender. Then we register and
# connect to the
# specified server.
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

# we join our channels
    $irc->yield( join => $_ ) for @channels;

    return;
}

my (%count, %timestamp);
my $dbm1 = tie %count, 'MLDBM', 'count.db', O_CREAT|O_RDWR, 0640 or die $!;
my $dbm2 = tie %timestamp, 'MLDBM', 'timestamp.db', O_CREAT|O_RDWR, 0640 or die $!;

my $re_url = $RE{URI}{HTTP};
$re_url =~ s/http/https?/;

# We registered for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    return 0 if $event =~ /^irc_\d/;

    my @output = ( "$event: " );

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']');
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
#    say join ' ', @output;
    my $channel = eval { $args->[1][0] };
    return 0 unless $channel;
#    say "Channel: $channel";
    while ($args->[-1] =~ m/($re_url)/g) {
        my $url = $1;
#        say "DEBUG urL: '$url'";
        if (exists $count{$url}) {
#            say "DEBUG: $url is aaalt";
            my $post = '!' x $count{$url}++;
            my $pre  = 'a' x int(0.5 + log(time - $timestamp{$url}));
            $irc->yield(privmsg => $channel, $pre . 'lt' . $post);
        } else {
            $count{$url}     = 1;
            $timestamp{$url} = time;
        }
    }
    return 0;
}

$poe_kernel->run();
