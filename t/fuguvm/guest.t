#!/usr/bin/env perl
# ex:ts=8 sw=4:

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Fugu::TestLog;
use File::Temp qw(tempdir);

# The load is a hard failure, not a skip. Fugu::SSH requires Net::SSH2
# lazily, so this module loads with core Perl alone: an eval guard here
# could only ever hide a rename or a syntax error, which are the two
# failures it must report.
use_ok('App::FuguVM::Guest');

# Memory and CPU constants
{
	ok(defined &App::FuguVM::Guest::MEMORY_DEFAULT, 'MEMORY_DEFAULT defined');
	is(App::FuguVM::Guest::MEMORY_DEFAULT(), '1G', 'Default memory is 1G');
	ok(defined &App::FuguVM::Guest::CPU_COUNT, 'CPU_COUNT defined');
	is(App::FuguVM::Guest::CPU_COUNT(), 2, 'Default CPU count is 2');
}

# Exit code constants
{
	is(App::FuguVM::Guest::EXIT_SUCCESS(), 0, 'EXIT_SUCCESS is 0');
	is(App::FuguVM::Guest::EXIT_ERROR(), 1, 'EXIT_ERROR is 1');
	is(App::FuguVM::Guest::EXIT_CONFIG_ERROR(), 3,
	    'EXIT_CONFIG_ERROR is 3');
	is(App::FuguVM::Guest::EXIT_VM_RUNNING(), 5, 'EXIT_VM_RUNNING is 5');
	is(App::FuguVM::Guest::EXIT_TIMEOUT(), 7, 'EXIT_TIMEOUT is 7');
}

# The configured architecture, at the boundary the loader validated
{
	my $vm = App::FuguVM::Guest->new(config => { arch => 'amd64' });
	is($vm->_arch->name, 'amd64',
	    '_arch returns the object of the configured value');
	is($vm->_arch->qemu_binary, 'qemu-system-x86_64',
	    'and the object carries the table');

	my $broken = App::FuguVM::Guest->new(config => { arch => 'mips64' });
	ok(!eval { $broken->_arch; 1 },
	    '_arch dies on an unknown value: the loader is the boundary');
	like($@, qr/unknown architecture/, 'and the death names the cause');
}

# Accelerator selection
{
	# --emulate always forces TCG with the named CPU model of the
	# architecture
	for my $case (['arm64', 'cortex-a57'], ['amd64', 'qemu64']) {
		my ($arch, $tcg_cpu) = @$case;
		my $emulated = App::FuguVM::Guest->new(
			emulate => 1,
			config  => { arch => $arch },
		);
		my %args = ($emulated->_accel_args);
		is($args{'-accel'}, 'tcg', "--emulate forces TCG for $arch");
		is($args{'-cpu'}, $tcg_cpu,
		    "TCG pairs with the $arch model, not host passthrough");
	}

	# Auto-selection returns a consistent accel/cpu pair
	my $auto = App::FuguVM::Guest->new(config => { arch => 'arm64' });
	my %args = ($auto->_accel_args);
	like($args{'-accel'}, qr/^(hvf|kvm|tcg)$/, 'known accelerator');
	if ($args{'-accel'} eq 'tcg') {
		is($args{'-cpu'}, 'cortex-a57',
		    'software emulation pairs with a named CPU');
	} else {
		is($args{'-cpu'}, 'host',
		    'hardware acceleration pairs with host CPU');
	}

	# The host arch helper returns a non-empty machine string
	ok(length(App::FuguVM::Guest::_host_arch()), 'host arch detected');
}

# The QEMU binary lookup on PATH
{
	my $bindir = tempdir(CLEANUP => 1);
	local $ENV{PATH} = $bindir;

	my $vm = App::FuguVM::Guest->new(config => { arch => 'amd64' });
	is($vm->_qemu_path, undef,
	    '_qemu_path returns undef when PATH holds no such binary');

	my $stub = "$bindir/qemu-system-x86_64";
	open my $fh, '>', $stub or die "Cannot write $stub: $!";
	print $fh "#!/bin/sh\n";
	close $fh;
	chmod 0755, $stub or die "Cannot chmod $stub: $!";

	is($vm->_qemu_path, $stub,
	    '_qemu_path returns the path of an executable stub');

	# up and start diagnose the absent binary with exit code 3
	my $arm = App::FuguVM::Guest->new(config =>
	    { name => 'default', arch => 'arm64' });
	$arm->{log} = TestLog->new;
	is($arm->start, App::FuguVM::Guest::EXIT_CONFIG_ERROR(),
	    'start exits 3 when the QEMU binary is absent');
	like(join("\n", @{ $arm->{log}{errors} }),
	    qr/qemu-system-aarch64.*arm64/,
	    'and the message names the binary and the architecture');
	is($arm->up, App::FuguVM::Guest::EXIT_CONFIG_ERROR(),
	    'up exits 3 the same way');
}

