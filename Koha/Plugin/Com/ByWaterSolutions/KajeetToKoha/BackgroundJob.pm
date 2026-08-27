package Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha::BackgroundJob;

use Modern::Perl;
use JSON qw( encode_json decode_json );
use base 'Koha::BackgroundJob';

use Try::Tiny qw(catch try);

=head3 job_type

Define the job type of this job: greeter

=cut

sub job_type {
    return 'plugin_kajeet_device_action';
}

sub process {
    my ( $self, $args ) = @_;

    $self->start;

    my @messages;

    require Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha;
    my $plugin = Koha::Plugin::Com::ByWaterSolutions::KajeetToKoha->new;

    try {
        my $res = $plugin->_kajeet_request({
            actionType => $args->{action_type},
            imei       => $args->{imei},
            ( $args->{borrower_id} ? ( borrowerId => $args->{borrower_id} ) : () ),
            ( $args->{due_date}    ? ( dueDate    => $args->{due_date} )    : () ),
        });
        push @messages, { type => 'success', code => 'kajeet_ok', message => $res->{message} };
        $self->step;
    }
    catch {
        push @messages, { type => 'error', code => 'kajeet_request_failed', error => "$_" };
        $self->set({ progress => 0, status => 'failed' });
    };

    my $data = $self->decoded_data;
    $data->{messages} = \@messages;

    return $self->finish($data);
}

=head3 enqueue

Enqueue the new job.

=cut

sub enqueue {
    my ( $self, $args ) = @_;

    return $self->SUPER::enqueue({
        job_args => $args,
        job_size => 1,
    });
}

1;
