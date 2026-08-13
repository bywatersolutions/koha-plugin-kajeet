package Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha;

# Kajeet DataBridge API methods - same package, separate file

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
