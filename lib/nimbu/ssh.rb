require "yaml"
require "nimbu"
require "nimbu/helpers"

class Nimbu::Auth
  class << self

    include Nimbu::Helpers
    def check_for_associated_ssh_key
      return unless client.keys.empty?
      associate_or_generate_ssh_key
    end

    def associate_or_generate_ssh_key
      public_keys = Dir.glob("#{home_directory}/.ssh/*.pub").sort

      case public_keys.length
      when 0 then
        display "Could not find an existing public key."
        display "Would you like to generate one? [Yn] ", false
        unless ask.strip.downcase == "n"
          display "Generating new SSH public key."
          generate_ssh_key("id_rsa")
          associate_key("#{home_directory}/.ssh/id_rsa.pub")
        end
      when 1 then
        display "Found existing public key: #{public_keys.first}"
        associate_key(public_keys.first)
      else
        display "Found the following SSH public keys:"
        public_keys.each_with_index do |key, index|
          display "#{index+1}) #{File.basename(key)}"
        end
        display "Which would you like to use with your Nimbu account? ", false
        chosen = public_keys[ask.to_i-1] rescue error("Invalid choice")
        associate_key(chosen)
      end
    end

    def generate_ssh_key(keyfile)
      ssh_dir = File.join(home_directory, ".ssh")
      unless File.exists?(ssh_dir)
        FileUtils.mkdir_p ssh_dir
        File.chmod(0700, ssh_dir)
      end
      `ssh-keygen -t rsa -N "" -f \"#{home_directory}/.ssh/#{keyfile}\" 2>&1`
    end

    def associate_key(key)
      display "Uploading SSH public key #{key}"
      client.add_key(File.read(key))
    end
  end
end
