# hudson redmine_by James Turnbull 
# Needs to go in the plugins dir for rbot

require 'uri'
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
                "This plug-in interacts with the Hudson test server. " +
                "Currently the plug-in only triggers builds."
         end 

         def trigger(m, params)
               unless params[:project]
                  m.reply "Incorrect usage: " + help(m.plugin)
               else
                  channel = m.target
                  debug "The channel is #{channel}"
                  
                  project_name = URI.escape(params[:project].to_s)
                  debug "The project name is #{project_name}"                    

                  base = base_url(channel) 
                  debug "The Hudson URL is #{base}"
                  return [nil, "I don't know about a Hudson URL for this channel - please add a channelmap for this channel"] if base.nil?
                    
                  token = project_token(params[:project].to_s)
                  debug "The token is #{token}"
                  return [nil, "I don't have a project map for this channel - please add a projectmap for this channel"] if token.nil?

                  debug "Triggering in #{channel} the #{project_name} at #{base} with #{token}"
  
                  url = trigger_url(base, project_name, token)

                  debug "The Hudson triggerign URL is #{url}"
           
                  trigger_project(url)

                  m.reply "Triggering a build of #{project_name}"
               end
        end

        def trigger_project(url)
               puts open("#{url}", "User-Agent" => "Ruby-Wget").read
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
	
	def trigger_url(base, project_name, token)
	        base + '/job/' + project_name + '/build?token=' + token
	end

end

plugin = HudsonPlugin.new

plugin.map "trigger *project", :action => "trigger"

