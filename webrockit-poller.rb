#!/opt/sensu/embedded/bin/ruby

require 'json'
require 'uri'
require 'time'
require 'optparse'
require 'timeout'

options = {}
options[:phantomas_bin] = "/opt/phantomjs/collectoids/phantomas/bin/phantomas.js"
options[:phantomas_opts] = "--format=json "
options[:ghost_bin] = "/opt/phantomjs/collectoids/webrockit-poller/ghost"
options[:phantomas_extra_ops] = [ ]
options[:phantomas_external_opts] = ""
options[:critical] = 30
options[:limitexternal] = ""
options[:debug] = false
options[:jsonreports] = false
options[:format] = "plain"
options[:metricdetail] = "standard"

def bail(msg,format="plain")
   nowstamp = Time.now.to_i 
   statusdata = JSON.parse(msg)
   if format.to_s == "plain"
      puts "pollerstatus\t" + statusdata['pollstatus'].to_s + "\t#{nowstamp}\n"
      if statusdata['pollstatus'].to_s != "0"
         puts "errormsg\t\"" + statusdata['errormsg'].to_s + "\"\t#{nowstamp}\n"
      end
   elsif format.to_s == "json" && statusdata['pollstatus'].to_s != "0"
      puts msg
   end
   exit statusdata['status'].to_i
end

