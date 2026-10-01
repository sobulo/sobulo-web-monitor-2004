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
        browserPrint("<!-- -->\n");
        #quickDebug($url, "Found in filterLinks before Filtering");
        next if ($found == 1);
        #quickDebug($url, "Found in filterLinks after Filtering");
        push @filtered_link_info, $l;
    }
    return @filtered_link_info;
}

#removeDuplicates()
#details - Removes all duplicates found in list of links
#arguments - A list of links
#returns   - A list of links
sub removeDuplicateLinks
{
    my @link_info = @_;
    my @link;
    my %linkTable;

    my $i = 0;
    my $l;
    foreach $l (@link_info) {
        my @info = @{$l};
        my $url = $info[0];
        next if ($linkTable{lc($url)} == 1);
        $linkTable{lc($url)} = 1;
        push @link, $l;

        #if ($linkTable{$url} == 1){
            #debugPrint("Found duplicate: $url\n");
            #splice @link_info, $i, 1;
            #next;
        #}
        $linkTable{$url} = 1;
        $i++;
    }
    return @link;
}

sub filterHash
{
    my %sourceHash = %{shift @_};
    my @filterKeys = @_;
    my %targetHash;

    my $k;
    foreach $k (@filterKeys) {
        if (exists($sourceHash{$k})) {
            $targetHash{$k} = $sourceHash{$k};
        }
    }
    return \%targetHash;
}
#For a particular website crawl for the given depth and retreive all the relevant urls.
sub getLinksForSite
{
    my ($link_info_ref, $depth, $resultsFilter, @crawlFilter) = @_;
    my @link_info = @{$link_info_ref};
    my $site = $link_info[0];
    $crawledLinks{$site} = 1;
    browserPrint("<!-- -->\n");
    my @links = getLinks($site); # get all the links in the site.
    my @okayUrls;
    my @brokenUrls;
    if (defined($links[0]) && $links[0] == -1) { # if there are no links the url is broken
        push @brokenUrls, $link_info_ref;
        @links = ();
    }
    else { # else it is fine
        push @okayUrls, $link_info_ref;
    }

    my @results = filterLinks($resultsFilter, @links);
    return (\@results, \@okayUrls, \@brokenUrls) if ($depth == 0);

    foreach my $c (@crawlFilter) {
        @links = filterLinks($c, @links); #which links to crawl, e.g. only *htm || *html
    }

    foreach my $l (@links) {
        my @info = @{$l}; # Each info element has an array of elements representing the tag.
        my $url = $info[0];
        my $url2 = $url . "/";
        browserPrint("<!-- -->\n");
        next if (($crawledLinks{$url} == 1 || $crawledLinks{$url2} == 1) && debugPrint("Skipping: $url\n"));
        my ($res_ref, $ok_ref, $brk_ref) = getLinksForSite($l, $depth -1, $resultsFilter, @crawlFilter);
        my @temp = @{$res_ref};
        my @temp2 = @{$ok_ref};
        my @temp3 = @{$brk_ref};

        if (defined($temp[0])){
            push @results, @temp;
        }
        if (defined($temp2[0])){
            push @okayUrls, @temp2;
        }
        if (defined($temp3[0])){
            push @brokenUrls, @temp3;
        }
    }
    return (\@results, \@okayUrls, \@brokenUrls);
}

