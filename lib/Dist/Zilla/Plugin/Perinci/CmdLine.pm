package Dist::Zilla::Plugin::Perinci::CmdLine;

use 5.010001;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

# AUTHORITY
# DATE
# DIST
# VERSION

with (
    'Dist::Zilla::Role::BeforeBuild',
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':InstallModules'],
    },
);

use File::Spec::Functions qw(catfile);

# either provide filename or filename+filecontent
sub _get_abstract_from_meta_summary {
    my ($self, $filename, $filecontent) = @_;

    local @INC = @INC;
    unshift @INC, 'lib';

    unless (defined $filecontent) {
        $filecontent = do {
            open my($fh), "<", $filename or die "Can't open $filename: $!";
            local $/;
            ~~<$fh>;
        };
    }

    unless ($filecontent =~ m{^#[ \t]*ABSTRACT:[ \t]*([^\n]*)[ \t]*$}m) {
        $self->log_debug(["Skipping %s: no # ABSTRACT", $filename]);
        return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
    }

    my $abstract = $1;
    if ($abstract =~ /\S/) {
        $self->log_debug(["Skipping %s: Abstract already filled (%s)", $filename, $abstract]);
        return $abstract;
    }

    my $pkg;
    if (!defined($filecontent)) {
        (my $mod_p = $filename) =~ s!^lib/!!;
        require $mod_p;

        # find out the package of the file
        ($pkg = $mod_p) =~ s/\.pm\z//; $pkg =~ s!/!::!g;
    } else {
        eval $filecontent; ## no critic: BuiltinFunctions::ProhibitStringyEval
        die if $@;
        if ($filecontent =~ /\bpackage\s+(\w+(?:::\w+)*)/s) {
            $pkg = $1;
        } else {
            die "Can't extract package name from file content";
        }
    }

    my $meta = $pkg->meta;

    return $meta->{summary} if $meta->{summary};
}

# dzil also wants to get abstract for main module to put in dist's
# META.{yml,json}
sub before_build {
   my $self  = shift;
   my $name  = $self->zilla->name;
   my $class = $name; $class =~ s{ [\-] }{::}gmx;
   my $filename = $self->zilla->_main_module_override ||
       catfile( 'lib', split m{ [\-] }mx, "${name}.pm" );

   $filename or die 'No main module specified';
   -f $filename or die "Path ${filename} does not exist or not a file";
   my $abstract = $self->_get_abstract_from_meta_summary($filename);
   return unless $abstract;

   $self->zilla->abstract($abstract);
   return;
}

sub munge_files {
    my $self = shift;
    $self->munge_file($_) for @{ $self->found_files };
}

sub munge_file {
    my ($self, $file) = @_;
    my $content = $file->content;

    unless ($file->isa("Dist::Zilla::File::OnDisk")) {
        $self->log_debug(["skipping %s: not an ondisk file, currently generated file is assumed to be OK", $file->name]);
        return;
    }

    $self->log_debug(["Processing %s ...", $file->name]);

    my $pkg = do {
        my $pkg = $file->name;
        $pkg =~ s!^lib/!!;
        $pkg =~ s!\.pm$!!;
        $pkg =~ s!/!::!g;
        $pkg;
    };

    if ($pkg =~ /\APerinci::CmdLine::Plugin::/) {

        my $abstract = $self->_get_abstract_from_meta_summary($file->name, $file->content);

        my $meta = $pkg->meta;

      SET_ABSTRACT:
        {
            last unless $abstract;
            $content =~ s{^#\s*ABSTRACT:.*}{# ABSTRACT: $abstract}m
                or die "Can't insert abstract for " . $file->name;
            $self->log(["inserting abstract for %s (%s)", $file->name, $abstract]);
            $file->content($content);
        } # SET_ABSTRACT

    } else {
    }

}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Plugin to use when building Perinci::CmdLine::* distributions

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<dist.ini>:

 [Perinci::CmdLine]


=head1 DESCRIPTION

This plugin is to be used when building C<Perinci::CmdLine::*> distributions. It
currently does the following:

For each F<Perinci/CmdLine/Plugin/*.pm> file:

=over

=item * Fill the Abstract from the metadata's summary

=back


=head1 SEE ALSO

L<Perinci::CmdLine>

L<Pod::Weaver::Plugin::Perinci::CmdLine>
