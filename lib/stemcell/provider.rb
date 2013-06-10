module Stemcell
  class Provider

    def verify_required_options(params,required_options)
      @log.debug "params is #{params}"
      @log.debug "required_options are #{required_options}"
      required_options.each do |required|
        raise ArgumentError, "you need to provide option #{required}" unless params.include?(required)
      end
    end

    def render_template(template, opts={})
      this_file = File.expand_path __FILE__
      base_dir = File.dirname this_file
      template_file_path = File.join(base_dir, 'templates', template)
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      generated_template = erb_template.result(binding)
      @log.debug "genereated template is #{generated_template}"
      return generated_template
    end

    # attempt to accept keys as file paths
    def try_file(opt="")
      begin
        return File.read(opt)
      rescue Object => e
        return opt
      end
    end

  end
end
