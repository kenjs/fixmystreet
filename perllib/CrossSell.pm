#!/usr/bin/perl -w
#
# CrossSell.pm:
# Adverts from FixMyStreet to another site.
#
# Unlike the PHP crosssell script, returns strings rather than prints them;
# and currently displays the same advert if e.g. there's a connection problem.
# 
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: CrossSell.pm,v 1.12 2008-09-10 18:06:30 matthew Exp $

# Config parameters site needs set to call these functions:
# OPTION_AUTH_SHARED_SECRET
# OPTION_HEARFROMYOURMP_BASE_URL

package CrossSell;

use strict;
use LWP::Simple qw($ua get);
$ua->timeout(5);
use URI::Escape;
use mySociety::AuthToken;
use mySociety::Web qw(ent);

sub display_random_hfymp_advert {
    my ($email, $name, $text) = @_;
    $name ||= '';
    my $auth_signature = mySociety::AuthToken::sign_with_shared_secret($email, mySociety::Config::get('AUTH_SHARED_SECRET'));

    # See if already signed up
    my $url = mySociety::Config::get('HEARFROMYOURMP_BASE_URL');
    my $already_signed = get($url . '/authed?email=' . uri_escape($email) . "&sign=" . uri_escape($auth_signature));
    # Different from PHP version; display this advert if e.g. connection problem
    return '' if $already_signed && $already_signed eq 'already signed';

    $email = ent($email);
    $name = ent($name);
    $auth_signature = ent($auth_signature);
    $text =~ s#\[form\]#<form action="http://www.hearfromyourmp.com/" method="post">
<input type="hidden" name="name" value="$name">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="sign" value="$auth_signature">
<h2><input style="font-size:100%" type="submit" value="#;
    $text =~ s#\[/form\]#"></h2>#;

    return '<div id="advert_hfymp">' . $text . '</div>';
}

sub display_random_gny_advert {
    my ($email, $name, $text) = @_;
    return '<div id="advert_thin">' . $text . '</div>';
}

sub display_random_twfy_alerts_advert {
    my ($email, $name, $text) = @_;
    my $auth_signature = mySociety::AuthToken::sign_with_shared_secret($email, mySociety::Config::get('AUTH_SHARED_SECRET'));
    $text =~ s#\[button\]#<form action="http://www.theyworkforyou.com/alert/" method="post">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="sign" value="$auth_signature">
<input type="hidden" name="site" value="fms">
<input style="font-size:150%" type="submit" value="#;
    $text =~ s#\[/button\]#"></p>#;
    return '<div id="advert_thin" style="text-align:center">' . $text . '</div>';
}

sub display_hfyc_cheltenham_advert {
    my ($email, $name) = @_;
    $name ||= '';
    my $auth_signature = mySociety::AuthToken::sign_with_shared_secret($email, mySociety::Config::get('AUTH_SHARED_SECRET'));

    # See if already signed up
    my $already_signed = get('http://cheltenham.hearfromyourcouncillor.com/authed?email=' . uri_escape($email) . "&sign=" . uri_escape($auth_signature));
    # Different from PHP version; display this advert if e.g. connection problem
    return '' if $already_signed && $already_signed eq 'already signed';

    # If not, display advert
    $email = ent($email);
    $name = ent($name);
    $auth_signature = ent($auth_signature);
    my $out = <<EOF;
<form action="http://cheltenham.hearfromyourcouncillor.com/" method="post">
<input type="hidden" name="name" value="$name">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="sign" value="$auth_signature">
<div id="advert_thin">
EOF

    my $rand = int(rand(2));
    if ($rand == 0) {
        $out .= "<h2>Cool! You're interested in Cheltenham!</h2>
        <p>We've got an exciting new free service that works exclusively
        for people in Cheltenham. Please sign up to help the charity
        that runs WriteToThem, and to get a sneak preview of our new
        service.</p>";
    } else {
        $out .= "<h2>Get to know your councillors.</h2>
        <p>Local councillors are really important, but hardly anyone knows them.
        Use our new free service to build a low-effort, long term relationship
        with your councillor.</p>";
    }
    $out .= <<EOF;
<p align="center">
<input type="submit" value="Sign up to HearFromYourCouncillor">
</p>
</div>
</form>
EOF
    return ($out, "cheltenhamhfyc$rand");
}

