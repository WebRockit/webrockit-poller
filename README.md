### webrockit-poller

This package builds the webrockit-poller staging the base path to /opt/phantomjs/collectoids/webrockit-poller.  The package webrockit-poller must exist on a webrockit poller client (Sensu client).

### Requirements

The gem "ghost" must be installed to handle DNS overrides when specifying a specific IP address.

### To build

   - run ./buildme.sh

The final package is located under ./finalpkg/

### Command Line Options

Usage: webrockit-poller.rb [options]
<pre>
    -d, --debug                     Enable debug output
    -f, --format [STRING]           Output data and status as plain(text/tsv) or json (default: plain)
    -i, --ip [IP ADDRESS]           Override DNS or provide IP for request (default: use dns)
    -l, --ps-extra-opts [STRING]    Extra Phantomas Options (default: no options) [eg -l 'debug' -l 'proxy=localhost']
    -m, --metricdetail [STRING]     Level of data to output: minimal, standard, verbose  (default: standard)
    -p, --phantomas [PATH]          Path to Phantomas binary (default: /opt/phantomjs/collectoids/phantomas/bin/phantomas.js)
    -u, --url [STRING]              URL to query (mandatory option)
</pre>

    

### Example
<pre>
$ webrockit-poller.rb --url http://github.com
timetofirstbyte         298     1393542372
httptrafficcompleted    3284    1393542372
contentlength           1375143 1393542372
bodysize                462576  1393542372
domains                 5       1393542372
requests                22      1393542372
redirects               2       1393542372
notfound                0       1393542372
pollerstatus            0       1393542377
</pre>

### License
   webrockit-poller is released under the MIT license, and may bundle other liberally licensed OSS components [License](LICENSE.txt)  
   [Third Party Software](third-party.txt)
