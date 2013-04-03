package Kelp::Less;

use Kelp;
use Kelp::Base -strict;

our @EXPORT = qw/
  app
  attr
  route
  get
  post
  put
  run
  param
  stash
  named
  req
  res
  template
  /;

our $app;

sub import {
    my $class  = shift;
    my $caller = caller;
    no strict 'refs';
    for my $sub (@EXPORT) {
        *{"${caller}::$sub"} = eval("\\\&$sub");
    }

    strict->import;
    warnings->import;
    feature->import(':5.10');

    $app = Kelp->new(@_);
    $app->routes->base('main');
}

sub route {
    my ( $path, $to ) = @_;
    $app->add_route( $path, $to );
}

sub get {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ GET => $path ], $to;
}

sub post {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ POST => $path ], $to;
}

sub put {
    my ( $path, $to ) = @_;
    route ref($path) ? $path : [ PUT => $path ], $to;
}

sub run      { $app->run }
sub app      { $app }
sub attr     { Kelp::Base::attr( ref($app), @_ ) }
sub param    { $app->param(@_) }
sub stash    { $app->stash(@_) }
sub named    { $app->named(@_) }
sub req      { $app->req }
sub res      { $app->res }
sub template { $app->res->template(@_) }
sub debug    { $app->debug(@_) }
sub error    { $app->error(@_) }

1;

__END__

=pod

=head1 TITLE

Kelp::Less - Quick prototyping with Kelp

=head1 SYNOPSIS

    use Kelp::Less;

    get '/person/:name' => sub {
        "Hello " . named 'name';
    };

    run;

=head1 DESCRIPTION

This modules exists to provide a way for quick and sloppy prototyping of a web
application. It is a wrapper for L<Kelp>, which imports several keywords, making
it easier and less verbose to create a quick web app.

It's called C<Less>, because there is less typing involved with it, and also
because it is suited for smaller, less complicated web projects. We encourage
you to use it anywhere you see fit, however for mid-size and big applications we
recommend that you use the fully structured L<Kelp>. This way you can take
advantage of the powerful router and initialization.

=head1 QUICK START

Each web app begins with C<use Kelp::Less;>. It automatically imports C<strict>,
C<warnings>, C<v5.10> as well as several useful functions. You can pass any
parameters to the constructor at the C<use> statement:

    use Kelp::Less mode => 'development';

The above is equivalent to:

    use Kelp;
    my $app = Kelp->new( mode => 'development' );

After that, you could add any initializations and attributes. For example, connect
to a database or setup cache. C<Kelp::Less> exports L<attr|Kelp::Base/attr>,
so you can use it to register attributes to your app.

    # Connect to DBI and CHI right away
    attr dbh   => DBI->connect(...);
    attr cache => CHI->new(...);

    # Lazy attribute. The code will be executed when app->version is called.
    attr version => sub {
        app->dbh->selectrow_array("SELECT version FROM vars");
    };

    # Later:
    app->dbh->do(...);
    app->cache->get(...);
    if ( app->version ) { ... }

Now is a good time to add routes. Routes are added via the L</route> keyword and
they are automatically registered in your app. A route needs to parameters -
C<path> and C<destination>. These are exactly equivalent to L<Kelp::Routes/add>,
and you are encouraged to read its POD to get familiar with how to add routes.
Here are a few examples for the impatient:

    # Add a 'catch-all methods' route and send it to an anonymous sub
    route '/hello/:name' => sub {
        return "Hello " . named('name');
    };

    # Add a POST route
    route [ POST => '/edit/:id' ] => sub {
        # Do something with named('id')
    };

    # Route that runs an existing sub in your code
    route '/login' => 'login';
    sub login {
        ...
    }

Each route subroutine receives C<$self> and all named placeholders, so one could
use them, if it makes it easier to understand where it all comes from.

    route '/:id/:page' => sub {
        my ( $self, $id, $page ) = @_;
    };

