# Distribution Repository

This directory contains everything needed to set up a distribution
point for perfSONAR using the Apache web server.


## Installation

1.  Verify that Apache is installed and running on your system.

1.  Verify that things in the receiver directory (../receiver) are
properly set up.

1.  In this directory, run `make`.

1.  Install the `downloads.perfsonar.net.conf` file into `/etc/httpd/conf.d`.

1.  Restart Apache



## Removal

1.  Remove the `downloads.perfsonar.net.conf` from `/etc/httpd/conf.d`.

1.  Restart Apache
