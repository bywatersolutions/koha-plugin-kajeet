package Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha;

# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.


use Modern::Perl;

use Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::API;
use Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::BackgroundJob;

use base qw(Koha::Plugins::Base);

use JSON qw( encode_json decode_json );
use Koha::DateUtils qw( dt_from_string );
use Try::Tiny;
use Koha::Encryption;
use Koha::ItemTypes;

our $VERSION = "0.0.1";

our $metadata = {
    name             => 'Kajeet API plugin',
    author           => 'ByWater Solutions',
    description      => 'A plugin to integrate Kajeet services with Koha',
    date_authored    => '2026-07-13',
    date_updated     => '2026-07-13',
    minimum_version  => '25.1100000',
    maximum_version  => '28.1199000',
    version          => $VERSION,
    namespace        => 'kajeet',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);

    return $self;
}

sub install {
    my ( $self, $args ) = @_;

    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;

    return 1;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        my $stored_itemtypes = $self->retrieve_data('itemtypes');
        my %selected =
            map { $_ => 1 }
            @{ $stored_itemtypes ? decode_json($stored_itemtypes) : [] };

        $template->param(
            api_key_is_set     => ( $self->retrieve_data('api_key') ? 1 : 0 ),
            selected_itemtypes => \%selected,
            itemtypes          => Koha::ItemTypes->search_with_localization,
            item_field_for_imei => $self->retrieve_data('item_field_for_imei'),
        );

        return $self->output_html( $template->output() );
    }

    my $data = {
        itemtypes => encode_json( [ $cgi->multi_param('itemtypes') ] ),
        item_field_for_imei => scalar $cgi->param('item_field_for_imei'),
    };

    # Only replace the stored key when a new one is entered.
    my $new_key = scalar $cgi->param('api_key');
    if ( defined $new_key && length $new_key ) {
        $data->{api_key} = Koha::Encryption->new->encrypt_hex($new_key);
    }

    $self->store_data($data);

    return $self->go_home();
}

sub intranet_head {
    my ( $self ) = @_;
    
    return;
}

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;
    return 'bywatersolutions_kajeettokoha';
}

=head3 background_tasks
     
Plugin hook used to register new background_job types
    
=cut

sub background_tasks {
    return {
        device_action => 'Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::BackgroundJob',
    };
}

sub after_circ_action {
    my ( $self, $params ) = @_;

    my $action = $params->{action};
    if ( $action eq 'checkout' ) {
        my $checkout = $params->{payload}->{checkout};
        my $checkout_item = $checkout->item;
        my $itemtype = $checkout_item->effective_itemtype;
        my $due = dt_from_string( $checkout->date_due )->strftime('%m/%d/%Y'); 

        return unless $self->_itemtype_is_configured($itemtype);

        my $item_field = $self->retrieve_data('item_field_for_imei');
        return unless $item_field;

        try {
            Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::BackgroundJob->new->enqueue({
                action_type => 'checkout',
                imei        => $checkout_item->$item_field,
                borrower_id => $checkout->borrowernumber,
                due_date    => $due,
            });
        }
        catch {
            warn "Problem activating the Kajeet device: $_";
        };
    }

    if ( $action eq 'checkin' ) {
        my $checkin = $params->{payload}->{checkout};
        my $checkin_item = $checkin->item;
        my $itemtype = $checkin_item->effective_itemtype;

        return unless $self->_itemtype_is_configured($itemtype);

        my $item_field = $self->retrieve_data('item_field_for_imei');
        return unless $item_field;
        try {
            Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::BackgroundJob->new->enqueue({
                action_type => 'checkin',
                imei        => $checkin_item->$item_field,
            });
        }
        catch {
            warn "Problem deactivating the Kajeet device: $_";
        };
    }
    return;
}

# a way to check if the item type is configured to be a hotspot that should be activated/deactived 
sub _itemtype_is_configured {
    my ( $self, $itemtype ) = @_;
    my $stored = $self->retrieve_data('itemtypes');
    return 0 unless $stored && $itemtype;
    my %configured = map { $_ => 1 } @{ decode_json($stored) };
    return exists $configured{$itemtype} ? 1 : 0;
}

