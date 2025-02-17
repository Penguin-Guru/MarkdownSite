use utf8;
package MarkdownSite::Panel::DB::Result::Site;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MarkdownSite::Panel::DB::Result::Site

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

=head2 person_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 domain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 max_static_file_count

  data_type: 'integer'
  default_value: 100
  is_nullable: 0

=head2 max_static_file_size

  data_type: 'integer'
  default_value: 2
  is_nullable: 0

=head2 max_static_webroot_size

  data_type: 'integer'
  default_value: 50
  is_nullable: 0

=head2 max_markdown_file_count

  data_type: 'integer'
  default_value: 20
  is_nullable: 0

=head2 minutes_wait_after_build

  data_type: 'integer'
  default_value: 10
  is_nullable: 0

=head2 builds_per_hour

  data_type: 'integer'
  default_value: 3
  is_nullable: 0

=head2 builds_per_day

  data_type: 'integer'
  default_value: 12
  is_nullable: 0

=head2 build_priority

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 can_change_domain

  data_type: 'boolean'
  default_value: false
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
  "person_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "domain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "max_static_file_count",
  { data_type => "integer", default_value => 100, is_nullable => 0 },
  "max_static_file_size",
  { data_type => "integer", default_value => 2, is_nullable => 0 },
  "max_static_webroot_size",
  { data_type => "integer", default_value => 50, is_nullable => 0 },
  "max_markdown_file_count",
  { data_type => "integer", default_value => 20, is_nullable => 0 },
  "minutes_wait_after_build",
  { data_type => "integer", default_value => 10, is_nullable => 0 },
  "builds_per_hour",
  { data_type => "integer", default_value => 3, is_nullable => 0 },
  "builds_per_day",
  { data_type => "integer", default_value => 12, is_nullable => 0 },
  "build_priority",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "can_change_domain",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
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

=head1 RELATIONS

=head2 builds

Type: has_many

Related object: L<MarkdownSite::Panel::DB::Result::Build>

=cut

__PACKAGE__->has_many(
  "builds",
  "MarkdownSite::Panel::DB::Result::Build",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 domain

Type: belongs_to

Related object: L<MarkdownSite::Panel::DB::Result::Domain>

=cut

__PACKAGE__->belongs_to(
  "domain",
  "MarkdownSite::Panel::DB::Result::Domain",
  { id => "domain_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 person

Type: belongs_to

Related object: L<MarkdownSite::Panel::DB::Result::Person>

=cut

__PACKAGE__->belongs_to(
  "person",
  "MarkdownSite::Panel::DB::Result::Person",
  { id => "person_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 repoes

Type: has_many

Related object: L<MarkdownSite::Panel::DB::Result::Repo>

=cut

__PACKAGE__->has_many(
  "repoes",
  "MarkdownSite::Panel::DB::Result::Repo",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 site_attributes

Type: has_many

Related object: L<MarkdownSite::Panel::DB::Result::SiteAttribute>

=cut

__PACKAGE__->has_many(
  "site_attributes",
  "MarkdownSite::Panel::DB::Result::SiteAttribute",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-04-04 14:48:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X2lGsCjvYxuVacOwaoVjlw

sub attr {
    my ( $self, $attr, $value ) = @_;

    if ( defined $value ) {
        my $rs = $self->find_or_new_related( 'site_attributes', { name => $attr } );
        $rs->value( ref $value ? $value : { value => $value } );

        $rs->update if     $rs->in_storage;
        $rs->insert unless $rs->in_storage;

        return $value;
    } else {
        my $result = $self->find_related('site_attributes', { name => $attr });
        return undef unless $result;
        return $self->_get_attr_value($result);
    }
}

sub _get_attr_value {
    my ( $self, $attr ) = @_;

    if ( ref $attr->value eq 'HASH' and keys %{$attr->value} == 1 and exists $attr->value->{value} ) {
        return $attr->value->{value};
    }

    return $attr->value;
}

sub get_attrs {
    my ( $self ) = @_;

    my $return = {};

    foreach my $attr ( $self->search_related( 'site_attributes', {} )->all ) {
        $return->{${\($attr->name)}} = $self->_get_attr_value($attr);
    }

    return $return;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
