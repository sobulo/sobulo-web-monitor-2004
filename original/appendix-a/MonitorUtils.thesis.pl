#!/usr/bin/perl

package MonitorUtils;

use strict;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use HTML::TokeParser;
use HTTP::Headers;



my $ua = LWP::UserAgent->new();
$ua->agent("TestBot/0.1");

#location of sendmail, for sending out emails
my $sendmail = "/usr/sbin/sendmail -t";

#print flags
my $BROWSER = 0;
my $DEBUG = 0;


my %crawledLinks = {};
my %SiteTitles = {}; #quick hack can do this better, maybe
my %changedUrls = {};
my %changedSites = {};


#newSave()
#details - Takes a snapshot of websites and stores in a time-stamped folder
#arguments - a hash reference, containing information about which sites should have their snapshot taken
#          - a string specifying where the time-stamped folder should be created
#returns   - string specifying full path to time-stamped snapshot folder
sub newSave
{
    my $hash_ref = shift @_;
    my $location = shift @_;

    my $result_filter = "\\.(ps\\.gz|pdf|ps|ppt)\\s*?\$";
    my $explore_filter = "\\.(asp|jsp|php).*?\$|\\.htm\\s*?\$|\\.html\\s*?\$|\\/\\w+?\\s*?\\/??\\s*?\$|\\?";

    $hash_ref = getLinksForAllSites($hash_ref, $result_filter, $explore_filter);
    my $dirname = time;
    $dirname = $location . $dirname . "/";
    browserPrint("<!-- -->\n");
    mkdir $dirname, 0777 or die "unable to make dir $dirname, error was: $!";
    chmod 0777, $dirname or warn "unable to chmod for $dirname, error was: $!";

    my $k;
    my %sites = %{$hash_ref};
    foreach $k (keys %sites)
    {
        my $file_name = $k;
        $file_name =~ s#/#\\\\#g;
        #$file_name = $dirname . "_" . $file_name;

        browserPrint("<!-- -->\n");
        writeSiteFile($dirname . "_" . $file_name, $k, $hash_ref);
        writeUrlFile($dirname . "okay" . "_" . $file_name, $k, $hash_ref, "okay");
        writeUrlFile($dirname . "broken" . "_" . $file_name, $k, $hash_ref, "broken");
    }
    return $dirname;
}

#getDirList()
#details - Returns the contents of all files/folders in a directory
#arguments - directory to b read
#returns   - string specifying full path to time-stamped snapshot folder
sub getDirList
{
    my $the_dir = shift @_;
    opendir DIRHANDLE, $the_dir or die "unable to open directory $the_dir, error was: $!";
    my @allfiles = grep !/^\.\.?$/, readdir DIRHANDLE;
    closedir DIRHANDLE;
    return (sort {$b <=> $a} @allfiles);

}

#diffSavedSites()
#details - Returns the difference between list of links cached for each site
#arguments - 2 hash_references (keys = site-urls, values = array of links found extracted from site)
#returns   - a hash_reference containing the difference btw the links for each site
sub diffSavedSites
{
    my $hash_ref1 = shift @_;
    my $hash_ref2 = shift @_;
    my %sites1 = %{$hash_ref1};
    my %sites2 = %{$hash_ref2};

    my $k;
    foreach $k (keys %sites1) {
        unless (exists($sites2{$k}))
        {
            debugPrint("Warning: doing diff, but no match for $k");
            next;
        }
        my %temp1 = %{($sites1{$k})};
        my %temp2 = %{($sites2{$k})};

        my @init_links = diffLinks($temp1{"links"}, $temp2{"links"});
        my @broken = diffLinks($temp1{"okay"}, $temp2{"okay"});
        my @links;
        my %brokenHash;
        my $b;
        foreach $b (@broken) {
            my @info = @{$b};
            $brokenHash{$info[0]} = "";
        }
        foreach $b (@init_links) {
            my @info = @{$b};
            next if (exists($brokenHash{$info[2]}));
            push @links, $b;
        }
        $temp1{"links"} = \@links;
        $temp1{"broken"} = \@broken;

        $sites1{$k} = \%temp1;
    }
    $hash_ref1 = \%sites1;
    return $hash_ref1;
}