# Returns a hash of sites and relevant links in it. Each element in the hash is referenced by the
# site. Then the array of links is referenced by the links tag.
sub getLinksForAllSites
{
    my $hash_ref = shift @_;
    my $resultFilter = shift @_;
    my $exploreFilter = shift @_;
    my %sites = %{$hash_ref};
    %crawledLinks = {};
    my $i = 1;
    my $numberOfSites = scalar(keys %sites);
    foreach my $k (keys %sites) {
        my %temp = %{($sites{$k})};
        my $depth = $temp{"depth"};
        my $within = $temp{"allow"};
        unless (defined($depth) && ($depth =~ /^\d+$/)) {
            $depth = 1000; #large enough to consider inifinite depth
        }
        unless (defined($within)) {
            $within = "";
        }
# Why [$k, "", "", ""].
        my ($res_ref, $ok_ref, $brk_ref) = getLinksForSite([$k, "", "", ""], $depth, $resultFilter, $exploreFilter, $within);
        $temp{"links"} = $res_ref;
        $temp{"okay"} = $ok_ref;
        $temp{"broken"} = $brk_ref;
        $sites{$k} = \%temp;
        %crawledLinks = {};
        debugPrint("**************Done with site$i: $k\n****************");
        browserPrint("Done with site: $k, completed $i out of $numberOfSites<br>\n");
        $i++;
    }
    return \%sites;
}

sub getKeysSortedByName
{
    my %hash = %{shift @_};
    my @sortedKeys = keys %hash;
    @sortedKeys = sort { lc(${$hash{$a}}{"name"}) cmp lc(${$hash{$b}}{"name"}) } @sortedKeys;
    return @sortedKeys;
}

sub printSnapshotHtml
{
    my $hash_ref = shift @_;
    my $type = shift @_;
    my $hideEmpty = shift @_;
    my $hide = shift @_;
    my $sort = shift @_;
    my $course = shift @_;
    my $network = shift @_;
    my %sites = %{$hash_ref};

    my $site_name;
    print "<ol>\n";

    my @sortedSites = keys %sites;
    if ($sort eq "name") {
        @sortedSites = getKeysSortedByName($hash_ref);
    }
    else
    {
        @sortedSites = sort { lc(${$sites{$a}}{"title"}) cmp lc(${$sites{$b}}{"title"}) } @sortedSites;
    }

    foreach $site_name (@sortedSites) {
        my %temp = %{($sites{$site_name})};
        my @links = @{($temp{"links"})};
        #my @okay_links = @{($temp{"okay"})};
        my @broken_links = @{($temp{"broken"})};
        my $d = $temp{"depth"};
        my $w = $temp{"allow"};
        my $tit = $temp{"title"};
        my $name = $temp{"name"};

        if ($course == 1){
            @links = filterOutLinks(\@links, "homework|exam|midterm|course|handout|fall|spring|winter|lecture", 1, 3);
        }
        next if ((scalar(@links) == 0) && ($hideEmpty == 1));

        print <<EOF2;
                            <p><li><b>Researcher: $name Site: <a href="$site_name">$tit</a> [Crawl Depth: $d] [Stay Within: $w]</b>
EOF2

        print "\n<ul>";
        my $l;
        my $td;
        if ($hide == 1) {
            @links = removeDuplicateLinks(@links);
        }

        my @sortedLinks = sort { lc(${$a}[1]) cmp lc(${$b}[1]) } @links;
        if (scalar(@sortedLinks) == 0) {
            if ($type eq "diff") {
                print "<li><b>No Changes Found\n</b>";
            }
            else
            {
                print "<li><b>No pdf/ps links found\n</b>";
            }

        }
        foreach $l (@sortedLinks) {
            my @info = @{$l};
            my $u = $info[0];
            my $t = $info[1];
            my $p = $info[2];
            my $ti = $info[3];
            my $edit = " found on ";
            if ($type eq "diff") {
                $edit = " " . $info[4] . " ";
            }
            print <<EOF3;
                                <li><a href="$u">$t</a> $edit <a href="$p">$ti</a>
EOF3
        }

        if ($network == 1) {

            @sortedLinks = sort { lc(${$a}[1]) cmp lc(${$b}[1]) } @broken_links;
            if (scalar(@sortedLinks) > 0) {
                if ($type eq "diff") {
                    print "<li><b>Below is a list of links that were not crawled in BOTH snapshots (due to network errors e.g. delays or broken links), these links were not considered for differences: \n";
                    print "[added] implies the link was present in the more recent snapshot but not in the former (vice versa for [removed]):</b><ul>\n;"
                }
                else
                {
                    print "<li><b>Below is a list of links not crawled due to network errors (e.g. delays or broken links)</b><ul>:\n";
                }

                foreach $l (@sortedLinks) {
                    my @info = @{$l};
                    my $u = $info[0];
                    my $t = $info[1];
                    my $p = $info[2];
                    my $ti = $info[3];
                    my $edit = " found on ";
                    if ($type eq "diff") {
                        $edit = " " . $info[4] . " ";
                    }
                    print <<EOF4;
                                 <li><a href="$u">$t</a> $edit <a href="$p">$ti</a>
EOF4
                }
                print "</ul>\n";
            }
        }
        print "</ul></p>\n";

}
        print "</ol>\n";
}

