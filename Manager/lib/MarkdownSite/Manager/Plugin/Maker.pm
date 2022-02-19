package MarkdownSite::Manager::Plugin::Maker;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Minion;
use Mojo::File qw( curfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;
use YAML;

sub register ( $self, $app, $config ) {

    $app->minion->add_task( remove_markdownsite => sub ( $job, $domain ) {
        $job->note( _mds_template => 'remove_markdownsite.tx' );

        my @logs;
        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, '--extra-vars', "domain=$domain", '/etc/ansible/purge-website.yml' ], \undef, \my $out, \my $err );
            $job->note( removed_site => 1 );

            push @logs, "Host: $deploy_address", " ";
            push @logs, "---STDOUT---", " ", split( /\n/, $out );
            push @logs, "---STDERR---", " ", split( /\n/, $err );
        }

        $job->finish( \@logs );
    });

    $app->minion->add_task( build_markdownsite => sub ( $job, $site_id ) {
        $job->note( _mds_template => 'build_markdownsite.tx' );

        my $site = $job->app->db->site( $site_id );

        die "Error: No site found for site_id: $site_id"
            unless $site;

        # Create a directory to build the markdownsite.
        #
        # build-RANDOM/
        #   /src            - Repository cloned from git.
        #   /build          -
        #   /build/html     -
        #   /build/pages    -
        #   /build/site.yml -
        #
        my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 0 );
        $build_dir->child('build')->make_path;

        my @logs;

        #==
        # Clone Repo
        #==
        run3( ['git', 'clone', $site->repo, "$build_dir/src" ], \undef, \my $out, \my $err );
        push @logs, "--- Running: git clone " . $site->repo . " $build_dir/src";
        push @logs, "> STDOUT", " ", split( /\n/, $out );
        push @logs, "> STDERR", " ", split( /\n/, $err );
        push @logs, "--- Done Running: git clone " . $site->repo . " $build_dir/src";

        foreach my $line ( split /\n/, $err ) {
            if ( $line =~ /^fatal: repository \'[^']+\' does not exist$/ ) {
                $job->fail( { error => "Does not seem to be a valid repository.", logs => \@logs });
                return;
            }

            if ( $line =~ /^fatal: Could not read from remote repository\.$/ ) {
                $job->fail( { error => "Error: Permission denied - Valid access and repo?", logs => \@logs });
                return;
            }
        }

        # Load the .markdown.yml config file.
        my $repo_yaml = {};
        if ( -e "$build_dir/src/.markdownsite.yml" ) {
            push @logs, "Loading .markdownsite.yml config.";
            # TODO -- test malformed file / might need try::tiny
            $repo_yaml = YAML::LoadFile( "$build_dir/src/.markdownsite.yml" );
        }

        $repo_yaml->{webroot} ||= 'webroot';
        $repo_yaml->{site}    ||= 'site';
        $repo_yaml->{branch}  ||= 'master';
        $repo_yaml->{domain}  ||= $site->domain;

        my $settings = {
            webroot => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{webroot} ),
            site    => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{site}    ),
            branch  =>  $repo_yaml->{branch},

            ( $repo_yaml->{domain} ne $site->domain
                # We have a domain mismatch, the user wants to change the domain.
                ? (
                    old_domain => $site->domain,
                    domain     => $repo_yaml->{domain},
                )
                # No domain name change..
                : (
                    domain     => $site->domain,
                )
            ),
        };

        # If the branch the user's site is in is not master, switch branches.
        if ( $settings->{branch} ne 'master' ) {
            run3( [ 'git', '-C', "$build_dir/src", 'checkout', $settings->{branch} ], \undef, \my $out, \my $err );

            push @logs, "--- Running: git -C $build_dir/src checkout " . $settings->{branch};
            push @logs, "> STDOUT---", " ", split( /\n/, $out );
            push @logs, "> STDERR---", " ", split( /\n/, $err );
            push @logs, "--- Done Running: git -C $build_dir/src checkout " . $settings->{branch};

            foreach my $line ( split /\n/, $err ) {
                if ( $line =~ /^error: pathspec \'[^']+\' did not match any file\(s\) known to git$/ ) {
                    $job->fail( { error => "Failed to checkout branch " . $settings->{branch}, logs => \@logs });
                    return;
                }
            }
        }

        # The domain name in the user's repo is different than the site's configuration,
        # check if the user is a sponser and if so, remap their domain.
        if ( exists $settings->{old_domain} ) {
            # TODO:
            # check site.is_sponser -> return if false

            # check that domain is a valid domain -> return if false
            if ( $settings->{domain} !~ /^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$/ ) {
                $job->fail( { error => "Invalid domain name " . $settings->{domain}, logs => \@logs });
                return;
            }

            # check that no other site has this domain -> return if false
            if ( $job->app->db->site( { domain => $settings->{domain} } ) ) {
                $job->fail( { error => "Domain name " . $settings->{domain} . " is already in use.", logs => \@logs });
                return;
            }

            push @logs, sprintf("Domain name changed from %s to %s", $settings->{old_domain}, $settings->{domain} );

            $site->domain( $settings->{domain} );
            $site->update;

            # Queue a minion job to purge the current website, associate it with the site builds..
            my $remove_mds_id = $job->app->minion->enqueue( remove_markdownsite => [ $settings->{old_domain} ] => { notes => { '_mds_sid_' . $site->id => 1 } } );
            $site->create_related( 'builds', { job_id => $remove_mds_id } );

            # Queue a job to build this site, and then exit this job.
            my $build_mds_id = $job->app->minion->enqueue( build_markdownsite => [ $site->id ] => { notes => { '_mds_sid_' . $site->id => 1 } });
            $site->create_related( 'builds', { job_id => $build_mds_id } );

            push @logs, "Domain name updated -- scheduling new jobs for purge/import and returning.";

            $job->finish( \@logs );
            return;
        }

        $job->note( is_clone_complete => 1 );

        #==
        # Build Static Files For Webroot
        #==
        if ( -d $settings->{webroot} ) {
            push @logs, "--- Processing Static Files ---";

            my $files = Mojo::File->new( $settings->{webroot} )->list_tree;

            if ( $files->size > $site->max_static_file_count ) {
                $job->fail( {
                    error => "This site may have up to " . $site->max_static_file_count . " static files, however the webroot contains " . $files->size . " files.",
                    logs => \@logs
                });
                return;
            }

            my $total_file_size = 0;

            foreach my $file ( $files->each ) {
                # Does file exceed size allowed?
                if ( $file->stat->size >= ( $site->max_static_file_size * 1024 * 1024 ) ) {
                    $job->fail( {
                        error => sprintf("This site may have static files up to %d MiB, however %s exceeds this limit.",
                            $site->max_static_file_size,
                            $file->to_string
                        ),
                        logs => \@logs
                    });
                    return;
                }

                $total_file_size += $file->stat->size;

                # TODO - Make this a site.max_static_webroot_size
                if ( $total_file_size >= ( 50 * 1024 * 1024 ) ) {
                    $job->fail( {
                        error => "This site may have up to 50 MiB in static files, however the webroot exceeds this limit.",
                        logs => \@logs
                    });
                    return;
                }

                Mojo::File->new( "$build_dir/build/html/" . $file->to_rel( $settings->{webroot} )->dirname )->make_path;
                $file->move_to( "$build_dir/build/html/" . $file->to_rel( $settings->{webroot} ) );
                push @logs, "File Processed:" . $file->to_rel($settings->{webroot});
            }
            push @logs, "--- Done Processing Static Files ---";
        }

        #==
        # Build Markdown Page Store
        #==
        if ( -d $settings->{site} ) {
            push @logs, "--- Processing MarkdownSite Files ---";

            my $files = Mojo::File->new( $settings->{site} )->list_tree;

            if ( $files->size > $site->max_markdown_file_count ) {
                $job->fail( {
                    error => "This site may have up to " . $site->max_markdown_file_count . " markdown files, however the site contains " . $files->size . " files.",
                    logs => \@logs
                });
                return;
            }

            foreach my $file ( $files->each ) {
                # Does file exceed size allowed?
                if ( $file->stat->size >= ( 256 * 1024 ) ) {
                    $job->fail( {
                        error => "MarkdownSite limits markdown files to 256 KiB.  $file exceeds that.",
                        logs => \@logs
                    });
                    return;
                }

                Mojo::File->new( "$build_dir/build/pages/" . $file->to_rel( $settings->{site} )->dirname )->make_path;
                $file->move_to( "$build_dir/build/pages/" . $file->to_rel( $settings->{site} ) );
                push @logs, "Markdown File Processed:" . $file->to_rel($settings->{site});

            }
            push @logs, "--- Done Processing MarkdownSite Files ---";
        }

        #==
        # Build Site Config
        #== TODO: There is two different files made here, one is done by ansible -- pick one,
        #         probably this one.
        Mojo::File->new($build_dir)->child('build')->child('site.yml')->spurt(
            YAML::Dump({
                domain  => $site->domain,
                www_dir => "$build_dir/build/",
            })
        );

        $job->note( is_build_complete => 1 );

        # Go to the build directory and make $build_dir/.
        $ENV{MARKDOWNSITE_CONFIG} = Mojo::File->new($build_dir->to_string)->child('build')->child('site.yml');

        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, '/etc/ansible/deploy-website.yml' ], \undef, \my $out, \my $err );
            push @logs, "--- Running: ansible-playbook -i $deploy_address /etc/ansible/deploy-website.yml";
            push @logs, "> STDOUT", " ", split( /\n/, $out );
            push @logs, "> STDERR", " ", split( /\n/, $err );
            push @logs, "--- Done Running: ansible-playbook -i $deploy_address /etc/ansible/deploy-website.yml";
        }

        $job->note( is_deploy_complete => 1 );
        $job->finish( \@logs );
    });
};

1;
