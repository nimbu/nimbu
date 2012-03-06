require "nimbu/command/base"

# working with themes (upload / download)
#
class Nimbu::Command::Themes < Nimbu::Command::Base

  # server
  #
  # list available commands or display help for a specific command
  #
  def index
    themes = json_decode(nimbu.list_themes)
    if themes.any?
      puts "You have following themes for this website:"
      themes.each do |theme|
        puts " - #{theme['theme']['name']} (#{theme['theme']['id']})"
      end
    else
      puts "Hm. You seem to have no themes. Is that normal?"
    end
    puts ""
    puts "Currently this directory is configured for '#{Nimbu::Auth.theme}'"
  end

  # list
  #
  # list all layouts, templates and assets
  #
  def list
    input = args.shift.downcase rescue nil
    if !input.to_s.strip.empty?
      theme = input.to_s.strip
    else
      theme = Nimbu::Auth.theme
    end
    display "Showing layouts, templates and assets for '#{theme}':"
    contents = json_decode(nimbu.show_theme_contents(theme))
    contents["layouts"].each do |l|
      display " - layouts/#{l["name"]}"
    end unless contents["layouts"].nil?
    contents["templates"].each do |t|
      display " - templates/#{t["name"]}"
    end unless contents["templates"].nil?
    contents["assets"].each do |a|
      display " - #{a["folder"]}/#{a["name"]}"
    end unless contents["assets"].nil?
  end

  # download
  #
  # download all layouts, templates and assets
  #
  def download
    input = args.shift.downcase rescue nil
    if !input.to_s.strip.empty?
      theme = input.to_s.strip
    else
      theme = Nimbu::Auth.theme
    end
    display "Downloading layouts, templates and assets for '#{theme}':"
    contents = json_decode(nimbu.show_theme_contents(theme))
    contents["layouts"].each do |asset|
      print " - layouts/#{asset["name"]}"
      data = json_decode(nimbu.fetch_theme_layout(theme,asset["id"]))
      filename = File.join(Dir.pwd,"layouts",asset["name"])
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'w') do |file| 
        file.puts(data["code"])
      end

      print " (ok)\n"
    end

    contents["templates"].each do |asset|
      print " - templates/#{asset["name"]}"
      data = json_decode(nimbu.fetch_theme_template(theme,asset["id"]))
      filename = File.join(Dir.pwd,"templates",asset["name"])
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'w') do |file| 
        file.puts(data["code"])
      end

      print " (ok)\n"
    end
  end

  # download
  #
  # download all layouts, templates and assets
  #
  def push
    simulate = args.include?("--dry-run") || args.include?("-d")
    liquid_only = args.include?("--liquid-only") || args.include?("--liquid")
    css_only = args.include?("--css-only") || args.include?("--css")
    js_only = args.include?("--js-only") || args.include?("-js")

    # if !input.to_s.strip.empty?
    #   theme = input.to_s.strip
    # else
    # end
    theme = Nimbu::Auth.theme
    display "Pushing layouts, templates and assets for '#{theme}' to the server:"
    
    layouts_glob = Dir.glob("#{Dir.pwd}/layouts/**/*.liquid")
    layouts_files = layouts_glob.map {|dir| dir.gsub("#{Dir.pwd}/layouts/","")}
    templates_glob = Dir.glob("#{Dir.pwd}/templates/**/*.liquid")
    templates_files = templates_glob.map {|dir| dir.gsub("#{Dir.pwd}/templates/","")}

    if !(css_only || js_only)
      print "\nLayouts:\n"
      layouts_files.each do |layout|
        file = "#{Dir.pwd}/layouts/#{layout}"
        next if File.directory?(file)
        print " - layouts/#{layout}"
        nimbu.upload_layout(theme, layout, IO.read(file))
        print " (ok)\n"
      end      

      print "\nTemplates:\n"
      templates_files.each do |template|
        file = "#{Dir.pwd}/templates/#{template}"
        next if File.directory?(file)
        print " - templates/#{template}"
        nimbu.upload_template(theme, template, IO.read(file))
        print " (ok)\n"
      end
    end

    if !liquid_only
      css_glob = Dir.glob("#{Dir.pwd}/stylesheets/**/*.css")
      css_files = css_glob.map {|dir| dir.gsub("#{Dir.pwd}/stylesheets/","")}
      if !js_only
        print "\nStylesheet:\n"
        css_files.each do |css|
          file = "#{Dir.pwd}/stylesheets/#{css}"
          next if File.directory?(file) || (!anyFileWithWord?(layouts_glob,css) && !anyFileWithWord?(templates_glob,css))
          nimbu.upload_asset(theme, "stylesheets/#{css}", File.open(file))
          print " - stylesheets/#{css}"
          print " (ok)\n"
        end
      end

      js_glob = Dir.glob("#{Dir.pwd}/javascripts/**/*.js")
      js_files = js_glob.map {|dir| dir.gsub("#{Dir.pwd}/javascripts/","")}
      if !css_only
        print "\nJavascripts:\n"
        js_files.each do |js|
          file = "#{Dir.pwd}/javascripts/#{js}"
          next if File.directory?(file) || (!anyFileWithWord?(layouts_glob,js) && !anyFileWithWord?(templates_glob,js))
          nimbu.upload_asset(theme, "javascripts/#{js}", File.open(file))
          print " - javascripts/#{js}"
          print " (ok)\n"
        end
      end

      image_files = Dir.glob("#{Dir.pwd}/images/**/*").map {|dir| dir.gsub("#{Dir.pwd}/images/","")}
      if !(css_only || js_only)
        print "\nImages:\n"
        image_files.each do |image|
          file = "#{Dir.pwd}/images/#{image}"
          next if File.directory?(file) || (!anyFileWithWord?(css_glob,image) && !anyFileWithWord?(js_glob,image) && !anyFileWithWord?(layouts_glob,image) && !anyFileWithWord?(templates_glob,image))
          nimbu.upload_asset(theme, "images/#{image}", File.open(file))
          print " - images/#{image}"
          print " (ok)\n"
        end
      end
    end
  end

  private 

  def anyFileWithWord?(glob,word)
    found = false
    glob.each do |file|
      found = true if fileHasWord?(file,word)
    end
    return found
  end

  def fileHasWord?(file,word)
    File.open(file) do |f|
      f.any? do |line|
        line.include?(word)
      end
    end
  end
end