sub getSnapshotEmailHtml
{
    my $hash_ref = shift @_;
    my $type = shift @_;
    my $hideEmpty = shift @_;
    my $hide = shift @_;
    my $sort = shift @_;
    my @rules = @_;
    my %sites = %{$hash_ref};
    my %results_hash;
    my $diffResult;

    my $site_name;
    $diffResult = "<ol>\n";

    my @sortedSites = keys %sites;
    if ($sort eq "name") {
        @sortedSites = getKeysSortedByName($hash_ref);
    }
    else
    {
        @sortedSites = sort { lc(${$sites{$a}}{"title"}) cmp lc(${$sites{$b}}{"title"}) } @sortedSites;
    }

    foreach $site_name (@sortedSites) {
        my %temp = %{($sites{$site_name})};
        my @links = @{($temp{"links"})};
        my $d = $temp{"depth"};
        my $w = $temp{"allow"};
        my $tit = $temp{"title"};
        my $name = $temp{"name"};

        if (defined($rules[0])){
            my $r;
            foreach $r (@rules) {
                #rules table
                if ($r eq "rule1") {
                    @links = filterOutLinks(\@links, "homework|exam|midterm|course|handout|fall|spring|winter", 1, 3);
                }

            }
        }
        next if ((scalar(@links) == 0) && ($hideEmpty == 1));

        $diffResult .= "<p><li><b>Researcher: $name Site: <a href='$site_name'>$tit</a> [Crawl Depth: $d] [Stay Within: $w]</b>";


        $diffResult .= "\n<ul>";
        my $l;
        my $td;
        if ($hide == 1) {
            @links = removeDuplicateLinks(@links);
        }

        my @sortedLinks = sort { lc(${$a}[1]) cmp lc(${$b}[1]) } @links;
        if (scalar(@sortedLinks) == 0) {
            $diffResult .= "<li><b>No Changes Found\n</b>";
        }
        foreach $l (@sortedLinks) {
            my @info = @{$l};
            my $u = $info[0];
            my $t = $info[1];
            my $p = $info[2];
            my $ti = $info[3];
            my $edit = " found on ";
            if ($type eq "diff") {
                $edit = " " . $info[4] . " ";
            }
            $diffResult .= "<li><a href='$u'>$t</a> $edit <a href='$p'>$ti</a>\n";
        }
        $diffResult .= "</ul></p>\n";
    }
    $diffResult .= "</ol>\n";
    return $diffResult;
}

