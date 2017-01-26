# -*- encoding : utf-8 -*-
require "nimbu/command/base"

# working with themes (upload / download)
#
class Nimbu::Command::Themes < Nimbu::Command::Base

  # themes
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

  # themes:list
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

  # themes
  #
  # list available commands or display help for a specific command
  #
  def diff
    require 'diffy'
    @diff = {}
    input = args.shift.downcase rescue nil
    theme = if !input.to_s.strip.empty?
      input.to_s.strip
    else
      Nimbu::Auth.theme
    end
    display "\nShowing differences between local and server\nlayouts, templates, snippets and assets for '#{theme.green.bold}':"
    json = nimbu.themes(:subdomain => Nimbu::Auth.site).get(theme)
    check_differences(json, theme, "layouts", "templates", "snippets")
  end

  # themes:push
  #
  # push all layouts, templates and assets
  # --liquid, --liquid-only   # only push template code
  # --css, --css-only   # only push template code
  # --js, --js-only   # only push template code
  # --images-only   # only push new images
  # --fonts-only    # only push fonts
  # --only          # only push the files given on the command line
  # --force         # skip the usage check and upload anyway
  #
  def push
    liquid_only = options[:liquid]
    css_only = options[:css]
    js_only = options[:js]
    images_only = options[:images_only]
    fonts_only = options[:fonts_only]
    files_only = options[:only]
    force = options[:force]

    # if !input.to_s.strip.empty?
    #   theme = input.to_s.strip
    # else
    # end
    theme = Nimbu::Auth.theme
    display "Pushing layouts, templates and assets for '#{theme}' to the server:"

    # What should we push?
    push_liquid = !(css_only || js_only || images_only || fonts_only)
    push_css = !(liquid_only || js_only || images_only || fonts_only)
    push_js = !(liquid_only || css_only || images_only || fonts_only)
    push_images = !(liquid_only || css_only || js_only || fonts_only)
    push_fonts = !(liquid_only || css_only || js_only || images_only)

    if push_fonts
      if files_only
        font_files = args.select{|file| file.start_with?("fonts")}.map{|file| file.gsub("fonts/", "")}
      else
        font_files = Dir.glob("#{Dir.pwd}/fonts/**/*").map {|dir| dir.gsub("#{Dir.pwd}/fonts/","")} rescue []
      end

      print "\nFonts:\n"
      font_files.each do |font|
        file = "#{Dir.pwd}/fonts/#{font}"
        next if !force && (File.directory?(file) || (!anyFileWithWord?(css_glob,font) && !anyFileWithWord?(js_glob,font) && !anyFileWithWord?(layouts_glob,font) && !anyFileWithWord?(templates_glob,font) && !anyFileWithWord?(snippets_glob,font)))
        io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
        nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "fonts/#{font}", :file => io})
        print " - fonts/#{font}"
        print " (ok)\n"
      end
    end

    if push_images
      if files_only
        image_files = args.select{|file| file.start_with?("images")}.map{|file| file.gsub("images/", "")}
      else
        image_files = Dir.glob("#{Dir.pwd}/images/**/*").map {|dir| dir.gsub("#{Dir.pwd}/images/","")}
      end

      print "\nImages:\n"
      image_files.each do |image|
        file = "#{Dir.pwd}/images/#{image}"
        next if !force && (File.directory?(file) || (!anyFileWithWord?(css_glob,image) && !anyFileWithWord?(js_glob,image) && !anyFileWithWord?(layouts_glob,image) && !anyFileWithWord?(templates_glob,image) && !anyFileWithWord?(snippets_glob,image)))
        io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
        nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "images/#{image}", :file => io})
        print " - images/#{image}"
        print " (ok)\n"
      end
    end

    if push_css
      if files_only
        css_files = args.select{|file| file.start_with?("stylesheets")}.map{|file| file.gsub("stylesheets/", "")}
      else
        css_files = css_glob.map {|dir| dir.gsub("#{Dir.pwd}/stylesheets/","")}
      end

      print "\nStylesheets:\n"
      css_files.each do |css|
        file = "#{Dir.pwd}/stylesheets/#{css}"
        next if !force && (File.directory?(file) || (!anyFileWithWord?(layouts_glob,css) && !anyFileWithWord?(templates_glob,css) && !anyFileWithWord?(snippets_glob,css)))
        io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
        nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "stylesheets/#{css}", :file => io})
        print " - stylesheets/#{css}"
        print " (ok)\n"
      end
    end

    if push_js
      if files_only
        js_files = args.select{|file| file.start_with?("javascripts")}.map{|file| file.gsub("javascripts/", "")}
      else
        js_files = js_glob.map {|dir| dir.gsub("#{Dir.pwd}/javascripts/","")}
      end

      print "\nJavascripts:\n"
      js_files.each do |js|
        file = "#{Dir.pwd}/javascripts/#{js}"
        next if !force && (File.directory?(file) || (!anyFileWithWord?(layouts_glob,js) && !anyFileWithWord?(templates_glob,js) && !anyFileWithWord?(snippets_glob,js)))
        io = Faraday::UploadIO.new(File.open(file), 'application/octet-stream', File.basename(file))
        nimbu.themes(:subdomain => Nimbu::Auth.site).assets(:theme_id => theme).create({:name => "javascripts/#{js}", :file => io})
        print " - javascripts/#{js}"
        print " (ok)\n"
      end
    end

    if push_liquid
      if files_only
        layouts_files = args.select{|file| file.start_with?("layouts")}.map{|file| file.gsub("layouts/", "")}
        templates_files = args.select{|file| file.start_with?("templates")}.map{|file| file.gsub("templates/", "")}
        snippets_files = args.select{|file| file.start_with?("snippets")}.map{|file| file.gsub("snippets/", "")}
      else
        layouts_files = layouts_glob.map {|dir| dir.gsub("#{Dir.pwd}/layouts/","")}
        templates_files = templates_glob.map {|dir| dir.gsub("#{Dir.pwd}/templates/","")}
        snippets_files = snippets_glob.map {|dir| dir.gsub("#{Dir.pwd}/snippets/","")}
      end

      print "\nSnippets:\n"
      snippets_files.each do |snippet|
        file = "#{Dir.pwd}/snippets/#{snippet}"
        next if !force && (File.directory?(file))
        print " - snippets/#{snippet}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).snippets(:theme_id => theme).create({:name => snippet, :content => IO.read(file).force_encoding('UTF-8')})
        print " (ok)\n"
      end

      print "\nLayouts:\n"
      layouts_files.each do |layout|
        file = "#{Dir.pwd}/layouts/#{layout}"
        next if !force && (File.directory?(file))
        print " - layouts/#{layout}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).layouts(:theme_id => theme).create({:name => layout, :content => IO.read(file).force_encoding('UTF-8')})
        print " (ok)\n"
      end

      print "\nTemplates:\n"
      templates_files.each do |template|
        file = "#{Dir.pwd}/templates/#{template}"
        next if !force && (File.directory?(file))
        print " - templates/#{template}"
        nimbu.themes(:subdomain => Nimbu::Auth.site).templates(:theme_id => theme).create({:name => template, :content => IO.read(file).force_encoding('UTF-8')})
        print " (ok)\n"
      end
    end

  end

  private

  def check_differences(contents, theme, *types)
    types.each do |type|
      if contents[type].any?
        print "\n\n#{type.capitalize}: ".bold
        contents[type].each { |layout| compare(layout, theme, type) }
        display "no differences found!" if @diff[type].nil?
      end
    end
  end

  def compare(data, theme, type)
    file = "#{Dir.pwd}/#{type}/#{data["name"]}"
    if File.exists?(file)
      local = IO.read(file).force_encoding('UTF-8').to_s.gsub(/\r\n?/, "\n").strip
      api = nimbu.themes(:subdomain => Nimbu::Auth.site)
      json = api.send(type, :theme_id => theme).get(:"#{type[0..-2]}_id" => data['id'])
      server = json["code"].to_s.force_encoding('UTF-8').gsub(/\r\n?/, "\n").strip
      diff = Diffy::Diff.new(local, server, :include_diff_info => true, :context => 3).to_s(:color).strip
      if diff != ""
        print "\n - #{type}/#{data["name"]} has #{'changed'.yellow.bold }:\n\n#{diff}" 
        @diff[type] = true
      end
    else
      @diff[type] = true
      print "\n - #{type}/#{data["name"]} is #{'missing'.red.bold }"
    end
  end

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

  def layouts_glob
    @layouts_glob ||= Dir.glob("#{Dir.pwd}/layouts/**/*.liquid")
  end

  def templates_glob
    @templates_glob ||= Dir.glob("#{Dir.pwd}/templates/**/*.liquid")
  end

  def snippets_glob
    @snippets_glob ||= Dir.glob("#{Dir.pwd}/snippets/**/*.liquid")
  end

  def css_glob
    @css_glob ||= Dir.glob("#{Dir.pwd}/stylesheets/**/*.css")
  end

  def js_glob
    @js_glob ||= Dir.glob("#{Dir.pwd}/javascripts/**/*.js")
  end

end