# The firmware search returns undef, or a code file that exists with
# its variable-store template
{
	my $vm = App::FuguVM::Guest->new(config => { arch => 'amd64' });
	my $firmware = $vm->_find_efi_firmware;
	ok(!defined $firmware || -f $firmware->{code},
	    '_find_efi_firmware returns undef or a code file that exists');
	ok(!defined $firmware || -f $firmware->{vars},
	    'and an amd64 result carries its variable-store template');
}

# The firmware arguments: -bios without a variable store, and two
# pflash devices with one
{
	my $state_dir = tempdir(CLEANUP => 1);
	my $vars = "$state_dir/template-vars.fd";
	open my $fh, '>', $vars or die "Cannot write $vars: $!";
	print $fh 'vars';
	close $fh;

	require App::FuguVM::State;
	my $state = App::FuguVM::State->new($state_dir, 'default');
	my $vm = App::FuguVM::Guest->new(
	    config => { name => 'default', arch => 'amd64' },
	    state  => $state,
	);

	is_deeply([$vm->_firmware_args({ code => '/x/code.fd' })],
	    ['-bios', '/x/code.fd'],
	    'a code file without a variable store boots with -bios');

	my @args = $vm->_firmware_args(
	    { code => '/x/code.fd', vars => $vars });
	is(scalar @args, 4, 'a pair maps to two pflash devices');
	like($args[1], qr/if=pflash.*readonly=on.*\/x\/code\.fd/,
	    'the code device is read-only');
	my ($copy) = $args[3] =~ /file=(.*)$/;
	ok(-f $copy, 'the variable-store copy exists');
	isnt($copy, $vars, 'and it is a copy, not the template');
}

# A disk belongs to one architecture: up stops when the state records
# an other one
{
	require App::FuguVM::State;

	my $bindir = tempdir(CLEANUP => 1);
	my $stub = "$bindir/qemu-system-x86_64";
	open my $fh, '>', $stub or die "Cannot write $stub: $!";
	print $fh "#!/bin/sh\n";
	close $fh;
	chmod 0755, $stub or die "Cannot chmod $stub: $!";
	local $ENV{PATH} = $bindir;

	my $root = tempdir(CLEANUP => 1);
	my $state = App::FuguVM::State->new("$root/state", 'default');
	$state->mark_installed('arm64');

	my $log = TestLog->new;
	my $vm = App::FuguVM::Guest->new(
		config => { name => 'default', arch => 'amd64' },
		state  => $state,
		log    => $log,
	);
	is($vm->up, App::FuguVM::Guest::EXIT_ERROR(),
	    'up stops on a disk of an other architecture');
	like(join("\n", @{ $log->{errors} }), qr/fuguvm destroy/,
	    'and the message names the remedy');
	is($vm->start, App::FuguVM::Guest::EXIT_ERROR(),
	    'start stops the same way');
}

# status reports the configured architecture
{
	require App::FuguVM::State;

	my $root = tempdir(CLEANUP => 1);
	my $state = App::FuguVM::State->new("$root/state", 'default');
	my $vm = App::FuguVM::Guest->new(
		config => {
			name => 'default', arch => 'amd64',
			ssh_port => 2222, console_port => 4444,
		},
		state => $state,
	);
	is($vm->status->{arch}, 'amd64',
	    'status reports the configured architecture');
}

# Bounded guest interaction: _bounded must return the code's value
# when the code finishes in time. When it does not, _bounded must
# return undef and must not hang. Thus a wedged guest can never
# stall shutdown.
{
	my $vm = App::FuguVM::Guest->new;
	$vm->{log} = TestLog->new;    # swallow the timeout warning

	is($vm->_bounded(5, sub { return 'done' }), 'done',
	    '_bounded returns the code result when it finishes in time');

	my $start = time;
	my $ret = $vm->_bounded(1, sub { sleep 5; return 'late' });
	is($ret, undef, '_bounded returns undef when the deadline elapses');
	ok(time - $start < 4, '_bounded aborts near the deadline, not later');
	ok($vm->{log}{warned}, '_bounded warns on timeout');
}

# The image cache follows the configured cache_dir, which
# App::FuguVM::Config::load_vm injects into the per-VM config.
{
	my $vm = App::FuguVM::Guest->new(config => { cache_dir => '/var/cache/fuguvm' });
	is($vm->_cache_dir, '/var/cache/fuguvm', 'configured cache_dir wins');
	is($vm->_image_cache->installed_dir, '/var/cache/fuguvm/installed',
	    'the image cache uses it too');

	local $ENV{HOME} = '/home/nobody';
	my $bare = App::FuguVM::Guest->new(config => {});
	is($bare->_cache_dir, '/home/nobody/.cache/fuguvm',
	    'a config without cache_dir falls back to the default');
}