#readSavedSites()
#details - Reads in a saved snapshot into a hash-reference
#arguments - hash-reference containing list of sites to read in
#returns   - hash-reference with snapshot data associated with each site
sub readSavedSites
{
    my $hash_ref = shift @_;
    my $location = shift @_;
    my %sites = %{$hash_ref};

    my $k;
    foreach $k (keys %sites)
    {
        my $file_name = $k;
        $file_name =~ s#/#\\\\#g;
        #$file_name = $location . "_" . $file_name;
        $hash_ref = readSiteFile($location . "_" . $file_name, $k, $hash_ref);
        $hash_ref = readUrlFile($location . "okay" . "_" . $file_name, $k, $hash_ref, "okay");
        $hash_ref = readUrlFile($location . "broken" . "_" . $file_name, $k, $hash_ref, "broken");
    }
    return $hash_ref;
}

#getLinks()
#details - Extracts all the links in a page
#arguments - string containing url of page
#returns   - a list of links found on the page
sub getLinks
{
    my $page_url = shift @_;
    browserPrint("<!-- -->\n");
    my $req;
    my $res;
    my $i = 0;
    while ($i < 2) { #Attempts to get a page twice.
        browserPrint("<!-- -->\n");
        $req = HTTP::Request->new('GET' => $page_url);
        $res = $ua->request($req);
        if ($res->is_success) {
            last;
        }
        $i++;
    }
    unless ($res->is_success) { # If page is not present flag an error.
        debugPrint("ERROR: Unable to retrieve source page: $page_url\n");
        return (-1, -1);
    }
    my $title = $res->title;
    if (defined($SiteTitles{$page_url})){
        $SiteTitles{$page_url} = $title;
    }
    my $p = HTML::TokeParser->new($res->content_ref);

    my @link_info = ();
    while (my $token = $p->get_tag("a")) {
        my $t;
        my $url = $token->[1]{href};
        my $text = $p->get_trimmed_text("/a");
        my $p_url = URI->new($page_url);
        my $ref_uri = URI->new($url);
        my $abs_url = $ref_uri->abs($p_url);
        browserPrint("<!-- -->\n");
        # Each node contains the absolute url, the acnchor text, current url and and title of current url.
        push @link_info, [$abs_url->canonical, $text, $p_url->canonical, $title];
    }
    return @link_info;
}

#filterLinks()
#details - Returns all links matching a particular filter (regular expression)
#arguments - A list of links
#          - filter specified by regular expression
#returns   - A list of links
sub filterLinks
{
    my $filter = shift @_;
    my @link_info = @_;
    return @link_info unless (defined($filter) && $filter =~ /^\S/);
    my $l;
    my @filtered_link_info = ();
    foreach $l (@link_info) {
        my @info = @{$l};
        my $url = $info[0];
        browserPrint("<!-- -->\n");
        #quickDebug($url, "Found in filterLinks before Filtering");
        next if ($url !~ /$filter/i);
        #quickDebug($url, "Found in filterLinks after Filtering");
        push @filtered_link_info, $l;
    }
    return @filtered_link_info;
}

#filterOutLinks()
#details - Returns all the links that do not match specified filter
#arguments - A list of links
#          - filter specified by regular expression
#          - list of integers, specifying which part of link-datastructure to filter on
#returns   - a list of links
sub filterOutLinks
{
    my @link_info = @{shift @_};
    my $filter = shift @_;
    my @keys = @_;

    return @link_info unless (defined($filter) && $filter =~ /^\S/);
    my $l;
    my @filtered_link_info = ();
    foreach $l (@link_info) {
        my @info = @{$l};
        my $found = 0;
        my $k;
        foreach $k (@keys) {
            my $url = $info[$k];
            if ($url =~ /$filter/i)
            {
                $found = 1;
                last;
            }
        }