sub getSnapshotEmailText
{
    my $hash_ref = shift @_;
    my $type = shift @_;
    my $hideEmpty = shift @_;
    my $hide = shift @_;
    my $sort = shift @_;
    my @rules = @_;
    my %sites = %{$hash_ref};
    my %results_hash;
    my $diffResult;

    my $site_name;
    $diffResult = "";

    my @sortedSites = keys %sites;
    if ($sort eq "name") {
        @sortedSites = getKeysSortedByName($hash_ref);
    }
    else
    {
        @sortedSites = sort { lc(${$sites{$a}}{"title"}) cmp lc(${$sites{$b}}{"title"}) } @sortedSites;
    }

    foreach $site_name (@sortedSites) {
        my %temp = %{($sites{$site_name})};
        my @links = @{($temp{"links"})};
        my $d = $temp{"depth"};
        my $w = $temp{"allow"};
        my $tit = $temp{"title"};
        my $name = $temp{"name"};

        if (defined($rules[0])){
            my $r;
            foreach $r (@rules) {
                #rules table
                if ($r eq "rule1") {
                    @links = filterOutLinks(\@links, "homework|exam|midterm|course|handout|fall|spring|winter", 1, 3);
                }

            }
        }
        next if ((scalar(@links) == 0) && ($hideEmpty == 1));

        $diffResult .= "Researcher: $name SiteName: $tit SiteUrl: $site_name [Crawl Depth: $d] [Stay Within: $w]\n";

        my $l;
        my $td;
        if ($hide == 1) {
            @links = removeDuplicateLinks(@links);
        }

        my @sortedLinks = sort { lc(${$a}[1]) cmp lc(${$b}[1]) } @links;
        if (scalar(@sortedLinks) == 0) {
            $diffResult .= "     No Changes Found\n";
        }
        foreach $l (@sortedLinks) {
            my @info = @{$l};
            my $u = $info[0];
            my $t = $info[1];
            my $p = $info[2];
            my $ti = $info[3];
            my $edit = " found on ";
            if ($type eq "diff") {
                $edit = " " . $info[4] . " ";
            }
            $diffResult .= "     PaperName: $t PaperUrl: $u $edit PageName: $ti PageUrl: $p \n";
        }
        $diffResult .= "\n";
    }
    $diffResult .= "\n";
    return $diffResult;
}

sub checkUrlFormat
{
    my $url = shift @_;
    if ($url =~ /^https?:\/\/\S+?\.\S+?$/) {
        return 1;
    }
    else
    {
        warn("Warning: illegal url format for $url\n");
        return 0;
    }
}

sub readSiteFile
{
    my $file_name = shift @_;
    my $site_name = shift @_;
    my $hash_ref = shift @_;
    my %sites = %{$hash_ref};
    my $k;
    my $name = $sites{$site_name}->{"name"};

    checkUrlFormat($site_name);

    browserPrint("<!-- -->\n");
    open(READ, "<$file_name") or die "unable to open for reading site info: $file_name";

    my $line = <READ>;
    $line =~ s/\n//;
    my ($url, $depth, $title, @within) = split /\|/, $line;
    my $with = join '|', @within;
    die "file contains link for $url and not for $site_name" if ($site_name ne $url);
    my %temp;
    $temp{"depth"} = $depth;
    $temp{"allow"} = $with;
    $temp{"title"} = $title;
    if (defined($name)) {
        $temp{"name"} = $name;
    }
    my @links;
    while (<READ>) {
        $line = $_;
        $line =~ s/\n//;
        next if ($line =~ /^\s*$/);
        my ($u, $text, $page_url, $page_title) = split /\|/, $line;
        checkUrlFormat($page_url);
        push @links, [$u, $text, $page_url, $page_title];
        browserPrint("<!-- -->\n");
    }
    $temp{"links"} = \@links;
    $sites{$site_name} = \%temp;
    close READ;
    return \%sites;
}

