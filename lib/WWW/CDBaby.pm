package WWW::CDBaby;

use WWW::Sitebase::Navigator -Base;
use warnings;
use strict;
use Carp;

our $DEBUG = 0;

=head1 NAME

WWW::CDBaby - Automate interaction with cdbaby.com!

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

    my $cdbaby = new WWW::CDBaby( "$account_name", "$password" );
    
    # Print the name of the first person who bought your CD
    my ( @sales ) $cdbaby->get_cd_sales( $album_id );
    print $sales[0]->{'name'};

=cut

field site_info => {
       home_page => 'https://members.cdbaby.com', # URL of site's homepage
       account_field => 'login_username', # Fieldname from the login form
       password_field => 'login_password', # Password fieldname
       cache_dir => '.www-cdbaby',
       login_form_no => 1,
       login_verify_re => 'Members Login HOME', # (optional)
               # Non-case-sensitive RE we should see once we're logged in
       not_logged_in_re => 'LOG IN to your CD Baby',
               # If we log in and it fails (bad password, account suddenly
               # gets logged out), the page will have this RE on it.
               # Case insensitive.
       home_uri_re => 'members\.cdbaby\.com\/home',
               # _go_home uses this and the next two items to load
               # the home page.  You can provide these options or
               # just override the method.
               # First, this is matched against the current URL to see if we're
               # already on the home page.
       home_link_re => 'members\.cdbaby\/com\/home',
               # If we're not on the home page, this RE is
               # used to find a link to the "Home" button on the current
               # page.
       home_url => 'https://members.cdbaby.com/home',
               # If the "Home" button link isn't found, this URL is
               # retreived.
       error_regexs => [
       ],
               # error_regexs is optional.  If the site you're navigating
               # displays  error pages that do not return proper HTTP Status
               # codes (i.e. returns a 200 but displays an error), you can enter
               # REs here and any page that matches will be retried.
               # This is meant for IIS and ColdFusion-based sites that
               # periodically spew error messages that go away when tried again
};


=head1 METHODS

=head2 C<get_cd_sales( album_id )>

Pass this method the URL of your album.  If you can see your
album at "cdbaby.com/amberg", your album_id is "amberg".

It returns an array of hashrefs containing all your physical album sales.
Digital sales are tracked separately.

This method gets the text-delimited file you get if you log into
members.cdbaby.com, click "Accounting", click the "$ sold" amount next
to the album name, and click the "download your sales in a tab-delimited text
file" link.  See how much easier this method is? ;-)

    use WWW::CDBaby;

    my $cdbaby = new WWW::CDBaby;

    my ( @sales ) = $cdbaby->get_cd_sales( $album_id );

    my $total=0;
    foreach $sale ( @sales ) {
        $total += $sale->{'paid_to_you'};
    }
    
    print "Total profits: \$$total\n";

=cut

sub get_cd_sales {

    my ( $album_id ) = @_;

    croak "Must pass an album ID to get_cd_sales" unless ( $album_id );

    my $res = $self->get_page( "http://members.cdbaby.com/show_sales_download/$album_id.txt" )
        or return;
    
    my $page = $res->decoded_content;
    
    # First line is the field names
    my $count = 0;
    my @field_arr = ();
    my @fieldnames = ();
    # Loop through each line.  First line is the field names
    foreach my $line ( split( "\n", $page ) ) {

        # Split the fields into an array.
        my @fields = split( "\t", $line );
        
        # If it's the first row, just store the fieldnames, otherwise
        # process the fields.
        if ( $count ) {
            ( $DEBUG ) && print join("\t", @fields) . "\n";
            
            # Set our counters. We step through each of the @fields array, which
            # contain the values, and the @fieldnames array, which contains the names
            # of the fields, and create a fieldname => value hash for the row.
            my $i=0; my %row = ();
            foreach my $fn ( @fieldnames ) {
                $row{"$fn"} = $fields[ $i ];
                $i++;
            }

            # Add the row we created to the array we'll return
            push ( @field_arr, \%row );
        } else {        
            @fieldnames = @fields
        }

        # This probably could be a flag since it's just used to see if we're on
        # the first row, but it's a counter.
        $count++;
    }

    # We're returning a list of hashrefs.
    return ( @field_arr );

}

