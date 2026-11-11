# Player class for Crazy8 game, and any others
# 09/01/2007

#	2008/09/01	fix mystake in _update_statistics
#	2008/21/01	fix _update_statistics
#	2008/02/12	add	player's unique id
#	2008/02/18	chg	player's unique id doesn't include random part
#				chg improve save method
#	2008/02/19	chg improve constructor
#				add match played stat item
#	2008/02/21	chg load/save


# TODO:
# 	save many players to the same files => ~ add playerID (uniq, ~ md5 or something else)
# 	recognize already saved player
# 	update file
# 	remove a/all player(s)

package Games::Player;
@ISA = ('Exporter');

use strict;
use warnings;
use Carp;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;


my $VERSION = '0.10';
my $RELEASE = '2008/02/21';

use constant DEFAULT_PLAYER_NAME => 'unammed player';
use constant DEFAULT_PLAYER_RANK => 0;
use constant DEFAULT_PLAYER_FILE => $ENV{'HOME'}.'/.players';

use constant HUMAN_PLAYER => 1;
use constant COMPUTER_PLAYER => 2;

my $_players_store = {};


sub new
{
	my ($package, %data) = @_;
	my $_player = {};

	my $defaults =
		{
			name => DEFAULT_PLAYER_NAME,
			hand => undef,
			kind => HUMAN_PLAYER,
			rank => DEFAULT_PLAYER_RANK,
			file => DEFAULT_PLAYER_FILE
		};

	$data{kind} = _convert_kind ($data{kind}) if (exists $data{kind});
	$data{_id} =  md5_hex ($data{name}) if (exists $data{name});
	%{$_player} = (%{$defaults}, %data);

	##$_player->{_id} = md5_hex ($_player->{name}); ##.time ().rand (time()));

	_load ($_player->{file});

	# ~ overwrite/forgot-saved to don't load player data
	
	$_player->{score} = 0;
	$_player->{statistics}->{played} = 0;			# games played
	$_player->{statistics}->{win} = 0;				# games win
	$_player->{statistics}->{lost} = 0;				# or lost
	$_player->{statistics}->{m_win} = 0;			# matches win
	$_player->{statistics}->{m_lost} = 0;			# or lost
	$_player->{statistics}->{avg_win} = 0.0;		# averages here
	$_player->{statistics}->{avg_lost} = 0.0;
	$_player->{statistics}->{avg_mwin} = 0.0;
	$_player->{statistics}->{avg_mlost} = 0.0;

	$_player->{_alive} = 1;

	bless $_player, $package;

	$_player;
}


sub reset
{
	my ($_base) = shift;

	$_base->{name} = DEFAULT_PLAYER_NAME;
	$_base->{hand} = undef;
	$_base->{rank} = DEFAULT_PLAYER_RANK;
	$_base->{file} = DEFAULT_PLAYER_FILE;

	$_base->{score} = 0;
	$_base->{played} = 0;
	$_base->{m_played} = 0;
	$_base->{statistics}->{win} = 0;
	$_base->{statistics}->{lost} = 0;
	$_base->{statistics}->{m_win} = 0;
	$_base->{statistics}->{m_lost} = 0;
	$_base->{statistics}->{avg_win} = 0.0;
	$_base->{statistics}->{avg_lost} = 0.0;
	$_base->{statistics}->{avg_mwin} = 0.0;
	$_base->{statistics}->{avg_mlost} = 0.0;
}


sub name
{
	my ($_base, $new_name) = @_;

	if (defined $new_name)
	{
		$_base->{name} = $new_name;
	}
	else
	{
		return $_base->{name};
	}
}


sub rank
{
	my ($_base) = @_;

	return $_base->{rank};
}


sub hand
{
	my ($_base, $hand) = @_;

	if (defined $hand and $hand->isa ('Games::Cards::Hand'))
	{
		$_base->{hand} = $hand;
	}
	else
	{
		return $_base->{hand};
	}
}


sub score
{
	my ($_base, $new_score) = @_;

	if (defined $new_score)
	{
		$_base->{score} += $new_score;
	}
	else
	{
		return $_base->{score};
	}
}


sub win
{
	my $_base = shift;

	$_base->{statistics}->{win}++;
	$_base->{statistics}->{played}++;
	$_base->_update_statistics ();
}


sub mwin
{
	my $_base = shift;

	$_base->{statistics}->{m_win}++;
	$_base->{statistics}->{m_played}++;
	$_base->_update_statistics ();
}


sub loose
{
	my $_base = shift;

	$_base->{statistics}->{lost}++;
	$_base->{statistics}->{played}++;
	$_base->_update_statistics ();
}


sub mloose
{
	my $_base = shift;

	$_base->{statistics}->{m_lost}++;
	$_base->{statistics}->{m_played}++;
	$_base->_update_statistics ();
}


sub data
{
	my $_base = shift;

	$_base->{statistics};
}


sub kind
{
	my ($_base, $new_kind) = @_;

	if (defined $new_kind)
	{
		unless ($_base->{_alive})
		{
			$_base->{kind} = $new_kind;
		}
		else
		{
			croak "Can't change player kind while player is alive!\n";
		}
	}
	else
	{
		return $_base->{kind};
	}
}


