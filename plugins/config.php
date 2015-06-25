<?php
//---- Database Information - You must have a database aready created, then enter the info below:
define('DB_HOSTNAME', 'localhost');
define('DB_USER', 'rustu');
define('DB_PASSWORD', 'nasapuhu8');
define('DB_NAME', 'zadmin_rust');

//----- Settins - below are some settins to adjust section of the page

$playersperpage = '25'; // Total number of players to show on each page 
$tphysize = '50px'; // width of 1st, 2nd, and 3rd place trophies, height automatically adjust to keep aspect ratio
$iconsize = '25px'; // width of stat icons, height automatically adjust to keep aspect ratio

// ---- Server Information - for showing server banner and graphs

$serverip = '198.50.160.71:28016'; // Enter your server IP and PORT here example = '123.456.789:28016'
$gsid = ''; // Enter your servers gameserver ID# - this number is found in the URL of your servers detail page at www.gametracker.com
$teamspeakip = ''; // Enter your Teamspeak3 server IP here example = '123.456.789'
$teamspeakport = ''; // Enter your Teamspeak3 PORT here example = '2154'

?>