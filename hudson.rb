# redmine_urls crudely updated by James Turnbull 
# based on trac_urls written by wombie
# Needs to go in the plugins dir for rbot

require 'net/https'
require 'uri'
require 'rubygems'
require 'hpricot'
require 'open-uri'

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
                         "Format for each entry in the list is project:authtoken.")

         def help(plugin, topic="")
                 case topic
                         when '':
                                "This plug-in interacts with the Hudson test server. " +
                                "Currently the plug-in only triggers build (see subtopic " +
                                "'trigger')."
                         when 'trigger':
                                "trigger project => Trigger the build of a project"
                 end
         end 

         def trigger(m, params)

             unless params[:project]
                    m.reply "Incorrect usage: " + help(m.plugin)
             else
                    channel = m.target
                    project = params[:project]
                    
                    base = base_url(channel) 
                    return [nil, "I don't know about a Hudson URL for this channel - please add a channelmap for this channel"] if base.nil?
                    
                    token = project_token(project)
                    return [nil, "I don't have a project map for this channel - please add a projectmap for this channel"] if token.nil?

                    debug "Triggering in #{channel} the #{project} at #{base} with #{token}"
                    m.reply "Triggering in #{channel} the #{project} at #{base} with #{token}"
                   
             end

         end

         def trigger_project
                debug "Expanding reference #{ref} in #{channel}"
                base = base_url(channel)

             puts open('http://hudson.url', 'User-Agent' => 'Ruby-Wget').read


         end

        private 	
        def project_token(project)
               p = @bot.config['hudson.projectmap'].find {|p| p =~ /^#{project}:/ }
               p.gsub(	/^#{project}:/, '') unless p.nil?
        end

	def base_url(target)
		e = @bot.config['hudson.channelmap'].find {|c| c =~ /^#{target}:/ }
		e.gsub(/^#{target}:/, '') unless e.nil?
	end
	
	def trigger_url(base, project, token)
		base + '/job/' + project + '/build?token=' + token
	end

end

plugin = HudsonPlugin.new
plugin.map 'trigger :project', :action => 'trigger'