sub writeSiteFile
{
    my $file_name = shift @_;
    my $site_name = shift @_;
    my $hash_ref = shift @_;
    my %sites = %{$hash_ref};
    browserPrint("<!-- -->\n");

    checkUrlFormat($site_name);

    open(WRITE, ">$file_name") or die "unable to open for writing site info: $file_name";

    my %temp = %{($sites{$site_name})};
    my @links = @{($temp{"links"})};
    my $d = $temp{"depth"};
    my $w = $temp{"allow"};
    my $title = $site_name;
    if (defined($SiteTitles{$site_name}) && ($SiteTitles{$site_name} !~ /^\s*?$/))
    {
        $title = $SiteTitles{$site_name};
    }

    print WRITE "$site_name|$d|$title|$w\n";
    my $l;
    foreach $l (@links) {
        browserPrint("<!-- -->\n");
        my @info = @{$l};
        $title = $info[2];
        my $text = $info[0];
        if (defined($info[1]) && ($info[1] !~ /^\s*?$/))
        {
            $text = $info[1];
        }
        if (defined($info[3]) && ($info[3] !~ /^\s*?$/))
        {
            $title = $info[3];
        }
        print WRITE "$info[0]|$text|$info[2]|$title\n";
    }
    close WRITE;
    chmod 0664, $file_name or warn "unable to chmod for $file_name, error was: $!";
}

sub readUrlFile
{
    my $file_name = shift @_;
    my $site_name = shift @_;
    my $hash_ref = shift @_;
    my $type = shift @_;
    my %sites = %{$hash_ref};
    my $k;
    my $name = $sites{$site_name}->{"name"};

    checkUrlFormat($site_name);

    browserPrint("<!-- -->\n");
    open(READ, "<$file_name") or die "unable to open for reading site info: $file_name";

    my %temp = %{($sites{$site_name})};
    my @links;
    my $line;
    while (<READ>) {
        $line = $_;
        $line =~ s/\n//;
        next if ($line =~ /^\s*$/);
        my ($u, $text, $page_url, $page_title) = split /\|/, $line;
        checkUrlFormat($page_url);
        push @links, [$u, $text, $page_url, $page_title];
        browserPrint("<!-- -->\n");
    }
    $temp{$type} = \@links;
    $sites{$site_name} = \%temp;
    #$SiteTitles{$site_name} = "";
    close READ;
    return \%sites;
}

sub writeUrlFile
{
    my $file_name = shift @_;
    my $site_name = shift @_;
    my $hash_ref = shift @_;
    my $type = shift @_;
    my %sites = %{$hash_ref};
    browserPrint("<!-- -->\n");

    checkUrlFormat($site_name);

    open(WRITE, ">$file_name") or die "unable to open for writing url info: $file_name";

    my %temp = %{($sites{$site_name})};
    my @links = @{($temp{$type})};
    my $title = $site_name;
    if (defined($SiteTitles{$site_name}) && ($SiteTitles{$site_name} !~ /^\s*?$/))
    {
        $title = $SiteTitles{$site_name};
    }

    my $l;
    foreach $l (@links) {
        browserPrint("<!-- -->\n");
        my @info = @{$l};
        $title = $info[2];
        my $text = $info[0];
        if (defined($info[1]) && ($info[1] !~ /^\s*?$/))
        {
            $text = $info[1];
        }
        if (defined($info[3]) && ($info[3] !~ /^\s*?$/))
        {
            $title = $info[3];
        }
        print WRITE "$info[0]|$text|$info[2]|$title\n";
    }
    close WRITE;
    chmod 0664, $file_name or warn "unable to chmod for $file_name, error was: $!";
}

sub sortLinks
{
    my @link_info = @_;
    my @sorted = sort { ($$a[0] . $$a[2]) cmp ($$b[0] . $$b[2]) } @link_info;
    return @sorted;
}

sub diffLinks
{
    my ($refA, $refB) = @_;
    my @listA = sortLinks(@{$refA});
    my @listB = sortLinks(@{$refB});

    my $i = 0; my $j = 0;
    my @diffResult;
    while ($i < scalar(@listA) || $j < scalar(@listB))
    {
        if ($i >= scalar(@listA)) {
            my @info = @{$listB[$j]};
            push @info, "added to";
            push @diffResult, \@info;
            $j++;
            next;
        }

        if ($j >= scalar(@listB)) {
            my @info = @{$listA[$i]};
            push @info, "removed from";
            push @diffResult, \@info;
            $i++;
            next;
        }

        my @infoA = @{$listA[$i]};
        my @infoB = @{$listB[$j]};
        my $urlA = $infoA[0];
        my $urlB = $infoB[0];
        if (($urlA cmp $urlB) == 0)
        {
            $j++; $i++;
        }
        elsif (($urlA cmp $urlB) < 0) {
            push @infoA, "removed from";
            push @diffResult, \@infoA;
            $i++;
        }
        else
        {
            push @infoB, "added to";
            push @diffResult, \@infoB;
            $j++;
        }
    }
    return @diffResult;
}

