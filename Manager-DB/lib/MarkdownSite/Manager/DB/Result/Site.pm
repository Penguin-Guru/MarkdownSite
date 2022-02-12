use utf8;
package MarkdownSite::Manager::DB::Result::Site;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Manager::DB::Result::Site

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Serializer");

=head1 TABLE: C<site>

=cut

__PACKAGE__->table("site");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'site_id_seq'

=head2 repo

  data_type: 'text'
  is_nullable: 0

=head2 domain

  data_type: 'text'
  is_nullable: 0

=head2 is_enabled

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "site_id_seq",
  },
  "repo",
  { data_type => "text", is_nullable => 0 },
  "domain",
  { data_type => "text", is_nullable => 0 },
  "is_enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<site_domain_key>

=over 4

=item * L</domain>

=back

=cut

__PACKAGE__->add_unique_constraint("site_domain_key", ["domain"]);

=head2 C<site_repo_key>

=over 4

=item * L</repo>

=back

=cut

__PACKAGE__->add_unique_constraint("site_repo_key", ["repo"]);

=head1 RELATIONS

=head2 builds

Type: has_many

Related object: L<MarkdownSite::Manager::DB::Result::Build>

=cut

__PACKAGE__->has_many(
  "builds",
  "MarkdownSite::Manager::DB::Result::Build",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-02-07 00:07:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1dlWgzxdIrmJYkuT4FRPHQ

sub get_builds {
    my ( $self ) = @_;

    return [ map { +{
        id                 => $_->id,
        date               => $_->created_at->strftime( "%F %T %Z" ),
        logs               => $_->get_build_logs,
        is_clone_complete  => $_->is_clone_complete,
        is_build_complete  => $_->is_build_complete,
        is_deploy_complete => $_->is_deploy_complete,
        is_complete        => $_->is_complete,
    } } $self->search_related( 'builds', { }, { order_by => { -DESC => 'created_at' } } ) ];
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
