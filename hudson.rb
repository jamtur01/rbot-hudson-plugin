# redmine_urls crudely updated by James Turnbull 
# based on trac_urls written by wombie
# Needs to go in the plugins dir for rbot

require 'net/https'
require 'uri'
require 'rubygems'
require 'hpricot'

class InvalidHudson < Exception
end

class HudsonPlugin < Plugin
	Config.register Config::ArrayValue.new('hudson.channelmap',
		:default => [], :requires_restart => false,
		:desc => "A map of channels to the base Hudson URL that should be used " +
		         "in that channel.  Format for each entry in the list is " +
		         "#channel:http://hudson.site/to/use.  Don't put a trailing " +
		         "slash on the base URL, please.")

         Config.register Config::ArrayValue.new('hudson.projectmap',
                :default => [], :requires_restart => false,
                :desc => "A map of Hudson projects to authentication tokens." +
                         "Format for each entry in the list is #channel:project.")

         def help(plugin, topic="")
                 case topic
                         when '':
                                "This plug-in interacts with the Hudson test server." +
                                "Current the plug-in only triggers build (see subtopic " +
                                "'trigger')."
                         when 'trigger':
                                "Trigger project => Trigger the build of a project"
         end 

         def privmsg(m)
                 unless(m.params =~ /^(\S)+$/)
                     m.reply "incorrect usage: " + help(m.plugin)
                     return
                 end 

                 m.params.gsub!(/\?$/, "") 

                 puts "The param is" + m.params

                 msg = m.message.scan(/(?:^|\W)(#{@registry[m.params]}:\w+)(?:$|\W)/)

                 
                 if command == "trigger"
                     debug "This is a trigger"
                     trigger(@registry[m.params])
                 else
                     m.reply "Incorrect usage: " + help(m.plugin) 
                 end
                                       
         end 
	
        def project_channel(target)
               p = @bot.config['hudson.projectmap'].find {|p| p =~ /^#{target}:/ }
               p.gsub(	/^#{target}:/, '') unless p.nil?
        end

	# Return the base URL for the channel (passed in as +target+), or +nil+
	# if the channel isn't in the channelmap.
	#
	def base_url(target)
		e = @bot.config['hudson.channelmap'].find {|c| c =~ /^#{target}:/ }
		e.gsub(/^#{target}:/, '') unless e.nil?
	end
	
	def rev_url(base_url, project, token)
		base_url + '/repositories/revision/' + project + '/' + num
	end
	
	def bug_url(base_url, project, num)
		base_url + '/issues/show/' + num
	end
	
	def wiki_url(base_url, project, page)
		base_url + '/wiki/' + project + '/' + page
	end

	def expand_reference(ref, channel)
		debug "Expanding reference #{ref} in #{channel}"
		base = base_url(channel)
                project = project_channel(channel)

		# If we're not in a channel with a mapped base URL...
		return [nil, "I don't know about Redmine URLs for this channel - please add a channelmap for this channel"] if base.nil?

                # If we're in a channel without a mapped project...
                return [nil, "I don't have a project map for this channel - please add a projectmap for this channel"] if project.nil?

		debug "Base URL for #{channel} is #{base}"
                debug "Project for #{channel} is #{project}"

		begin
			url, reftype = ref_into_url(base, project, ref)
			css_query = css_query_for(reftype)

			content = unless css_query.nil?
				# Rip up the page and tell us what you saw
				page_element_contents(url, css_query)
			else
				# We don't know how to get meaningful info out of this page, so
				# just validate that it actually loads
				page_element_contents(url, 'h1')
				nil
			end
			
			[url, content]
		rescue InvalidRedmineUrl => e
			error("InvalidRedmineUrl returned: #{e.message}")
			return [nil, "I'm afraid I don't understand '#{ref}' or I can't find a page for it.  Sorry."]
		rescue Exception => e
			error("Error (#{e.class}) while fetching URL #{url}: #{e.message}")
			e.backtrace.each {|l| error(l)}
			return [nil, "#{url} #{e.message} #{e.class} - An error occured while I was trying to look up the URL.  Sorry."]
		end
	end

	def page_element_contents(url, css_query)
		parts = URI.parse(url)
		resp = nil
		ssl = @bot.config['redmine_urls.https']
		b_auth = @bot.config['redmine_urls.basic_auth']
		b_auth_uname = @bot.config['redmine_urls.basic_auth_username']
		b_auth_pword = @bot.config['redmine_urls.basic_auth_password']
		debug("Setup: https: #{ssl}, auth: #{@bot.config['redmine_urls.basic_auth']} username: #{@bot.config['redmine_urls.basic_auth_username']} password: #{@bot.config['redmine_urls.basic_auth_password']}")
		if @bot.config['redmine_urls.https']
			port = 443
		else
			port = 80
		end
		http = Net::HTTP.new(parts.host, port)
		http.use_ssl = @bot.config['redmine_urls.https']
		debug("use_ssl is #{http.use_ssl}")
		http.start do |http| 
			request = Net::HTTP::Get.new(parts.path)
			if @bot.config['redmine_urls.basic_auth']
				debug("trying to use http basic auth")
				request.basic_auth @bot.config['redmine_urls.basic_auth_username'], @bot.config['redmine_urls.basic_auth_password']
			end
			resp = http.request(request)
		end

		debug("Response object is #{resp.inspect} for #{url}")
		raise InvalidRedmineUrl.new("#{url} returned #{resp.code} #{resp.message}") unless resp.code == '200'
		elem = Hpricot.parse(resp.body).search(css_query).first
		unless elem
			warning("Didn't find '#{css_query}' in response #{resp.body}")
			return
		end
		debug("Found '#{elem.inner_text}' with '#{css_query}'")
		elem.inner_text.gsub("\n", ' ').gsub(/\s+/, ' ').strip
	end
end

plugin = HudsonPlugin.new
plugin.register("trigger")
plugin.map "hudson"
