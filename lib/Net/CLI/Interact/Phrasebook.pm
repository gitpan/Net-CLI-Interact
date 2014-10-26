package Net::CLI::Interact::Phrasebook;
BEGIN {
  $Net::CLI::Interact::Phrasebook::VERSION = '1.111150';
}

use Moose;
use Net::CLI::Interact::ActionSet;

has 'logger' => (
    is => 'ro',
    isa => 'Net::CLI::Interact::Logger',
    required => 1,
);

has 'personality' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'library' => (
    is => 'ro',
    isa => 'Str|ArrayRef[Str]',
    lazy_build => 1,
    required => 0,
);

sub _build_library {
    use File::Basename;
    my (undef, $directory, undef) = fileparse(
        $INC{ 'Net/CLI/Interact.pm' }
    );
    return [ Path::Class::Dir->new($directory)
        ->subdir("Interact", "phrasebook")->stringify ];
}

has 'add_library' => (
    is => 'ro',
    isa => 'Str|ArrayRef[Str]',
    default => sub { [] },
    required => 0,
);

has '_prompt' => (
    is => 'ro',
    isa => 'HashRef[Net::CLI::Interact::ActionSet]',
    default => sub { {} },
    required => 0,
);

sub prompt {
    my ($self, $name) = @_;
    confess "missing prompt argument!" unless defined $name;
    confess "unknown prompt [$name]"
        unless length $name and exists $self->_prompt->{$name};
    return $self->_prompt->{$name};
}

sub prompt_names { return keys %{ (shift)->_prompt } }

has '_macro' => (
    is => 'ro',
    isa => 'HashRef[Net::CLI::Interact::ActionSet]',
    default => sub { {} },
    required => 0,
);

sub macro {
    my ($self, $name) = @_;
    confess "missing macro argument!" unless defined $name;
    confess "unknown macro [$name]"
        unless length $name and exists $self->_macro->{$name};
    return $self->_macro->{$name};
}

sub macro_names { return keys %{ (shift)->_macro } }

# inflate the hashref into action objects
sub _bake {
    my ($self, $data) = @_;
    return unless ref $data eq ref {} and keys %$data;
    $self->logger->log('phrasebook', 'debug', 'storing', $data->{type}, $data->{name});

    my $slot = '_'. lc $data->{type};
    $self->$slot->{$data->{name}}
        = Net::CLI::Interact::ActionSet->new({
            actions => $data->{actions}
        });
}

# matches which are prompt names are resolved to RegexpRefs
sub _resolve_lazy_matches {
    my $self = shift;

    foreach my $name (keys %{$self->_macro}) {
        my $set = $self->macro($name);
        my $new_set = [];

        $set->reset;
        while ($set->has_next) {
            my $item = $set->next;
            if ($item->is_lazy) {
                push @$new_set, $item->clone({ value =>
                    $self->prompt($item->value)->first->value
                });
            }
            else {
                push @$new_set, $item;
            }
        }

        # direct access to macros hash
        $self->_macro->{$name} = Net::CLI::Interact::ActionSet->new({
            actions => $new_set
        });
    }
}

sub BUILD {
    my $self = shift;
    $self->load_phrasebooks;
}

