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
end