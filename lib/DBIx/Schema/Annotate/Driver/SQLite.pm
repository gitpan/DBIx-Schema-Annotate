package DBIx::Schema::Annotate::Driver::SQLite;
use parent 'DBIx::Schema::Annotate::Driver::Base';
use Smart::Args;

sub table_ddl {
    args(
        my $self,
        my $table_name => 'Str',
    );

    my $schema_row = do {
        my $sth = $self->{dbh}->prepare(q! SELECT * FROM sqlite_master WHERE type='table' and name = ? !);
        $sth->execute($table_name);
        $sth->fetchrow_hashref;
    };
    my $index_row = do {
        my $sth = $self->{dbh}->prepare(q! SELECT * FROM sqlite_master WHERE type='index' and tbl_name = ? !);
        $sth->execute($table_name);
        $sth->fetchrow_hashref;
    };

    return $schema_row->{sql} unless $index_row->{sql};
    return join("\n", $schema_row->{sql}, $index_row->{sql} || '' );
}

1;

