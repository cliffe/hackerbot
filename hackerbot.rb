require 'cinch'
require 'nokogiri'

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
      # Print.err "Failed to read hackerbot file (#{file})"
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
      print bot_name
      bots[bot_name] = {}
      bots[bot_name]['greeting'] = hackerbot.at_xpath('greeting').text
      bots[bot_name]['dothis'] = {}
      # for each dothis TODO!
      # bots[bot_name]['dothis'][prompt] =

      bots[bot_name]['bot'] = Cinch::Bot.new do
        configure do |c|
          c.nick = bot_name
          c.server = "irc.freenode.org"
          c.channels = ["#hackerbottesting"]
        end


        hackerbot.xpath('//dothis').each do |dothis|
          bots[bot_name]['greeting'] += ' **** ' + dothis.at_xpath('prompt').text

        end

        on :message, "hello" do |m|
          m.reply "Hello, #{m.user.nick}"
          m.reply bots[bot_name]['greeting']
        end


      end
    end
  end

  bots
end

def start_bots(bots)
  bots.each do |bot_name, bot|
    print "starting #{bot_name}\n"
    bot['bot'].start
  end
end

bots = read_bots
start_bots(bots)
# bot.start