OptionParser.new do |opts|
   nowstamp = Time.now.to_i 
   opts.banner = "Usage: #{$0} [options]"

   opts.on("-d", "--debug", "Enable debug output") do
      options[:debug] = true
   end
   opts.on("-e", "--external none,limit", "Define external asset fetching") do |e|
      begin
         if e.to_s.empty?
            raise
         end
      rescue
         bail("{\"pollstatus\":1,\"errormsg\":\"No exteral asset parameter provided, please use --external [none,limit]\"}",options[:limitexternal])
      end
      options[:limitexternal] = e
   end
   opts.on("-f", "--format json,plain", "Output data and status as plain(text/tsv) or json (default: plain)") do |f|
      begin
         if f.to_s.empty?
            raise
         end
      rescue
         bail("{\"pollstatus\":1,\"errormsg\":\"No format provided, please use --format [plain,json]\"}",options[:format])
      end
      options[:format] = f
   end
   opts.on("-i", "--ip x.x.x.x", "Override DNS or provide IP for request (default: use dns)") do |i|
      begin
         if i =~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/
            options[:ip_address] = i
         else
            raise
         end
      rescue
         bail("{\"pollstatus\":1,\"errormsg\":\"No ip provided after ip option, please use --ip x.x.x.x\"}",options[:format])
      end
   end
   opts.on("-l", "--ps-extra-opts [STRING]", "Extra Phantomas Options (default: no options) [eg -l 'debug' -l 'proxy=localhost']") do |l|
      options[:phantomas_extra_ops] << "--" + l.to_s
   end
   opts.on("-m", "--metricdetail minimal,standard,verbose", "Level of data to output (default: standard)") do |m|
      begin
         if m.to_s.empty?
            raise
         end
      rescue
         bail("{\"pollstatus\":1,\"errormsg\":\"No metriclevel provided, please use -m [minimal, standard, verbose]\"}",options[:format])
      end
      options[:metricdetail] = m
   end
   opts.on("-p", "--phantomas [PATH]", "Path to Phantomas binary (default: #{options[:phantomas_bin]})") do |p|
      options[:phantomas_bin] = p
   end
   opts.on("-u", "--url [STRING]", "URL to query" ) do |u|
      begin
         if u.to_s.empty?
            raise
         end
      rescue   
         bail("{\"pollstatus\":1,\"errormsg\":\"Empty url provided, please use --url http://example.tld\"}",options[:format])
      end
      options[:url] = u
      options[:domain] = u.sub(/^https?\:\/\//, '').split("/")[0]
   end
end.parse!

unless File.executable?(options[:phantomas_bin])
   bail("{\"pollstatus\":3,\"errormsg\":\"Could not find Phantomas binary (#{options[:phantomas_bin]})\"}",options[:format])
end
if !options[:ip_address].to_s.empty?
   cmd = Array.new
   cmd << "sudo env GEM_PATH=/opt/sensu/embedded/lib/ruby/gems/2.0.0 "+options[:ghost_bin]+" modify "+options[:domain]+" "+options[:ip_address]
   cmd << "2> /dev/null"
   warn "Ghost cmd is: " + cmd.join(" ") if options[:debug]
   @pipe = IO.popen(cmd.join(" "))
   output = @pipe.read
   Process.wait(@pipe.pid)
end

if options[:url].to_s.empty?
   bail("{\"pollstatus\":1,\"errormsg\":\"No url provided, please use --url http://example.tld\"}",options[:format])
end
if options[:format].to_s.empty?
   bail("{\"pollstatus\":1,\"errormsg\":\"Missing or bad format provided, please use --format [plain,json]\"}",options[:format])
end

#  --no-externals block requests to 3rd party domains
#  --allow-domain=[domain],[domain] allow requests to given domain(s) - aka whitelist
#  --block-domain=[domain],[domain] disallow requests to given domain(s) - aka blacklist
if options[:limitexternal].to_s == "none"
  options[:phantomas_external_opts] = "--no-externals"
elsif options[:limitexternal].to_s == "limit"
  options[:phantomas_external_opts] = "--no-externals --allow-domain ."+options[:domain]
end

website_url = URI(options[:url])
website_load_time = 0.0

# Run Phantomas
output = ""
nowstamp = Time.now.to_i 
begin
   Timeout::timeout(options[:critical].to_i + 3) do
      cmd = Array.new
      cmd << options[:phantomas_bin]
      cmd << options[:phantomas_opts]
      cmd << options[:phantomas_extra_ops]
      cmd << options[:phantomas_external_opts]
      cmd << " --url " + website_url.to_s
      cmd << "2> /dev/null"
      warn "Phantomas cmd is: " + cmd.join(" ") if options[:debug]
      @pipe = IO.popen(cmd.join(" "))
      output = @pipe.read
      Process.wait(@pipe.pid)
   end
rescue Timeout::Error => e
   critical_time_ms = options[:critical].to_i * 1000
   Process.kill(9, @pipe.pid)
   Process.wait(@pipe.pid)
   bail("{\"pollstatus\":2,\"errormsg\":\"Critical: #{website_url.to_s}: Timeout after: #{options[:critical]} | load_time=#{critical_time_ms.to_s}\"}",options[:format])
end

begin
   warn "JSON Output:\n" + output if options[:debug]
   hash = JSON.parse(output)
rescue
   bail("{\"pollstatus\":3,\"errormsg\":\"Poller returned nil output\"}",options[:format])
end

if options[:metricdetail].to_s == "verbose"
   metrics = ['requests', 
      'gzipRequests', 
      'postRequests', 
      'httpsRequests', 
      'redirects', 
      'notFound', 
      'timeToFirstByte', 
      'timeToLastByte', 
      'bodySize', 
      'contentLength', 
      'ajaxRequests', 
      'htmlCount', 
      'htmlSize', 
      'cssCount', 
      'cssSize', 
      'jsCount', 
      'jsSize', 
      'jsonCount', 
      'jsonSize', 
      'imageCount', 
      'imageSize', 
      'webfontCount', 
      'webfontSize', 
      'base64Count', 
      'base64Size', 
      'otherCount', 
      'otherSize', 
      'cacheHits', 
      'cacheMisses', 
      'cachingNotSpecified', 
      'cachingTooShort', 
      'cachingDisabled', 
      'domains', 
      'maxRequestsPerDomain', 
      'medianRequestsPerDomain', 
      'DOMqueries', 
      'DOMqueriesById', 
      'DOMqueriesByClassName', 
      'DOMqueriesByTagName', 
      'DOMqueriesByQuerySelectorAll', 
      'DOMinserts', 
      'DOMqueriesDuplicated', 
      'eventsBound', 
      'headersCount', 
      'headersSentCount', 
      'headersRecvCount', 
      'headersSize', 
      'headersSentSize', 
      'headersRecvSize', 
      'documentWriteCalls', 
      'evalCalls', 
      'jQueryOnDOMReadyFunctions', 
      'jQuerySizzleCalls', 
      'assetsNotGzipped', 
      'assetsWithQueryString', 
      'smallImages', 
      'multipleRequests', 
      'timeToFirstCss', 
      'timeToFirstJs', 
      'timeToFirstImage', 
      'onDOMReadyTime', 
      'onDOMReadyTimeEnd', 
      'windowOnLoadTime', 
      'windowOnLoadTimeEnd', 
      'httpTrafficCompleted', 
      'windowAlerts', 
      'windowConfirms', 
      'windowPrompts', 
      'consoleMessages', 
      'cookiesSent', 
      'cookiesRecv', 
      'domainsWithCookies', 
      'documentCookiesLength', 
      'documentCookiesCount', 
      'bodyHTMLSize', 
      'iframesCount', 
      'imagesWithoutDimensions', 
      'commentsSize', 
      'hiddenContentSize', 
      'whiteSpacesSize', 
      'DOMelementsCount', 
      'DOMelementMaxDepth', 
      'nodesWithInlineCSS', 
      'globalVariables', 
      'jsErrors', 
      'localStorageEntries', 
      'smallestResponse', 
      'biggestResponse', 
      'fastestResponse', 
      'slowestResponse', 
      'medianResponse']
elsif options[:metricdetail].to_s == "minimal"
   metrics = ['timeToFirstByte',
      'httpTrafficCompleted']
else
   metrics = ['timeToFirstByte',
      'httpTrafficCompleted', 
      'contentLength', 
      'bodySize', 
      'domains', 
      'requests',
      'redirects', 
      'notFound']
end

metriccount = 0

if options[:format].to_s == "plain"
   metrics.each { |metric| 
      metricvalue = hash['metrics'][metric]
      puts metric.downcase + "\t#{metricvalue}\t#{nowstamp}\n"
   }
elsif options[:format].to_s == "json"
   print "[{"
   metrics.each { |metric| 
      metricvalue = hash['metrics'][metric]
      print "\"" + metric.downcase + "\":[ #{metricvalue}, #{nowstamp}]"
      metriccount += 1
      if metriccount != metrics.length
         print ","
      end
   }
   print "}]"
end


bail("{\"pollstatus\":0,\"errormsg\":\"Great success!\"}",options[:format])
