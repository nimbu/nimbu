require "nimbu/command/base"

# working with themes (upload / download)
#
class Nimbu::Command::Themes < Nimbu::Command::Base

  # server
  #
  # list available commands or display help for a specific command
  #
  def index
    themes = nimbu.themes(:subdomain => Nimbu::Auth.site).list
    if themes.any?
      display "\nYou have following themes for this website:"
      themes.each do |theme|
        puts " - #{theme.name.bold} (#{theme.short})"
      end
    else
      puts "Hm. You seem to have no themes. Is that normal?"
    end
    puts ""
    puts "Currently this directory is configured for '#{Nimbu::Auth.theme.red.bold}'"
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
    display "\nShowing layouts, templates, snippets and assets for '#{theme.red.bold}':"
    contents = nimbu.themes(:subdomain => Nimbu::Auth.site).get(theme)
    if contents["layouts"].any?
      display "\nLayouts:".bold
      contents["layouts"].each do |l|
        display " - layouts/#{l["name"]}"
      end
    end

    if contents["templates"].any?
      display "\nTemplates:".bold
      contents["templates"].each do |t|
        display " - templates/#{t["name"]}"
      end
    end

    if contents["snippets"].any?
      display "\nSnippets:".bold
      contents["snippets"].each do |s|
        display " - snippets/#{s["name"]}"
      end
    end

    if contents["assets"].any?
      display "\nAssets:".bold
      contents["assets"].each do |a|
        display " - #{a["folder"]}/#{a["name"]}"
      end
    end
  end

  # push
  #
  # push all layouts, templates and assets
  # --liquid, --liquid-only   # only push template code
  # --css, --css-only   # only push template code
  # --js, --js-only   # only push template code
  # --images-only   # only push new images
  #
  def push
    liquid_only = options[:liquid]
    css_only = options[:css]
    js_only = options[:js]
    images_only = options[:images_only]

    puts options
    puts images_only

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
    snippets_glob = Dir.glob("#{Dir.pwd}/snippets/**/*.liquid")
    snippets_files = snippets_glob.map {|dir| dir.gsub("#{Dir.pwd}/snippets/","")}

    if !(css_only || js_only || images_only)
      print "\nLayouts:\n"
      layouts_files.each do |layout|
        file = "#{Dir.pwd}/layouts/#{layout}"
        next if File.directory?(file)
        print " - layouts/#{layout}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).layouts(:theme_id => theme).create({:name => layout, :content => IO.read(file)})
        print " (ok)\n"
      end

      print "\nTemplates:\n"
      templates_files.each do |template|
        file = "#{Dir.pwd}/templates/#{template}"
        next if File.directory?(file)
        print " - templates/#{template}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).templates(:theme_id => theme).create({:name => template, :content => IO.read(file)})
        print " (ok)\n"
      end

      print "\nSnippets:\n"
      snippets_files.each do |snippet|
        file = "#{Dir.pwd}/snippets/#{snippet}"
        next if File.directory?(file)
        print " - snippets/#{snippet}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).snippets(:theme_id => theme).create({:name => snippet, :content => IO.read(file)})
        print " (ok)\n"
      end
    end

    if !liquid_only
      css_glob = Dir.glob("#{Dir.pwd}/stylesheets/**/*.css")
      css_files = css_glob.map {|dir| dir.gsub("#{Dir.pwd}/stylesheets/","")}
      if !(js_only || images_only)
        print "\nStylesheet:\n"
        css_files.each do |css|
          file = "#{Dir.pwd}/stylesheets/#{css}"
          next if File.directory?(file) || (!anyFileWithWord?(layouts_glob,css) && !anyFileWithWord?(templates_glob,css))
          io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
          nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "stylesheets/#{css}", :file => io})
          print " - stylesheets/#{css}"
          print " (ok)\n"
        end
      end

      js_glob = Dir.glob("#{Dir.pwd}/javascripts/**/*.js")
      js_files = js_glob.map {|dir| dir.gsub("#{Dir.pwd}/javascripts/","")}
      if !(css_only || images_only)
        print "\nJavascripts:\n"
        js_files.each do |js|
          file = "#{Dir.pwd}/javascripts/#{js}"
          next if File.directory?(file) || (!anyFileWithWord?(layouts_glob,js) && !anyFileWithWord?(templates_glob,js))
          io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
          nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "javascripts/#{js}", :file => io})
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
          io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
          nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "images/#{image}", :file => io})
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