sub printLinkInfo
{
    my @link_info = @_;
    my $l;
    foreach $l (@link_info) {
        my @info = @{$l};
        my $i;
        #debugPrint("$info[1]");
        for ($i = 0; $i < scalar(@info); $i++) {
            debugPrint("$i:\t$info[$i]\t");
        }
        debugPrint("\n");
    }
}

sub translateUrlToFileName
{
        my $file_name = shift @_;
        $file_name =~ s#/#\\\\#g;
        $file_name = "_" . $file_name;
        return $file_name;
}

sub readCachedPage
{
    my $file_name = shift @_;
    open(INIT, "<$file_name") or die "unabale to open cached page $file_name for reading, error was: $!";
    my $content = (join "", <INIT>);
        return \$content;
}

sub writeCachedPage
{
    my ($file_name, $contents_ref) = @_;
        my $contents = $$contents_ref;

    die "unable to write undefined value $contents" unless defined($contents);

    open(INIT, ">$file_name") or die "couldn't open init file $file_name for writing, error was: $!";

    print INIT "$contents";
    close INIT;
    chmod 0664, $file_name or warn "unable to chmod for $file_name, error was: $!";
        #chmod 0666, $file_name or die "unable to chmod for $file_name, error was: $!";
}

sub sendMail
{
    my ($to, $from, $subject, $text_message, $html_message) = @_;

    my $email = <<THE_EMAIL;
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="_jkkdsffds32432dlkjifewks_"
To: $to
From: $from
Subject: $subject

--_jkkdsffds32432dlkjifewks_
Content-Type: text/plain; charset="iso-8859-1"

$text_message

--_jkkdsffds32432dlkjifewks_
Content-Type: text/html; charset="iso-8859-1"

<html>
<body>
<!----------------------------------------
We appologize if you see this message. The
email was intended to display either plain
text or HTML, not both. You may ignore the
rest of the email. The plain text above is
the complete message intended to reach you.
------------------------------------------>

$html_message
</body>
</html>

--_jkkdsffds32432dlkjifewks_--
THE_EMAIL

        open(MAIL, "|$sendmail") or die "couldn't open sendmail, error was: $!";
        print MAIL $email;
        close(MAIL);
}

sub parseXml
{
    my $content = shift @_;
    my $hash_ref = parseXmlHelper($content, {});
    my %hash = %{$hash_ref};

        die "<xml-document> expected\n" unless exists($hash_ref->{"xml-document"});
        $hash_ref = ${$hash_ref->{"xml-document"}}[0];
        return $hash_ref;
}

sub parseXmlHelper
{
    my $content = shift @_;
    my $hash_ref = shift @_;
    my %xml_hash = %{$hash_ref};

        if (!defined($content) || ($content =~ /^\s*$/s)) {
            return $hash_ref;
        }

        if ($content !~ /^\s*<\s*(\S+?)\s*>\s*(.*?)\s*<(\/|\\)\s*\1\s*>\s*/s) {
            die "error while parsing xml file\n";
        }

        my $tag_name = $1;
        my $tag_content = $2;
        $content = $';

        #debugPrint("TagName: #$tag_name#\n");
        #debugPrint("TagContent: #$tag_content#\n");
        #debugPrint("Content:#$content#\n");

        if (!exists($xml_hash{$tag_name}))
        {
            $xml_hash{$tag_name} = [];
        }


        #nested tags
        if ($tag_content =~ /^\s*</s) {
            $tag_content = parseXmlHelper($tag_content,{});
        }

        my @tag_array = @{$xml_hash{$tag_name}};
        push @tag_array, $tag_content;
        $xml_hash{$tag_name} = \@tag_array;

        $hash_ref = parseXmlHelper($content, \%xml_hash);
        return $hash_ref;
}

