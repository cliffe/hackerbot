require 'cinch'
require 'nokogiri'
require 'nori'
require './print.rb'
require 'open3'
require 'programr'

def read_bots
  bots = {}
  Dir.glob("config/*.xml").each do |file|
    print "#{file}"

    begin
      doc = Nokogiri::XML(File.read(file))
    rescue
      Print.err "Failed to read hackerbot file (#{file})"
      print "Failed to read hackerbot file (#{file})"

      exit
    end
    #
    # # TODO validate scenario XML against schema
    # begin
    #   xsd = Nokogiri::XML::Schema(File.read(schema_file))
    #   xsd.validate(doc).each do |error|
    #     Print.err "Error in bot config file (#{file}):"
    #     Print.err '    ' + error.message
    #     exit
    #   end
    # rescue Exception => e
    #   Print.err "Failed to validate bot config file (#{file}): against schema (#{schema_file})"
    #   Print.err e.message
    #   exit
    # end

    # remove xml namespaces for ease of processing
    doc.remove_namespaces!

    doc.xpath('/hackerbot').each_with_index do |hackerbot|

      bot_name = hackerbot.at_xpath('name').text
      Print.debug bot_name
      bots[bot_name] = {}

      chatbot_rules = hackerbot.at_xpath('AIML_chatbot_rules').text
      Print.debug "Loading chat_ai from #{chatbot_rules}"
      bots[bot_name]['chat_ai'] = ProgramR::Facade.new
      bots[bot_name]['chat_ai'].learn([chatbot_rules])

      bots[bot_name]['messages'] = Nori.new.parse(hackerbot.at_xpath('//messages').to_s)['messages']
      Print.debug bots[bot_name]['messages'].to_s

      bots[bot_name]['hacks'] = []
      hackerbot.xpath('//hack').each do |hack|
        bots[bot_name]['hacks'].push Nori.new.parse(hack.to_s)['hack']
      end
      bots[bot_name]['current_hack'] = 0

      Print.debug bots[bot_name]['hacks'].to_s

      bots[bot_name]['bot'] = Cinch::Bot.new do
        configure do |c|
          c.nick = bot_name
          c.server = 'localhost'
          c.channels = ['#hackerbottesting']
        end

        on :message, /hello/i do |m|
          m.reply "Hello, #{m.user.nick}."
          m.reply bots[bot_name]['greeting']
          current = bots[bot_name]['current_hack']

          # prompt for the first attack
          m.reply bots[bot_name]['hacks'][current]['prompt']
          m.reply bots[bot_name]['messages']['say_ready'].sample
        end

        on :message, /help/i do |m|
          m.reply bots[bot_name]['messages']['help'].sample
        end

        on :message, 'next' do |m|
          m.reply bots[bot_name]['messages']['next'].sample

          # is this the last one?
          if bots[bot_name]['current_hack'] < bots[bot_name]['hacks'].length - 1
            bots[bot_name]['current_hack'] += 1
            current = bots[bot_name]['current_hack']

            # prompt for current hack
            m.reply bots[bot_name]['hacks'][current]['prompt']
            m.reply bots[bot_name]['messages']['say_ready'].sample
          else
            m.reply bots[bot_name]['messages']['last_attack'].sample
          end

        end

        on :message, 'previous' do |m|
          m.reply bots[bot_name]['messages']['previous'].sample

          # is this the last one?
          if bots[bot_name]['current_hack'] > 0
            bots[bot_name]['current_hack'] -= 1
            current = bots[bot_name]['current_hack']

            # prompt for current hack
            m.reply bots[bot_name]['hacks'][current]['prompt']
            m.reply bots[bot_name]['messages']['say_ready'].sample

          else
            m.reply bots[bot_name]['messages']['first_attack'].sample
          end

        end

        on :message, 'list' do |m|
          bots[bot_name]['hacks'].each_with_index {|val, index|
            uptohere = ''
            if index == bots[bot_name]['current_hack']
              uptohere = '--> '
            end

            m.reply "#{uptohere}attack #{index+1}: #{val['prompt']}"
          }
        end

        # fallback to AIML ALICE chatbot responses
        on :message do |m|
          Print.debug "test1"

          # Only process messages not related to controlling attacks
          return if m.message =~ /help|next|previous|list/

          begin
            reaction = bots[bot_name]['chat_ai'].get_reaction(m.message)

          rescue Exception => e
            puts e.message
            puts e.backtrace.inspect
            reaction = ''
          end
          Print.debug "test2"
          if reaction
            m.reply reaction
          else
            Print.debug reaction
            if m.message.include?('?')
              m.reply bots[bot_name]['messages']['non_answer'].sample
            end
          end

        end


        on :message, 'ready' do |m|
          m.reply bots[bot_name]['messages']['getting_shell'].sample
          current = bots[bot_name]['current_hack']
          # cmd_output = `#{bots[bot_name]['hacks'][current]['get_shell']} << `

          shell_cmd = bots[bot_name]['hacks'][current]['get_shell'].sample
          Print.debug shell_cmd

          Open3.popen2e(shell_cmd) do |stdin, stdout_err|
            # check whether we have shell by echoing "test"
            sleep(1)
            stdin.puts "echo shelltest\n"
            sleep(1)
            line = stdout_err.gets.chomp()
            if line == "shelltest"
              m.reply bots[bot_name]['messages']['got_shell'].sample

              post_cmd = bots[bot_name]['hacks'][current]['post_command']
              if post_cmd
                stdin.puts "#{post_cmd}\n"
              end

              # sleep(1)
              stdin.close # no more input, end the program
              line = stdout_err.read.chomp()

              m.reply "FYI: #{line}"
              condition_met = false
              bots[bot_name]['hacks'][current]['condition'].each do |condition|
                if !condition_met && condition.key?('output_matches') && line =~ /#{condition['output_matches']}/
                  condition_met = true
                  m.reply "#{condition['message']}"
                end
                if !condition_met && condition.key?('output_not_matches') && line !~ /#{condition['output_not_matches']}/
                  condition_met = true
                  m.reply "#{condition['message']}"
                end
                if !condition_met && condition.key?('output_equals') && line == condition['output_equals']
                  condition_met = true
                  m.reply "#{condition['message']}"
                end

                if condition_met && condition.key?('trigger_next')
                  # is this the last one?
                  if bots[bot_name]['current_hack'] < bots[bot_name]['hacks'].length - 1
                    bots[bot_name]['current_hack'] += 1
                    current = bots[bot_name]['current_hack']

                    sleep(1)
                    # prompt for current hack
                    m.reply bots[bot_name]['hacks'][current]['prompt']
                  else
                    m.reply bots[bot_name]['messages']['last_attack'].sample
                  end
                end
              end
              unless condition_met
                if bots[bot_name]['hacks'][current]['else_condition']
                  m.reply bots[bot_name]['hacks'][current]['else_condition']['message']
                end
              end


            else
              m.reply bots[bot_name]['hacks'][current]['shell_fail_message']
            end

          end
          m.reply bots[bot_name]['messages']['repeat'].sample
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
