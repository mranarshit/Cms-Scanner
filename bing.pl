#!/usr/bin/perl -w
use strict;
use LWP::UserAgent;
use URI::Escape;
use List::MoreUtils qw(uniq);
use Parallel::ForkManager;
use Getopt::Long;


our $options = GetOptions (
'i|server=s'=> \my $ip_list,
't|threads=i'=> \my $max_process,
'f|file_save=s'=> \my $file_save,
'cms|cmss'=> \my $cms,
'v|verbose'=> \my $verbose,
);
unless ($options){help();}

my %OPT = (
    Wordpress =>{
	REGEX	=>	"wordpress|wp\-content|wp\-includes",
        CMS => "Wordpress",
    },
    Joomla =>{
	REGEX	=>	"joomla|\/component\/|com\_",
	CMS => "Joomla",
    },
    vbulletin =>{
	REGEX2	=>	"X-Meta-Generator: vBulletin",
	REGEX		=>	"vbulletin_css",
        CMS => "Vbulletin",
    },
    Mybb =>{
	REGEX2	=>	"Set-Cookie: mybb",
	REGEX	=>	"wp\-content|\">MyBB<\/a>",
        CMS => "Mybb",
    },
    Whmcs=>{
	REGEX2	=>	"Set-Cookie: WHMC",
	REGEX	=>	"\">WHMCompleteSolution<\/a>",
        CMS => "Whmcs",
    },
    ZenCart=>{
	REGEX	=>	"zenAdminID",
	REGEX2	=>	"zen cart",
        CMS => "Zencart",
    },
    
);

my @ips;
my $ua = LWP::UserAgent->new;
$ua->agent("msnbot/1.0 (+http://search.msn.com/msnbot.htm)");
$ua->timeout(20);

flag();
GetFiles();

my $pm = new Parallel::ForkManager($max_process);# preparing fork
print "[OK] Qantity of ip : ".scalar(@ips)." \n\n";
foreach my $ip (@ips){#loop => working
    my $pid = $pm->start and next;
    chomp($ip);
    do_work ($ip);
    $pm->finish;
}
$pm->wait_all_children();
print "\n";

sub rev_bing {
        my $ip = shift;
        my $page = 0;
        my (%group,@cont);
 
        while(1)
        {
        my $content = $ua->get("http://www.bing.com/search?q=ip:$ip&first=$page&FORM=PERE")->content;
        my $status = keys %group;
        while ( $content =~ /<cite>[:\/\/]*([\w\.\-]+)[\w+\/\.\-_:\?=]*<\/cite>/g) {
        $group{$1} = undef;
        }
        last if ($status == keys %group);
        $page += 10;
        }
        foreach my $s (keys %group) {push(@cont,sclean($s));}
        return(uniqq(@cont));
 
}
sub sclean {
        my $site = shift;
        $site =~ s/^www\.//g if $site =~ /^www\./;
        return $site;
}
sub uniqq {
        return keys %{{ map { $_ => 1 } @_ }};
}

sub GetFiles {
    open( DOM, $ip_list ) or die "$!\n";
    while( defined( my $line_ = <DOM> ) ) {
        chomp( $line_ );
        push(@ips, $line_ );
    }
    close( DOM );
}

sub save {
    my ($file,$item) = @_;
    open(SAVE,">>".$file);
    print SAVE $item."\n";
    close(SAVE);
}

sub do_work {
    my $ip = $_[0];
    my @sites = rev_bing($ip);
    print "[.] ".scalar(@sites)." grabbed from : ".$ip."\n";
    if (scalar (@sites) == 0) {die "[?] Can't grabbe Cms types\n";}
    foreach my $site (@sites){print "   | ".$site."\n" if ($verbose);}#printing website results
    if ($cms) {
        print "\n[!] Scanning website cms \n";
        foreach my $site (@sites){
            my $cms_type = cms_type ($site);
            if ($cms_type) {
                print "   | $site : $cms_type\n" if ($verbose);
                save ("$ip-cms.txt",$site.":".$cms_type);
            }
            else {
                print "   | $site : Unknow cms\n" if ($verbose);
                #save ("$ip-cms.txt",$site.":".$cms_type);
                
            }
        }
    }
}

sub cms_type {
    my $site = shift;
    my $xx = $ua->get("http://".$site."/") or die $!."\n";
    my $content = $xx->content;
    foreach  my $S (keys %OPT)
    {
        my $regex_content = $OPT{$S}->{REGEX};
        if ($OPT{$S}->{REGEX}){
            my $headers_string = $xx->headers()->as_string;
            if ($content =~ /$regex_content/ || $headers_string =~/$headers_string/) {
            return $OPT{$S}->{CMS};
            }
            else{return 0;}
        }    
        else {
            if ($content =~ /$regex_content/) {
            return $OPT{$S}->{CMS};
            }
            else{return 0;}
        }   
    }
}

sub flag {
    print q{
    
██╗  ██╗████████╗  █ Name   : Cms scanner
██║  ██║╚══██╔══╝  █ Author : Mr_AnarShi-T (M-A)
███████║   ██║     █ Home   : 0x30.cc
██╔══██║   ██║     █ web    : https://github.com/mranarshit
██║  ██║   ██║     █ Youtube: https://goo.gl/obdHlS
╚═╝  ╚═╝   ╚═╝     █ (c)    : Htlover

   };
print "\n";
}

sub help{
    flag();
    print "\nTarget list : \n";
    print "   At least one of these options has to be provided to define the target list\n";
    print "   -i List, --i=List   Target List (e.g. \"list_ip.txt\")\n";
    print "Max process :\n";
    print "   This options can be used to specify the number of process for fork\n";
    print "   -t MAXPR, --t=MAXPROCESS  Max process (e.g. 1 or 5 etc)\n";
    print "File Save :\n";
    print "   This options can be used to specify a file name to save results\n";
    print "   -f FILE, --t=FILE  File Name (e.g. log.txt etc)\n";
    print "Cms :\n";
    print "   This options can be used to scan website cms\n";
    print "   -cms Cms, --cms\n";
    print "Verbose :\n";
    print "   This options can be used to print results\n";
    print "   -v Verbose, --v\n\n";
    exit;
}