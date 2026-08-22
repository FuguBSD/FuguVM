#!/usr/bin/env perl
# ex:ts=8 sw=4:

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use File::Temp qw(tempdir);
use File::Path qw(make_path);

use_ok('App::FuguVM::Miniroot');

# Test constants
is(App::FuguVM::Miniroot::CDN_HOST(), 'cdn.openbsd.org',
    'CDN_HOST is correct');

# The architecture comes from the constructor, not from a constant
ok(!App::FuguVM::Miniroot->can('ARCH'),
    'the ARCH constant is gone with the directive');

# download() only warns when the helper is missing. Thus a rename
# degrades silently to "no download" instead of a failure. Assert
# that the path still resolves.
ok(-f App::FuguVM::Miniroot::_ftp_script(),
    'the ftp helper resolves to a file');

# Test object creation
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $image = App::FuguVM::Miniroot->new($tmpdir, undef, 'arm64');
    ok(defined $image, 'Image object created');
}

# A construction without an architecture is a programming error
{
    ok(!eval { App::FuguVM::Miniroot->new('/tmp', undef, undef); 1 },
	'new with no architecture dies');
}

# Test url generation, for each architecture
{
    my $tmpdir = tempdir(CLEANUP => 1);

    my $arm64 = App::FuguVM::Miniroot->new($tmpdir, undef, 'arm64');
    is($arm64->url('7.8'),
       'https://cdn.openbsd.org/pub/OpenBSD/7.8/arm64/miniroot78.img',
       'the arm64 URL holds the arm64 path segment');

    my $amd64 = App::FuguVM::Miniroot->new($tmpdir, undef, 'amd64');
    is($amd64->url('7.8'),
       'https://cdn.openbsd.org/pub/OpenBSD/7.8/amd64/miniroot78.img',
       'the amd64 URL holds the amd64 path segment');

    like($arm64->url('7.8'), qr{/miniroot78\.img$},
       'the file name is the same for both architectures');
    like($amd64->url('7.8'), qr{/miniroot78\.img$},
       'only the path segment differs');
}

# Test image filename generation
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $image = App::FuguVM::Miniroot->new($tmpdir, undef, 'arm64');

    my $filename = $image->_image_filename('7.8');
    is($filename, 'miniroot78.img', 'Image filename generated correctly');
}

# Test path returns undef for missing image
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $image = App::FuguVM::Miniroot->new($tmpdir, undef, 'arm64');

    my $path = $image->path('7.8');
    is($path, undef, 'path returns undef for missing image');
}

# Test path returns path for cached image
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $image = App::FuguVM::Miniroot->new($tmpdir, undef, 'arm64');
    
    # Create a fake cached image in the proxy cache structure
    my $cache_path = "$tmpdir/proxy/cdn.openbsd.org/pub/OpenBSD/7.8/arm64";
    make_path($cache_path);
    open my $fh, '>', "$cache_path/miniroot78.img";
    print $fh "fake image content";
    close $fh;
    
    my $path = $image->path('7.8');
    ok(defined $path, 'path returns path for cached image');
    like($path, qr/miniroot78\.img$/, 'path ends with correct filename');
}

done_testing();