sub display_tms_form {
    my (%input) = @_;
    my %input_h = map { $_ => $input{$_} ? ent($input{$_}) : '' } qw(name email postcode mobile signed_email);
    my $auth_signature = $input_h{signed_email};
    return <<EOF;
<h1 style="padding-top:0.5em">Coming Soon: TextMyStreet</h1>

<p>Exclusive to FixMyStreet users: Sign up for a <strong>brand new</strong>, not-yet-launched
service which will make it easy to send short messages to other people on <strong>your
street</strong> and just round the corner.</p>

<p>Use it to borrow a strimmer, discuss the weather or report a <strong>lost cat</strong>.</p>

<form action="/tms-signup" method="post">
<input type="hidden" name="signed_email" value="$auth_signature">
<label for="name">Name:</label>
<input type="text" name="name" id="name" value="$input_h{name}" size="30">
<br><label for="email">Email:</label>
<input type="text" name="email" id="email" value="$input_h{email}" size="30">
<br><label for="postcode">Postcode:</label> 
<input type="text" name="postcode" id="postcode" value="$input_h{postcode}" size="11">
<br><label for="mobile">Mobile:</label> <input type="text" name="mobile" id="mobile" value="$input_h{mobile}" size="11">
&nbsp; <input type="submit" class="submit" value="Sign up">
</form>

<p>mySociety respects your privacy, and we'll never sell or give away your private
details. Once we launch we'll send you some emails and perhaps some texts
explaining how it works, and it'll never cost you a penny unless we explicitly
say it will. You'll be able to <strong>unsubscribe</strong> at any time.</p>
EOF
}

# Choose appropriate advert and display it.
# $this_site is to stop a site advertising itself.
sub display_advert ($$;$%) {
    my ($q, $email, $name, %data) = @_;

    if (defined $data{council} && $data{council} eq '2326') {
        my ($out, $ad) = display_hfyc_cheltenham_advert($email, $name);
        if ($out) {
            $q->{scratch} = "advert=$ad";
            return $out;
        }
    }

    $q->{scratch} = 'advert=tms';
    my $auth_signature = '';
    unless (defined $data{emailunvalidated} && $data{emailunvalidated}==1) {
        $auth_signature = mySociety::AuthToken::sign_with_shared_secret($email, mySociety::Config::get('AUTH_SHARED_SECRET'));
    }
    return '<div style="margin: 0 5em; border-top: dotted 1px #666666;">'
        . display_tms_form(email => $email, name => $name, signed_email => $auth_signature)
        . '</div>';

    my @adverts = (
        [ 'gny0', '<h2>Are you a member of a local group&hellip;</h2> &hellip;which uses the internet to coordinate itself, such as a neighbourhood watch? If so, please help the charity that runs FixMyStreet by <a href="http://www.groupsnearyou.com/add/about/">adding some information about it</a> to our new site, GroupsNearYou.' ],
        [ 'gny1', '<h2>Help us build a map of the world&rsquo;s local communities &ndash;<br><a href="http://www.groupsnearyou.com/add/about/">Add one to GroupsNearYou</a></h2>' ],
        #  Since you're interested in your local area, why not
        #  start a long term relationship with your MP?
        #[ 'hfymp0', '<h2 style="margin-bottom:0">Get email from your MP in the future</h2> <p style="font-size:120%;margin-top:0;">and have a chance to discuss what they say in a public forum [form]Sign up to HearFromYourMP[/form]' ],
        #[ 'twfy_alerts0', '<h2>Get emailed every time your MP says something in Parliament</h2> [button]Keep an eye on them for free![/button]' ],
    );
    while (@adverts) {
        my $rand = int(rand(scalar @adverts));
        next unless $adverts[$rand];
        my ($advert_id, $advert_text) = @{$adverts[$rand]};
        (my $advert_site = $advert_id) =~ s/\d+$//;
        my $func = "display_random_${advert_site}_advert";
        no strict 'refs';
        my $out = &$func($email, $name, $advert_text);
        use strict 'refs';
        if ($out) {
            $q->{scratch} = "advert=$advert_id";
            return $out;
        }

        for (my $i=0; $i<@adverts; $i++) {
            (my $a = $adverts[$i][0]) =~ s/\d+$//;
            delete $adverts[$i] if $advert_site eq $a;
        }
    }

    $q->{scratch} = 'advert=pb';
    return <<EOF;
<div id="advert_thin" style="text-align:center">
<h2 style="font-size: 150%">
If you're interested in improving your local area,
<a href="http://www.pledgebank.com/">use PledgeBank</a> to
do so with other people!</h2>
</div>
EOF
}

1;
