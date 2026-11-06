# The window lock's queue, for tools/window_lock.sh: waiters take the window in the
# order they came, each holding a ticket while it waits.
#
# Usage:  perl tools/lib/window_queue.pl ASKER QUEUE FD SECONDS MESSAGE
#
# A ticket is a number from QUEUE/counter, counted under that file's own lock, and a
# file QUEUE/N this process holds an exclusive flock(2) on while it waits: the kernel
# drops it when the waiter dies, however it dies, so a ticket whose lock can be taken
# belongs to no one and is removed by the first waiter behind it to see it. The ticket
# is taken and locked under the counter's lock, so a waiter behind it, whose number
# came later, never sees it unlocked while its waiter lives.
#
# Once no live ticket is ahead of it, it takes the window lock itself — flock(2) on
# descriptor FD, which it shares with ASKER, so the lock stays with ASKER when this
# process ends, as with tools/lib/fd_lock.sh's Perl — and prints "locked" on stdout.
# It never blocks in flock: it tries once every half second, so it sees its time run
# out and its asker die (an asker gone ends it, freeing its ticket, where a Perl blocked
# in flock waits on for no one), and costs no process per try. MESSAGE goes to stderr
# once, the first time it has to wait, with how many live tickets are ahead of it.
#
# Exits 0 holding the lock, 1 when SECONDS (above 0) have passed without it, 3 when
# ASKER is gone, 2 when the queue cannot be used (the caller then waits unordered).
#
# The kernel lock alone is what keeps two windows apart; the queue only orders those
# that take a ticket. A waiter that takes none — an older copy of window_lock.sh,
# blocked in flock — may take the window ahead of the queue, never alongside it.

use strict;
use warnings;
use Fcntl qw(:flock);
use IO::Handle;

my ($asker, $queue, $fd, $seconds, $message) = @ARGV;
exit 2 unless defined $message && $fd =~ /^\d+$/ && $seconds =~ /^\d+$/;
my $deadline = $seconds > 0 ? time + $seconds : 0;

mkdir $queue;
exit 2 unless -d $queue;
open(my $window, ">&=", $fd) or exit 2;

# The ticket: the counter's next number, its file made and locked under the counter's
# lock.
my $counter_path = "$queue/counter";
{
	open(my $touch, ">>", $counter_path) or exit 2;
	close $touch;
}
open(my $counter, "+<", $counter_path) or exit 2;
flock($counter, LOCK_EX) or exit 2;
my $last = <$counter>;
my $number = (defined $last && $last =~ /^(\d+)/ ? $1 : 0) + 1;
seek($counter, 0, 0) or exit 2;
truncate($counter, 0) or exit 2;
print {$counter} "$number\n";
$counter->flush or exit 2;
my $ticket_path = "$queue/$number";
open(my $ticket, ">", $ticket_path) or exit 2;
flock($ticket, LOCK_EX | LOCK_NB) or exit 2;
close $counter;

# Its ticket let go of and its file removed: once it holds the window, or ends without.
my $ticketed = 1;
sub drop_ticket {
	return unless $ticketed;
	$ticketed = 0;
	close $ticket;
	unlink $ticket_path;
}
END { drop_ticket(); }

# How many tickets ahead of this one have a live waiter; those that have none are
# removed.
sub ahead {
	opendir(my $dir, $queue) or return 0;
	my @numbers = grep { /^\d+$/ && $_ < $number } readdir $dir;
	closedir $dir;
	my $live = 0;
	for my $other (@numbers) {
		open(my $fh, "+<", "$queue/$other") or next;
		if (flock($fh, LOCK_EX | LOCK_NB)) {
			flock($fh, LOCK_UN);
			close $fh;
			unlink "$queue/$other";
			next;
		}
		close $fh;
		$live++;
	}
	return $live;
}

my $said = 0;
while (1) {
	exit 3 unless kill(0, $asker);
	my $live = ahead();
	if ($live == 0 && flock($window, LOCK_EX | LOCK_NB)) {
		drop_ticket();
		STDOUT->autoflush(1);
		print "locked\n";
		exit 0;
	}
	unless ($said) {
		my $place = $live ? "; $live ahead of it in the queue" : "";
		print STDERR "$message$place\n";
		$said = 1;
	}
	exit 1 if $deadline && time >= $deadline;
	select(undef, undef, undef, 0.5);
}