# parse phrasebook files and load action objects
sub load_phrasebooks {
    my $self = shift;
    my $data = {};

    foreach my $file ($self->_find_phrasebooks) {
        $self->logger->log('phrasebook', 'info', 'reading phrasebook', $file);
        my @lines = $file->slurp;
        while ($_ = shift @lines) {
            # Skip comments and empty lines
            next if m/^(?:#|\s*$)/;

            if (m{^(prompt|macro)\s+(\w+)\s*$}) {
                $self->_bake($data);
                $data = {type => $1, name => $2};
                next;
            }
            # skip new sections we don't yet understand
            elsif (m{^\w}) {
                $_ = shift @lines until m{^(?:prompt|macro)};
                unshift @lines, $_;
                next;
            }

            if (m{^\s+(send(?:_no_ors)?)\s+(.+)$}) {
                my ($type, $value) = ($1, $2);
                $value =~ s/^["']//; $value =~ s/["']$//;
                push @{ $data->{actions} }, {
                    type => 'send', value => $value,
                    no_ors => ($type eq 'send_no_ors')
                };
                next;
            }

            if (m{^\s+match\s+prompt\s+(.+)\s*$}) {
                push @{ $data->{actions} },
                    {type => 'match', value => $1, lazy => 1};
                next;
            }

            if (m{^\s+match\s+/(.+)/\s*$}) {
                push @{ $data->{actions} },
                    {type => 'match', value => qr/$1/};
                next;
            }

            if (m{^\s+follow\s+/(.+)/\s+with\s+(.+)\s*$}) {
                my ($match, $send) = ($1, $2);
                $send =~ s/^["']//; $send =~ s/["']$//;
                $data->{actions}->[-1]->{continuation} = [
                    {type => 'match', value => qr/$match/},
                    {type => 'send',  value => $send, no_ors => 1}
                ];
                next;
            }

            confess "don't know what to do with this phrasebook line:\n", $_;
        }
        # last entry in the file needs baking
        $self->_bake($data);
    }

    $self->_resolve_lazy_matches;
}

# finds the path of Phrasebooks within the Library leading to Personality
# FIXME: *sniff* *sniff* this code seems a bit whiffy
use Path::Class;
sub _find_phrasebooks {
    my $self = shift;
    my @libs = (ref $self->add_library ? @{$self->add_library} : ($self->add_library));
    push @libs, (ref $self->library ? @{$self->library} : ($self->library));

    my $target = undef;
    foreach my $l (@libs) {
        Path::Class::Dir->new($l)->recurse(callback => sub {
            return unless $_[0]->is_dir;
            $target = $_[0] if $_[0]->dir_list(-1) eq $self->personality
        });
        last if $target;
    }
    confess (sprintf "couldn't find Personality '%s' within your Library\n",
            $self->personality) unless $target;

    my @phrasebooks = ();
    my $root = Path::Class::Dir->new($target->is_absolute ? '' : ());
    foreach my $part ( $target->dir_list ) {
        $root = $root->subdir($part);
        next if scalar grep { $root->subsumes($_) } @libs;
        push @phrasebooks,
            sort {$a->basename cmp $b->basename}
            grep { not $_->is_dir } $root->children(no_hidden => 1);
    }

    confess (sprintf "Personality [%s] contains no content!\n",
            $self->personality) unless scalar @phrasebooks;
    return @phrasebooks;
}

1;

# ABSTRACT: Load command phrasebooks from a Library


__END__
=pod

=head1 NAME

Net::CLI::Interact::Phrasebook - Load command phrasebooks from a Library

=head1 VERSION

version 1.111150

=head1 DESCRIPTION

A command phrasebook is where you store the repeatable sequences of commands
which can be sent to connected network devices. An example would be a command
to show the configuration of a device: storing this in a phrasebook (sometimes
known as a dictionary) saves time and effort.

This module implements the loading and preparing of phrasebooks from an
on-disk file-based hierarchical library, and makes them available to the
application as smart objects for use in L<Net::CLI::Interact> sessions.
Entries in the phrasebook will be one of the following types:

=over 4

=item Prompt

Named regular expressions that match the content of a single line of text in
the output returned from a connected device. They are a demarcation between
commands sent and responses returned.

=item Macro

Alternating sequences of command statements sent to the device, and regular
expressions to match the response. There are different kinds of Macro,
explained below.

=back

The named regular expressions used in Prompts and Macros are known as I<Match>
statements. The command statements in Macros which are sent to the device are
known as I<Send> statements. That is, Prompts and Macros are built from one or
more Match and Send statements.

Each Send or Match statement becomes an instance of the
L<Net::CLI::Interact::Action> class. These are built up into Prompts and
Macros, which become instances of the L<Net::CLI::Interact::ActionSet> class.

=head1 USAGE

A phrasebook is a plain text file containing named Prompts or Macros. Each
file exists in a directory hierarchy, such that files "deeper" in the
hierarchy have their entries override the similarly named entries higher up.
For example:

 /dir1/file1
 /dir1/file2
 /dir1/dir2/file3

Entries in C<file3> sharing a name with any entries from C<file1> or C<file2>
will take precedence. Those in C<file2> will also override entries in
C<file1>, because asciibetical sorting places the files in that order, and
later definitions with the same name and type override earlier ones.

When this module is loaded, a I<personality> key is required. This locates a
directory on disk, and then the files in that directory and all its ancestors
in the hierarchy are loaded. The directory root is specified by two I<Library>
options.

=head1 INTERFACE

=head2 new( \%options )

This takes the following options, and returns a loaded phrasebook object:

=over 4

=item C<< personality => $directory >> (required)

The name of a directory component on disk. Any files higher in the libraries
hierarchy are also loaded, but entries in files contained within this
directory, or "closer" to it, will take precedence.

=item C<< library => $directory | \@directories >>

First library hierarchy, specified either as a single directory or a list of
directories that are searched in order. The idea is that this option be set in
your application code, perhaps specifying some directory of phrasebooks
shipped with the distribution.

=item C<< add_library => $directory | \@directories >>

Second library hierarchy, specified either as a single directory or a list of
directories that are searched in order. This parameter is for the end-user to
provide the location(s) of their own phrasebook(s). Any entries found via this
path will override those found via the first C<library> path.

=back

=head2 prompt( $name )

Returns the Prompt associated to the given C<$name>, or throws an exception if
no such prompt can be found. The returned object is an instance of
L<Net::CLI::Interact::ActionSet>.

=head2 prompt_names

Returns a list of the names of the current loaded Prompts.

=head2 macro( $name )

Returns the Macro associated to the given C<$name>, or throws an exception if
no such macro can be found. The returned object is an instance of
L<Net::CLI::Interact::ActionSet>.

=head2 macro_names

Returns a list of the names of the current loaded Macros.

=head1 PHRASEBOOK FORMAT

=head2 Prompt

A Prompt is a named regular expression which matches the content of a single
line of text. Here is an example:

 prompt configure
     match /\(config[^)]*\)# ?$/

On the first line is the keyword C<prompt> followed by the name of the Prompt,
which must be a valid Perl identifier (letters, numbers, underscores only).

On the immediately following line is the keyword C<match> followed by a
regular expression, enclosed in two forward-slash characters. Currently, no
alternate bookend characters are supported, nor are regular expression
modifiers (such as C<xism>) outside of the match, but you can of course
include them within.

The Prompt is used to find out when the connected CLI has emitted all of the
response to a command. Try to make the Prompt as specific as possible,
including line-end anchors. Remember that it will be matched against one line
of text, only.

=head2 Macro

In general, Macros are alternating sequences of commands to send to the
connected CLI, and regular expressions to match the end of the returned
response. Macros are useful for issueing commands which have intermediate
prompts, or confirmation steps. They also support the I<slurping> of
additional output when the connected CLI has split the response into pages.

At its simplest a Macro can be just one command:

 macro show_int_br
     send show ip int br
     match /> ?$/

On the first line is the keyword C<macro> followed by the name of the Macro,
which must be a valid Perl identifier (letters, numbers, underscores only).

On the immediately following line is the keyword C<send> followed by a space
and then any text up until the end of the line, and if you want to include
whitespace at the beginning or end of the command, use quotes. This text is
sent to the connected CLI as a single command statement. The next line
contains the keyword C<match> followed by the Prompt (regular expression)
which will terminate gathering of returned output from the sent command.

Macros support the following features:

=over 4

=item Automatic Matching

Normally, you ought always to specify C<send> statements along with a
following C<match> statement so that the module can tell when the output from
your command has ended. However you can omit any Match and the module will
insert either the current C<prompt> value if set by the user, or the last
Prompt from the last Macro. So the previous example could be re-written as:

 macro show_int_br
     send show ip int br

You can have as many C<send> statements as you like, and the Match statements
will be inserted for you:

 macro show_int_br_and_timestamp
     send show ip int br
     send show clock

However it is recommended that this type of sequence be implemented as
individual commands (or separate Macros) rather than a single Macro, as it
will be easier for you to retrieve the command response(s). Normally the
Automatic Matching is used just to allow missing off of the final Match
statement when it's the same as the current Prompt.

=item Format Interpolation

Each C<send> statement is in fact run through Perl's C<sprintf> command, so
variables may be interpolated into the statement using standard C<"%"> fields.
For example:

 macro show_int_x
     send show interface %s

The method for passing variables into the module upon execution of this Macro
is documented in L<Net::CLI::Interact::Role::Engine>. This feature is useful
for username/password prompts.

=item Named Match References

If you're going to use the same Match (regular expression) in a number of
Macros, then set it up as a Prompt (see above) and refer to it by name,
instead:

 prompt priv_exec
     match /# ?$/
 
 macro to_priv_exec
     send enable
     match /[Pp]assword: ?$/
     send %s
     match prompt priv_exec

As you can see, in the case of the last Match, we have the keywords C<match
prompt> followed by the name of a defined Prompt.

=item Continuations

Sometimes the connected CLI will not know it's talking to a program and so
paginate the output (that is, split it into pages). There is usually a
keypress required between each page. This is supported via the following
syntax:

 macro show_run
     send show running-config
     follow / --More-- / with ' '

On the line following the C<send> statement is the keyword C<follow> and a
regular expression enclosed in forward-slashes. This is the Match which will,
if seen in the command output, trigger the continuation. On the line you then
have the keyword C<with> followed by a space and some text, until the end of
the line. If you need to enclose whitespace use quotes, as in the example.

The module will send the continuation text and gobble the matched prompt from
the emitted output so you only have one complete piece of text returned, even
if split over many pages.

Note that in the above example the C<follow> statement should be seen as an
extension of the C<send> statement. There is still an implicit Match prompt
added at the end of this Macro, as per Automatic Matching, above.

=item Line Endings

Normally all sent command statements are appended with a newline (or the value
of C<ors>, if set). To suppress that feature, use the keyword C<send_no_ors>
instead of C<send>. However this does not prevent the Format Interpolation via
C<sprintf> as described above (simply use C<"%%"> to get a literal C<"%">).

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Oliver Gorwits.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

