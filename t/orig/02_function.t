#!perl -w

# This test originally comes from the Hash-Util-FieldHash distribution

use strict;
use Test::More tests => 41;

use Hash::FieldHash qw(:all);

#########################


# define ref types to use with some tests
my @test_types;
BEGIN {
    # skipping CODE refs, they are differently scoped
    @test_types = qw( SCALAR ARRAY HASH GLOB);
}

### existence/retrieval/deletion
{
    no warnings 'misc';
    my $val = 123;
    fieldhash my %h;
    for ( [ ref => {}] ) {
        my ( $keytype, $key) = @$_;
        $h{ $key} = $val;
        ok( exists $h{ $key},  "existence ($keytype)");
        is( $h{ $key}, $val,   "retrieval ($keytype)");
        delete $h{ $key};
        is( keys %h, 0, "deletion ($keytype)");
    }
}

### id-action (stringification independent of bless)
{
    my( %f, %g, %h, %i);
    fieldhashes \(%f, %g);
    my $val = 123;
    my $key = [];
    $f{ $key} = $val;
    is( $f{ $key}, $val, "plain key set in field");
    bless $key;
    is( $f{ $key}, $val, "access through blessed");
    $key = [];
    $h{ $key} = $val;
    is( $h{ $key}, $val, "plain key set in hash");
    bless $key;
    isnt( $h{ $key}, $val, "no access through blessed");
}

{
    my %h;
    fieldhash %h;
    $h{ []} = 123;
    is( keys %h, 0, "blip");
}

for my $preload ( [], [ map {}, 1 .. 3] ) {
    my $pre = @$preload ? ' (preloaded)' : '';
    my %f;
    fieldhash %f;
    my @preval = map "$_", @$preload;
    @f{ @$preload} = @preval;
    # Garbage collection separately
    for my $type ( @test_types) {
        {
            my $ref = gen_ref( $type);
            $f{ $ref} = $type;
            my ( $val) = grep $_ eq $type, values %f;
            is( $val, $type, "$type visible$pre");
        }
        is( keys %f, @$preload, "$type gone$pre");
    }
    
    # Garbage collection collectively
    {
        my @refs = map gen_ref( $_), @test_types;
        @f{ @refs} = @test_types;
        ok(
            eq_set( [ values %f], [ @test_types, @preval]),
            "all types present$pre",
        );
    }
    die "preload gone" unless defined $preload;
    ok( eq_set( [ values %f], \ @preval), "all types gone$pre");
}

# autovivified key
{
    my %h;
    fieldhash %h;
    my $ref = {};
    my $x = $h{ $ref}->[ 0];
    is keys %h, 1, "autovivified key present";
    undef $ref;
    is keys %h, 0, "autovivified key collected";
}
    
# big key sets
{
    my $size = 10_000;
    my %f;
    fieldhash %f;
    {
        my @refs = map [], 1 .. $size;
        $f{ $_} = 1 for @refs;
        is( keys %f, $size, "many keys singly");
    }
    is( keys %f, 0, "many keys singly gone");
    
    {
        my @refs = map [], 1 .. $size;
        @f{ @refs } = ( 1) x @refs;
        is( keys %f, $size, "many keys at once");
    }
    is( keys %f, 0, "many keys at once gone");
}

# many field hashes
{
    my $n_fields = 1000;
    my @fields = map {}, $n_fields;
    fieldhashes @fields;
    my @obs = map gen_ref( $_), @test_types;
    my $n_obs = @obs;
    for my $field ( @fields ) {
        @{ $field }{ @obs} = map ref, @obs;
    }
    my $err = grep keys %$_ != @obs, @fields;
    is( $err, 0, "$n_obs entries in $n_fields fields");
    pop @obs;
    $err = grep keys %$_ != @obs, @fields;
    is( $err, 0, "one entry gone from $n_fields fields");
    @obs = ();
    $err = grep keys %$_ != @obs, @fields;
    is( $err, 0, "all entries gone from $n_fields fields");
}


# direct hash assignment
{
    fieldhashes \my( %f, %g, %h);
    my $size = 6;
    my @obs = map [], 1 .. $size;
    @f{ @obs} = ( 1) x $size;
    $g{ $_} = $f{ $_} for keys %f; # single assignment
    %h = %f;                       # wholesale assignment
    @obs = ();
    is keys %f, 0, "orig garbage-collected";
    is keys %g, 0, "single-copy garbage-collected";
    is keys %h, 0, "wholesale-copy garbage-collected";
}

{
    fieldhash my %h;
    bless \ %h, 'abc'; # this bus-errors with a certain bug
    ok( 1, "no bus error on bless")
}

#######################################################################

use Symbol qw( gensym);

BEGIN {
    my %gen = (
        SCALAR => sub { \ my $o },
        ARRAY  => sub { [] },
        HASH   => sub { {} },
        GLOB   => sub { gensym },
        CODE   => sub { sub {} },
    );

    sub gen_ref { $gen{ shift()}->() }
}