sub save
{
	my ($_base, $file) = @_;

	for my $item (qw(name kind score rank))
	{
		$_players_store->{$_base->{_id}}->{$item} = $_base->{$item};
	}

	for my $item (qw/played win lost m_win m_lost avg_win avg_lost avg_mwin avg_mlost/)
	{
		$_players_store->{$_base->{_id}}->{statistics}->{$item} = $_base->{statistics}->{$item};
	}

	_save ($_base->{file});
}


sub _save
{
	my $file = shift;

	my $players = {};

	if (~~ keys %{$_players_store} == -1)
	{
		_load ();
	}

	if (open (PLAYER, '> '.$file))
	{
		my $line;

		for my $player_id (sort keys %{$_players_store})
		{
			$line = $player_id.'|'.$_players_store->{$player_id}->{name}.'|'.$_players_store->{$player_id}->{kind}.'|'.$_players_store->{$player_id}->{score}.'|'.$_players_store->{$player_id}->{rank}.'|';

			for my $item (sort keys %{$_players_store->{$player_id}->{statistics}})
			{
				$line .= $_players_store->{$player_id}->{statistics}->{$item}.'|';
			}

			$line =~ s/\|$//;
			$line .= "\n";

			print PLAYER $line;
		}

		close (PLAYER);
	}
	else
	{
		croak "Can't update player file [$file]: $!";
	}
}


sub load
{
	my ($_base, $pid) = @_;

	for my $player (keys %{$_players_store})
	{
		if ($player eq $_base->{_id})
		{
			print "Found: $player\n";

			for my $item (qw(name kind score rank))
			{
				$_base->{$item} = $_players_store->{$_base->{_id}}->{$item};
			}

			for my $item (qw/played win lost m_win m_lost avg_win avg_lost avg_mwin avg_mlost/)
			{
				$_base->{statistics}->{$item} = $_players_store->{$_base->{_id}}->{statistics}->{$item};
			}

			last;
		}
	}
}


sub _load
{
	my $file = shift;

	if (open (PLAYER, '< '.$file))
	{
		while (<PLAYER>)
		{
			my $loaded_players = {};

			chomp;
			my @data = split /\|/, $_;
			if ($#data != 13)
			{
				print "Invalid player found: [$_], ignored ($#data)\n";
				next;
			}

			my $count = 0;
			for my $item (qw(_id name kind score rank))
			{
				$loaded_players->{$item} = $data[$count++];
			}

			for my $item (qw/played win lost m_win m_lost avg_win avg_lost avg_mwin avg_mlost/)
			{
				$loaded_players->{statistics}->{$item} = $data[$count++];
			}

			$_players_store->{$loaded_players->{_id}} = $loaded_players;
		}

		close (PLAYER);
	}
	else
	{
		croak "Can't open player file [$file]: $!\n";
	}

	print "Players in file: ".Dumper ($_players_store);
}


sub is_human
{
	my $_base = shift;

	return ($_base->{kind} == HUMAN_PLAYER);
}


sub is_not_human
{
	my $_base = shift;

	return ($_base->{kind} != HUMAN_PLAYER);
}


sub _convert_kind
{
	my $raw_kind = shift;
	my $converted_kind;

	if (defined $raw_kind)
	{
		$converted_kind = HUMAN_PLAYER if ($raw_kind =~ /h/i);
		$converted_kind = COMPUTER_PLAYER if ($raw_kind =~ /c/i);
	}

	$converted_kind;
}


sub _update_rank
{
}


sub _update_statistics
{
	my $_base = shift;

	print "=> Baw: $_base->{statistics}->{avg_win}  bsw: $_base->{statistics}->{win}\n";
	if ($_base->{statistics}->{win} > 0)
	{
		$_base->{statistics}->{avg_win} = (1 - 1/$_base->{statistics}->{win}) * $_base->{statistics}->{avg_win} + $_base->{statistics}->{avg_win}/$_base->{statistics}->{win};
	}
	else
	{
		$_base->{statistics}->{avg_win} = 1;
	}

	if ($_base->{statistics}->{lost} > 0)
	{
		$_base->{statistics}->{avg_lost} = (1 - 1/$_base->{statistics}->{lost}) * $_base->{statistics}->{avg_lost} + $_base->{statistics}->{avg_lost}/$_base->{statistics}->{lost};
	}
	else
	{
		$_base->{statistics}->{avg_lost} = 1;
	}
}


sub DESTROY
{
	print "Player destroyed\n";
}

1;

__END__

=head1 NAME

Games::Player

=head1 SYNOPSIS

use Games::Player;

my $player1 = Games::Player->new 
			(
				name => 'player1',
				kind => 'human',
				file => './players',
			);

print "p1 name's :".$player1->name ()."   Rank: ".$player1->rank ()."\n";
print "p1 score: ".$player1->score ()."\n";
print "p1 is ".($player1->is_human () ? 'human' : 'computer')."\n";

$player1->load ();

...

$player1->score (10);
$player1->win ();

$player1->save ();


=head1 AUTHOR



=head1 SEE ALSO