sub generateXml
{
    my $hash_ref = shift @_;
    my $content = generateXmlHelper($hash_ref, 1);
    $content = "<xml-document>\n" . $content . "</xml-document>\n";
    return $content;
}

sub generateXmlHelper
{
    my $hash_ref = shift @_;
    my $tab_level = shift @_;
    die "generateXmlHelper: expected hash reference\n" unless (ref($hash_ref) eq "HASH");
    my %xml_hash = %{$hash_ref};
    my $content = "";

    my $x;
    foreach $x (keys %xml_hash) {
        die "generateXmlHelper: expected array reference\n" unless (ref($xml_hash{$x}) eq "ARRAY");
        #debugPrint("key is: $x\n");
        my @tag_array = @{$xml_hash{$x}};

        my $t;
        foreach $t (@tag_array) {
            for (my $i = 0; $i < $tab_level; $i++) {
                $content .= "\t";
            }
            $content .= "<$x>";
            if (ref($t) eq "HASH"){ #nested tag
                $content = $content . "\n";
                $content = $content . generateXmlHelper($t, $tab_level +1);
                for (my $i = 0; $i < $tab_level; $i++) {
                    $content .= "\t";
                }
                $content .= "</$x>\n";
            }
            else {
                $content .= $t;
                $content .= "</$x>\n"
            }
        }
    }

    return $content;
}

sub convertXmlHashToUserHash
{
    my $hash_ref = shift @_;
    my %xml_hash = %{$hash_ref};
    my %user_hash;

    die "expected <user>\n" unless exists($xml_hash{"user"});
    my @tag_array = @{$xml_hash{"user"}};

    my $t;
    foreach $t (@tag_array) {
        my %temp;
        $temp{"name"} = ${$t->{"name"}}[0];
        $temp{"notify"} = ${$t->{"notify"}}[0];
        $temp{"url"} = $t->{"url"};
        $user_hash{${$t->{"email"}}[0]} = \%temp;
    }
    return \%user_hash;
}

sub convertUserHashToXmlHash
{
    my $hash_ref = shift @_;
    my %user_hash = %{$hash_ref};
    my %xml_hash;

    my $x;
    my @userArray;
    foreach $x (keys %user_hash) {
        my %temp = %{$user_hash{$x}};
        my %info_hash;

        $info_hash{"email"} = [$x];
        $info_hash{"name"} = [$temp{"name"}];
        $info_hash{"url"} = $temp{"url"};
        $info_hash{"notify"} = [$temp{"notify"}];

        push @userArray, \%info_hash;
    }
    $xml_hash{"user"} = \@userArray;
    return \%xml_hash;
}

sub convertXmlHashToProfessorHash
{
    my $hash_ref = shift @_;
    my %xml_hash = %{$hash_ref};
    my %professor_hash;

    die "expected <professor>\n" unless exists($xml_hash{"professor"});
    my @tag_array = @{$xml_hash{"professor"}};

    my $t;
    foreach $t (@tag_array){
        my %temp;
        $temp{"name"} = ${$t->{"name"}}[0];

            die "expected <site>\n" unless exists($t->{"site"});
            my @tag_array2 = @{$t->{"site"}};
            my %result_hash;

            my $t2;
            my %temp2;
            foreach $t2 (@tag_array2) {
                my %temp3;
                if (defined(${$t2->{"depth"}}[0])) {
                    $temp3{"depth"} = ${$t2->{"depth"}}[0];
                }
                if (defined(${$t2->{"allow"}}[0])) {
                    $temp3{"allow"} = ${$t2->{"allow"}}[0];
                }
                $temp2{${$t2->{"url"}}[0]} =\%temp3;
            }
            $temp{"sites"} = \%temp2;
            $professor_hash{${$t->{"email"}}[0]} = \%temp;
    }
    return \%professor_hash;
}

