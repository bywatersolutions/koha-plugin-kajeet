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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use JSON qw( encode_json decode_json );
use LWP::UserAgent;
use Koha::Encryption;

sub _api_key {
    my ($self) = @_;

    my $stored = $self->retrieve_data('api_key');
    return unless $stored;

    return Koha::Encryption->new->decrypt_hex($stored);
}

sub _kajeet_request {
    my ( $self, $body ) = @_;

    $self->{_kajeet_ua} //= LWP::UserAgent->new( timeout => 15 );

    my $res = $self->{_kajeet_ua}->post(
        'https://databridge.kajeet.com/v2.0/media/actions',
        'Content-Type' => 'application/json',
        'x-api-key'    => $self->_api_key,
        Content        => encode_json($body),
    );

    die 'Kajeet API error (' . $res->code . '): ' . $res->decoded_content
        unless $res->is_success;

    return length( $res->decoded_content // '' ) ? decode_json( $res->decoded_content ) : undef;
}

1;
