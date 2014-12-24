package DBIx::Schema::Annotate;
use 5.008001;
use strict;
use warnings;
use DBIx::Inspector;
use Smart::Args;
use IO::All;
use Module::Load ();

our $VERSION = "0.04";

our $BLOCK_LINE = '## == Schema Info ==';

sub new {
    args(
        my $class => 'ClassName',
        my $dbh  =>  'DBI::db',
    );

    bless {
        dbh => $dbh,
        driver => '',
        tables => '',
    }, $class;
}

sub driver {
    my $self = shift;
    $self->{driver} ||= do {
        my $driver_class = sprintf('%s::Driver::%s', __PACKAGE__, $self->{dbh}->{Driver}->{Name});
        Module::Load::load($driver_class);
        $driver_class->new(dbh => $self->{dbh});
    };
}

sub tables {
    my $self = shift;
    $self->{tables} ||= do {
        my $inspector = DBIx::Inspector->new(dbh => $self->{dbh});
        my @list;
        for my $info ($inspector->tables) {
            push @list, $info->name;
        }
        \@list;
    };
}

sub get_table_ddl {
    args(
        my $self,
        my $table_name => 'Str',
    );
    return $self->driver->table_ddl(table_name => $table_name);
}

sub clean {
    args(
        my $self,
        my $dir => 'Str',
    );

    for my $table_name (@{$self->tables}) {
        my $f_path = io->catfile($dir, _camelize($table_name).'.pm');
        next unless ( -e $f_path);

        my $io = io($f_path);
        $io->print(do{
            my $content = $io->all;
            $content =~ s/^$BLOCK_LINE.+$BLOCK_LINE\n\n//gms;
            $content;
        });
    }

}

sub write_files {
    args(
        my $self,
        my $dir => 'Str',
    );

    for my $table_name (@{$self->tables}) {
        my $io = io->catfile($dir, _camelize($table_name).'.pm');
        next unless ( -e $io->pathname);

        $io->print(do{
            my $content = $io->all;
            #clean
            $content =~ s/^$BLOCK_LINE.+$BLOCK_LINE\n\n//gms;
            my $ddl = $self->get_table_ddl(table_name => $table_name);

            my $annotate = join(
                "\n" => 
                $BLOCK_LINE,
                (map { '# '.$_} split('\n', $ddl)),
                $BLOCK_LINE
            );

            sprintf("%s\n\n%s",$annotate, $content);
        });
    }
}

sub _camelize {
    my $s = shift;
    join('', map{ ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $s));
}


1;

__END__

=encoding utf-8

=head1 NAME

DBIx::Schema::Annotate - Add table schema as comment to your ORM file. This module is inspired by annotate_models.


=head1 SYNOPSIS

    use DBIx::Schema::Annotate;

    my $dbh = DBI->connect('....') or die $DBI::errstr;
    my $annotate = DBIx::Schema::Annotate->new( dbh => $dbh );
    $annotate->write_files(
      dir       => '...',
      exception_rule => {
        # todo
      }
    );

    # Amon2 + Teng
    $ carton exec -- perl -Ilib -MMyApp -MDBIx::Schema::Annotate -e 'my $c = MyApp->bootstrap; DBIx::Schema::Annotate->new( dbh => $c->db->{dbh})->write_files(dir => q!lib/MyApp/DB/Row/!)'

=head1 DESCRIPTION

Schema is added to pm file of specified path follower of the same camelize name as table.

For example 'post' table and 'post_comment' table exist, and we assume that $self->write_files(dir => $dir) was carried out.
The targets to which DBIx::Schema::Annotate adds a annotate are $dir/Post.pm and $dir/PostComment.pm.

This module is supporting MySQL and SQLite.

=head1 METHODS

=head2 new( dbh => $dbh )

Constructor.

=head2 write_files( dir => 'path/to/...' )

Schema is added to pm file of 'path/to/...' follower of the same camelize name as table.

=head1 LICENSE

Copyright (C) tokubass.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokubass E<lt>tokubass@cpan.orgE<gt>

=cut