Here, C<$self> is the app object and it can be used the same way as in a full
L<Kelp> route. For the feeling of magic and eeriness, C<Kelp::Lite> aliases
C<app> to C<$self>, so the former can be used as a full substitute to the
latter. See the exported keywords section for more information.

After you have added all of your routes, it is time to run the app. This is done
via a single command:

    run;

It returns PSGI ready structure, so you can immediately deploy your new app via
Plack:

    % plackup myapp.psgi
    HTTP::Server::PSGI: Accepting connections at http://0:5000/

=head1 KEYWORDS

The following list of keywords are exported to allow for less typing in
C<Kelp::Less>:

=head2 app

This a full alias for C<$self>. It is the application object, and an
instance of the C<Kelp> class. You can use it for anything you would use
C<$self> inside a route.

    route '/yo' => sub {
        app->res->code(500);
    };

=head2 attr

Assigns lazy or active attributes (using L<Kelp::Base>) to C<app>. Use it to
initialize your application.

    attr mongo => MongoDB::MongoClient->new( ... );

=head2 route

Adds a route to C<app>. It is an alias to C<$self->routes->add>, and requires
the exact same parameters. See L<Kelp::Routes> for enlightenment.

    route '/get' => sub { "got" };

=head2 get, post, put

These are shortcuts to C<route> restricted to the corresponding HTTP method.

    get '/data'  => sub { "Only works with GET" };
    post '/data' => sub { "Only works with POST" };
    put '/data'  => sub { "Only works with PUT" };

=head2 param

An alias for C<$self-E<gt>param> that gets the GET or POST parameters.
When used with no arguments, it will return an array with the names of all http
parameters. Otherwise, it will return the value of the requested http parameter.

    get '/names' => sub {
        my @names = param;
        # Now @names contains the names of the params
    };

    get '/value' => sub {
        my $id = param 'id';
        # Now $is contains the value of 'id'
    };

=head2 stash

An alias for C<$self-E<gt>stash>. The stash is a concept originally conceived by the
developers of L<Catalyst>. It's a hash that you can use to pass data from one
route to another.

    # Create a bridge route that checks if the user is authenticated, and saves
    # the username in the stash.
    get '/user' => { bridge => 1, to => sub {
        return stash->{username} = app->authenticate();
    }};

    # This route is run after the above bridge, so we know that we have an
    # authenticated user and their username in the stash.
    get '/user/welcome' => sub {
        return "Hello " . stash 'username';
    };

With no arguments C<stash> returns the entire stash hash. A single argument is
interpreted as the key to the stash hash and its value is returned accordingly.

=head2 named

An alias for C<$self-E<gt>named>. The C<named> hash contains the names and values of
the named placeholders from the current route's path. Much like the C<stash>,
with no arguments it returns the entire C<named> hash, and with a single
argument it returns the value for the corresponding key in the hash.

    get '/:name/:id' => sub {
        my $name = named 'name';
        my $id = name 'id';
    };

In the above example a GET request to C</james/1000> will initialize C<$name>
with C<"james"> and C<$id> with C<1000>.

=head2 req

An alias for C<$self-E<gt>req>, this provides quick access to the
L<Kelp::Request> object for the current route.

    # Inside a route
    if ( req->is_ajax ) {
        ...
    }

=head2 res

An alias for C<$self-E<gt>res>, this is a shortcut for the L<Kelp::Response>
object for the current route.

    # Inside a route
    res->code(403);
    res->json->render({ message => "Forbidden" });

=head2 template

A shortcut to C<$self-E<gt>res-E<gt>template>. Renders a template using the
currently loaded template module.

    get '/hello/:name' => sub {
        template 'hello.tt', { name => named 'name' };
    };

=head2 run

Creates and returns a PSGI ready subroutine, and makes the app ready for C<Plack>.

=head1 SEE ALSO

L<Kelp>

=head1 CREDITS

Author: minimalist - minimal@cpan.org

=head1 ACKNOWLEDGEMENTS

This module's interface was inspired by L<Dancer>.

=head1 LICENSE

Same as Perl itself.

=cut