=head2 C<get_dd_sales( album_id )>

Pass this method the URL of your album.  If you can see your
album at "cdbaby.com/amberg", your album_id is "amberg".

It returns an array of hashrefs containing your digital distribution
sales and plays for that album.

This method gets the HTML table you get if you Go to the "Digital" tab
and click the amount next to INCOME for one of your albums.  It parses
the HTML into one hash for each row.  The keys to the hash are taken
directly from the headers at the top of the table and modified to make
them program-friendly:

 Leading and trailing whitespace is stripped
 white space is replaced by "_"
 # by itself is turned into "quantity"
 caps are made lower case.
 Any remaining characters that aren't letters, numbers, or _ are stripped

The current keys returned (as of 8/1/2007) are:

 company
 sales_date
 report_date
 song
 price
 quantity
 subtotal

As these keys are taken directly from the headers at the top of the table,
if rows are added or removed or the headers are changed by CD Baby,
the keys to your hash will change accordingly.

Also, the dollar sign ("$") from the price fields is removed so you can
do things like the example below:

    use WWW::CDBaby;

    my $cdbaby = new WWW::CDBaby;

    my ( @sales ) = $cdbaby->get_dd_sales( $album_id );

    my $total=0;
    foreach $sale ( @sales ) {
        $total += $sale->{'subtotal'};
    }
    
    print "Total profits: \$$total\n";

(Note: when I run this script, I get a number slightly lower than
the total shown on the DD page.  This is probably either CD Baby rounding
the numbers (probably up :) or some floating point issue.)

=cut

sub get_dd_sales {

    my ( $album_id ) = @_;
    
    croak "Must pass an album ID to get_dd_sales" unless ( $album_id );
    
    my @fieldnames = ();
    my @field_arr = ();

    ( $DEBUG ) && print "Getting sales page\n";
    my $res = $self->get_page( "https://members.cdbaby.com/accounting?view=ddalbum&a=$album_id" )
        or return;

    ( $DEBUG ) && print "Parsing headers...\n";
    # Get the headers
    my $page = $res->decoded_content;

    while ( $page =~ s/.*?<th>(<a .*?>)?(.*?)<//ismo ) {
        my $fn = $2;
        $fn =~ s/^\s*(.*)\s*$/$1/; # Strip trailing & leading whitespace
        $fn =~ s/\s+/_/g;          # Turn whitespace into _
        $fn =~ s/^#$/no/g;         # Turn a lone "#" into "quantity"
        $fn = lc( $fn );           # Make it all lower case
        $fn =~ s/[^a-z0-9_]//g;    # Strip anything else
        push ( @fieldnames, "$fn" );
        ( $DEBUG ) && print "header: $fn\n";
    }
    ($DEBUG) && print "\n\nParsing sales...\n";

    # Get the rows
    # We ignore the row definitions and just loop through TD tags, applying
    # each one in sequence to the field names in @fieldnames.  When we
    # get to the end of @fieldnames, we store that hash in @field_arr and go on
    # to the next row.
    my $count=0;
    my %row = ();
    while ( $page =~ s/.*?<td>(<a .*?>)?(.*?)<\/td>//ismo ) {
        my $fv = $2;
        $fv =~ s/^\s*(.*)\s*$/$1/; # Strip trailing & leading whitespace
        $fv =~ s/<.*?>//g;  # Strip links
        $fv =~ s/^\$//;     # Strip leading dollar sign (for prices)
        $row{"$fieldnames[$count]"}="$fv";
        ($DEBUG) && print "$fieldnames[$count]: $fv\n";
        $count++;

        if ( $count >= @fieldnames ) {
            # Store the row
            push( @field_arr, { %row } );

            # Reset the counter
            $count=0;
            %row=();
            
            ($DEBUG) && print "\n\n";
        }
    }
    
    return ( @field_arr );
    
}

=head1 AUTHOR

Grant Grueninger, C<< <grantg at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-cdbaby at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-CDBaby>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::CDBaby

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-CDBaby>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-CDBaby>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-CDBaby>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-CDBaby>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Grant Grueninger, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of WWW::CDBaby
