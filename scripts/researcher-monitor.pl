#!/usr/bin/perl

# 2026 reconstruction/test infrastructure. This is not recovered 2004 source.
# It loads and orchestrates the frozen Appendix A MonitorUtils package unchanged.

use strict;
use warnings;
use FindBin qw($Bin);
use File::Path qw(make_path);
use File::Spec;

my $repo_root = File::Spec->rel2abs(File::Spec->catdir($Bin, File::Spec->updir()));
my $monitor_utils = File::Spec->catfile(
    $repo_root,
    "original",
    "appendix-a",
    "MonitorUtils.thesis.pl"
);
require $monitor_utils;

my $default_url = "http://127.0.0.1:8765/index.html";
my $command = shift @ARGV // "";

if ($command eq "snapshot") {
    my $url = shift @ARGV // $default_url;
    my $output_root = shift @ARGV // File::Spec->catdir(
        $repo_root,
        "runtime",
        "researcher-monitor"
    );
    die usage() if @ARGV;

    assert_loopback_url($url);
    make_path($output_root) unless -d $output_root;
    $output_root .= "/" unless $output_root =~ /\/$/;

    my $site_hash = build_site_hash($url);
    my $snapshot_dir = MonitorUtils::newSave($site_hash, $output_root);
    print "Snapshot created: $snapshot_dir\n";
}
elsif ($command eq "diff") {
    my $older_dir = shift @ARGV // die usage();
    my $newer_dir = shift @ARGV // die usage();
    my $url = shift @ARGV // $default_url;
    die usage() if @ARGV;

    assert_loopback_url($url);
    $older_dir .= "/" unless $older_dir =~ /\/$/;
    $newer_dir .= "/" unless $newer_dir =~ /\/$/;

    die "Older snapshot directory not found: $older_dir\n" unless -d $older_dir;
    die "Newer snapshot directory not found: $newer_dir\n" unless -d $newer_dir;

    my $older_sites = MonitorUtils::readSavedSites(build_site_hash($url), $older_dir);
    my $newer_sites = MonitorUtils::readSavedSites(build_site_hash($url), $newer_dir);
    my $differences = MonitorUtils::diffSavedSites($older_sites, $newer_sites);
    my $report = MonitorUtils::getSnapshotEmailText(
        $differences,
        "diff",
        0,
        1,
        "name"
    );
    print $report;
}
else {
    die usage();
}

sub build_site_hash
{
    my $url = shift @_;
    my $professor_hash = {
        "fixture\@example.invalid" => {
            "name" => "Controlled Fixture Researcher",
            "sites" => {
                $url => {
                    "depth" => 0,
                    "allow" => ""
                }
            }
        }
    };
    return MonitorUtils::convertProfessorHashToSiteHash($professor_hash);
}

sub assert_loopback_url
{
    my $url = shift @_;
    die "Only a loopback fixture URL is allowed: $url\n"
        unless $url =~ m{^http://127\.0\.0\.1:\d+/};
}

sub usage
{
    return <<"USAGE";
Usage:
  scripts/researcher-monitor.pl snapshot [URL] [OUTPUT_ROOT]
  scripts/researcher-monitor.pl diff OLDER_SNAPSHOT NEWER_SNAPSHOT [URL]

Defaults:
  URL: $default_url
  OUTPUT_ROOT: runtime/researcher-monitor
USAGE
}
