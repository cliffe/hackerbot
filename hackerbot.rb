require 'cinch'
require 'nokogiri'
require 'nori'
require './print.rb'
require 'open3'

def read_bots
  bots = {}
  Dir.glob("config/*.xml").each do |file|
    print "#{file}"
    module_filename = nil
    #
    # Print.verbose "Reading #{module_type}: #{module_path}"
    # doc, xsd = nil
    begin
      doc = Nokogiri::XML(File.read(file))
    rescue
      Print.err "Failed to read hackerbot file (#{file})"
      print "Failed to read hackerbot file (#{file})"

      exit
    end
    #
    # # validate scenario XML against schema
    # begin
    #   xsd = Nokogiri::XML::Schema(File.read(schema_file))
    #   xsd.validate(doc).each do |error|
    #     Print.err "Error in #{module_type} metadata file (#{file}):"
    #     Print.err '    ' + error.message
    #     exit
    #   end
    # rescue Exception => e
    #   Print.err "Failed to validate #{module_type} metadata file (#{file}): against schema (#{schema_file})"
    #   Print.err e.message
    #   exit
    # end

    # remove xml namespaces for ease of processing
    doc.remove_namespaces!
    #
    # new_module = Module.new(module_type)
    # # save module path (and as an attribute for filtering)
    # new_module.module_path = module_path
    # new_module.attributes['module_path'] = [module_path]
    doc.xpath('/hackerbot').each_with_index do |hackerbot|

      bot_name = hackerbot.at_xpath('name').text
      Print.debug bot_name
      bots[bot_name] = {}
      bots[bot_name]['greeting'] = hackerbot.at_xpath('greeting').text
      bots[bot_name]['hacks'] = []
      hackerbot.xpath('//hack').each do |hack|
        bots[bot_name]['hacks'].push Nori.new.parse(hack.to_s)['hack']

      end
      bots[bot_name]['current_hack'] = 0

      Print.debug bots[bot_name]['hacks'].to_s

      # for each dothis TODO!
      # bots[bot_name]['dothis'][prompt] =

      bots[bot_name]['bot'] = Cinch::Bot.new do
        configure do |c|
          c.nick = bot_name
          c.server = "172.28.128.3" # "irc.freenode.org" TODO
          c.channels = ["#hackerbottesting"]
        end

        on :message, "hello" do |m|
          m.reply "Hello, #{m.user.nick}."
          m.reply bots[bot_name]['greeting']
          current = bots[bot_name]['current_hack']
          # m.reply bots[bot_name]['hacks'].to_s

          # prompt for the first attack
          m.reply bots[bot_name]['hacks'][current]['prompt']
          m.reply "When you are ready, simply say '#{bots[bot_name]['hacks'][current]['trigger_message']}'."

        end

        # TODO: use trigger_message
        on :message, "ready" do |m|
          m.reply 'Ok. Gaining shell access, and running post command...'
          current = bots[bot_name]['current_hack']
          # cmd_output = `#{bots[bot_name]['hacks'][current]['get_shell']} << `

          shell_cmd = bots[bot_name]['hacks'][current]['get_shell']
          Print.debug shell_cmd

          Open3.popen2e(shell_cmd) do |stdin, stdout_err|

            # check whether we have shell by echoing "test"
            sleep(1)
            stdin.puts "echo test\n"
            sleep(1)
            line = stdout_err.gets.chomp()
            if line == "test"
              m.reply 'Shell successful...'
            else
              m.reply bots[bot_name]['hacks'][current]['shell_fail_message']
            end



            # answer = gets.chomp()
            stdin.puts "echo answer"


            # threads.each{|t| t.join()} #in order to cleanup when you're done.
          end
          m.reply "line end"

          # Open3.pipeline_rw("sort", "cat -n") {|stdin, stdout, wait_thrs|
          #   stdin.puts "foo"
          #   stdin.puts "bar"
          #   stdin.puts "baz"
          #   stdin.close     # send EOF to sort.
          #   out = stdout.read   #=> "     1\tbar\n     2\tbaz\n     3\tfoo\n"
          # }
          # m.reply out

        end

      end
    end
  end

  bots
end

def start_bots(bots)
  bots.each do |bot_name, bot|
    Print.std "Starting bot: #{bot_name}\n"
    bot['bot'].start
  end
end

bots = read_bots
start_bots(bots)
# bot.start