sub convertProfessorHashToXmlHash
{
    my $hash_ref = shift @_;
    my %professor_hash = %{$hash_ref};
    my %xml_hash;

    my $k;
    my @professor_array;
    foreach $k (keys %professor_hash) {
        my %temp = %{($professor_hash{$k})};
        my %info_hash;

        $info_hash{"email"} = [$k];
        $info_hash{"name"} =[$temp{"name"}];

        my %sites_hash = %{$temp{"sites"}};
        my $l;
        my @sites_array;
        foreach $l (keys %sites_hash) {
            my %sites_xml_hash;
            $sites_xml_hash{"url"} = [$l];
            if (defined($sites_hash{$l}->{"depth"})) {
                $sites_xml_hash{"depth"} = [$sites_hash{$l}->{"depth"}];
            }
            if (defined($sites_hash{$l}->{"allow"})) {
                $sites_xml_hash{"allow"} = [$sites_hash{$l}->{"allow"}];
            }
            push @sites_array, \%sites_xml_hash;
        }
        $info_hash{"site"} = \@sites_array;
        push @professor_array, \%info_hash;
    }
    $xml_hash{"professor"} = \@professor_array;
    return \%xml_hash;
}

sub convertProfessorHashToSiteHash
{
    my $hash_ref = shift @_;
    my %student_hash = %{$hash_ref};
    my %site_hash;

    my $v;
    foreach $v (values %student_hash) {
        die "convertStudentHashToSiteHash: expected <sites>\n" unless exists($v->{"sites"});
        my %url_hash = %{$v->{"sites"}};
        my $name = $v->{"name"};

            my $url;
            foreach $url (keys %url_hash) {
                checkUrlFormat($url);
                $site_hash{$url} = $url_hash{$url};
                $site_hash{$url}->{"name"} = $name;
                $SiteTitles{$url} = "";
            }
    }
    return \%site_hash;
}

sub filterProfessorHash
{
    my $hash_ref = shift @_;
    my @selectedSites = @_;

    my %student_hash = %{$hash_ref};
    my %site_hash;

    my $k;
    foreach $k (keys %student_hash) {
        my $v = $student_hash{$k};
        die "convertStudentHashToSiteHash: expected <sites>\n" unless exists($v->{"sites"});
        my %url_hash = %{$v->{"sites"}};
        my $name = $v->{"name"};

        my $url;
        my $foundAny = 0;
        foreach $url (keys %url_hash) {
            #print "Processing $url<br>";
            unless (findInArray($url, @selectedSites)) {
                #print "deleting $url<br>";
                delete $url_hash{$url};
                next;
            }
            $foundAny = 1;
        }

        if ($foundAny == 0) {
            delete $student_hash{$k};
        }
        else
        {
            $v->{"sites"} = \%url_hash;
        }
    }
    return \%student_hash;
}

# Looks for the presence of a key in an array.
# Key is the first parameter and @array is the second.
sub findInArray
{
    my $key = shift @_;
    my @array = @_;
    foreach my $k (@array) {
        if ($k eq $key) {
            return 1;
        }
    }
    return 0;
}

sub setDebug
{
    $DEBUG = shift @_;
}

sub debugPrint
{
    my $message = shift @_;
    if ($DEBUG == 1) {
        print "$message";
    }
    return 1;
}

sub setBrowser
{
    $BROWSER = shift @_;
}

sub browserPrint
{
    my $message = shift @_;
    if ($BROWSER == 1) {
        print "$message";
    }
    return 1;
}


1;