# When the cache is off, `up` suppresses restore and save together.
# It derives no key at all. Thus it can neither look one up nor
# publish one.
{
	my $off = App::FuguVM::Guest->new(
		config => { cache_dir => '/var/cache/fuguvm', image_cache => 0 });
	is($off->_image_cache, undef, 'image_cache no disables the cache');

	my $flag = App::FuguVM::Guest->new(
		config   => { cache_dir => '/var/cache/fuguvm' },
		no_cache => 1,
	);
	is($flag->_image_cache, undef, '--no-cache disables the cache');

	my $on = App::FuguVM::Guest->new(
		config => { cache_dir => '/var/cache/fuguvm', image_cache => 1 });
	ok(defined $on->_image_cache, 'image_cache yes leaves it enabled');
}

# Installed-image cache: restore, chain verification, and reparenting.
# These are the parts of `up` that do not need a running QEMU.
SKIP: {
	my $has_qemu = `which qemu-img 2>/dev/null`;
	skip 'qemu-img not installed', 14 unless $has_qemu;

	require App::FuguVM::Disk;
	require App::FuguVM::DiskCache;
	require App::FuguVM::State;

	my $root = tempdir(CLEANUP => 1);
	my $cache = App::FuguVM::DiskCache->new("$root/cache");
	my $key = '7.8-arm64-11223344';

	# A stand-in for a freshly installed disk
	my $installed = "$root/installed.qcow2";
	system('qemu-img', 'create', '-f', 'qcow2', $installed, '64M') == 0
	    or skip 'cannot create a test disk image', 14;
	my $base = $cache->store($key, $installed,
	    { root_password => 'from-the-image' });
	ok(defined $base, 'a base image is available to restore from');

	my $state = App::FuguVM::State->new("$root/state", 'default');
	my $vm = App::FuguVM::Guest->new(
		config => { name => 'default', arch => 'arm64', cache_dir => "$root/cache" },
		state  => $state,
		log    => TestLog->new,
	);

	# Restore: the overlay plus the state that the installation
	# leaves behind
	ok($vm->_cache_restore($cache, $key), 'restore reports a cache hit');
	ok($state->disk_exists, 'the working disk exists after a restore');
	ok($state->is_installed, 'the restored VM is marked installed');
	is($state->get_root_password, 'from-the-image',
	    'the root password comes from the image, not a new install');
	is($state->data->{cached_from}, $key,
	    'state records which cached image it came from');

	my $disk = App::FuguVM::Disk->new("$root/state");
	is($disk->backing_file('default'), $base,
	    'the working disk is an overlay on the cached base');

	# A resolvable chain passes verification
	ok($vm->_verify_backing_chain, 'an intact backing chain verifies');

	# Reparenting a standalone disk onto a base
	my $other = App::FuguVM::State->new("$root/state2", 'default');
	my $vm2 = App::FuguVM::Guest->new(
		config => { name => 'default', arch => 'arm64', cache_dir => "$root/cache" },
		state  => $other,
		log    => TestLog->new,
	);
	App::FuguVM::Disk->new("$root/state2")->create('default', '64M');
	ok($other->disk_exists, 'a standalone disk to reparent');
	ok($vm2->_reparent_disk($base), 'reparent succeeds');
	is(App::FuguVM::Disk->new("$root/state2")->backing_file('default'), $base,
	    'the standalone disk became an overlay');
	ok(!-f $other->disk_path . '.replaced',
	    'no leftover copy of the replaced disk');

	# A missing base is a diagnosed failure, not silent corruption
	chmod 0700, $cache->entry_dir($key);
	unlink $base;
	my $log = TestLog->new;
	$vm->{log} = $log;
	ok(!$vm->_verify_backing_chain, 'a broken chain fails verification');
	like(join("\n", @{ $log->{errors} }), qr/fuguvm destroy/,
	    'and the error names the remedy');

	# A restore against the now-empty cache is a miss, not a crash
	my $fresh = App::FuguVM::State->new("$root/state3", 'default');
	my $vm3 = App::FuguVM::Guest->new(
		config => { name => 'default', arch => 'arm64', cache_dir => "$root/cache" },
		state  => $fresh,
		log    => TestLog->new,
	);
	ok(!$vm3->_cache_restore($cache, $key),
	    'restore misses once the base is gone');
}

done_testing();

# Minimal log stub: it counts warnings for _bounded and keeps errors.
# Thus the tests can assert on diagnostics.
package TestLog;
sub new { return bless { warned => 0, errors => [] }, shift }
sub warning { my $self = shift; $self->{warned}++; return; }
sub info { return; }

sub error
{
	my ($self, $fmt, @args) = @_;
	push @{ $self->{errors} }, @args ? sprintf($fmt, @args) : $fmt;
	return;
}

sub debug { return; }
