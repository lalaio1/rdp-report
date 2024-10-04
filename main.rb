require 'json'
require 'net/http'
require 'uri'
require 'thread'
require 'io/console'

# -= Global Colors
require_relative './global/colors'

# -= Goobal Banner  / Func
require_relative './func/print_banner'

# -= Main Class
class DiscordReporter
  API_URL = 'https://discordapp.com/api/v8/report'
  CONFIG_FILE = File.join(Dir.home, '.discord_reporter_config.json')
  HEADERS = {
    'Accept' => '*/*',
    'Accept-Encoding' => 'gzip, deflate',
    'Accept-Language' => 'sv-SE',
    'User-Agent' => 'Discord/21295 CFNetwork/1128.0.1 Darwin/19.6.0',
    'Content-Type' => 'application/json'
  }

  REASON_CODES = {
    '1' => 0, 'ILLEGAL CONTENT' => 0,
    '2' => 1, 'HARASSMENT' => 1,
    '3' => 2, 'SPAM OR PHISHING LINKS' => 2,
    '4' => 3, 'SELF-HARM' => 3,
    '5' => 4, 'NSFW CONTENT' => 4
  }

  RESPONSE_MESSAGES = {
    401 => "#{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Invalid Discord token.#{RESET}",
    403 => "#{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Missing access to channel or guild.#{RESET}",
    422 => "#{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Action requires account verification.#{RESET}"
  }

  def initialize
    @sent_reports = 0
    @errors = 0
    @stop = false
    load_token
    collect_input
  end

  def load_token
    request_token
  end
  
  def request_token
    print "#{BRIGHT_CYAN_TEXT}[#{RESET}>#{BRIGHT_CYAN_TEXT}] #{RESET}token: #{RESET}"
    @token = gets.chomp
    puts "\n#{GREEN_TEXT}[#{RESET}+#{GREEN_TEXT}] #{RESET}Token received successfully.#{RESET}"
  end
  

  def collect_input
    @guild_id = prompt('Guild ID')
    @channel_id = prompt('Channel ID')
    @message_id = prompt('Message ID')
    @reason_code = select_reason
  end

  def prompt(label)
    print "#{GREEN_TEXT}[#{RESET}>#{GREEN_TEXT}]#{RESET} #{label}: #{RESET}"
    gets.chomp
  end

  def select_reason
    puts "\n#{GREEN_TEXT}[#{RESET}1#{GREEN_TEXT}] #{RESET}Illegal content\n#{GREEN_TEXT}[#{RESET}2#{GREEN_TEXT}] #{RESET}Harassment\n#{GREEN_TEXT}[#{RESET}3#{GREEN_TEXT}] #{RESET}Spam or phishing links\n#{GREEN_TEXT}[#{RESET}4#{GREEN_TEXT}] #{RESET}Self-harm\n#{GREEN_TEXT}[#{RESET}5#{GREEN_TEXT}] #{RESET}NSFW content#{RESET}"
    print "#{GREEN_TEXT}[#{RESET}>#{GREEN_TEXT}] #{RESET}Reason: #{RESET}"
    input = gets.chomp.upcase
    REASON_CODES[input] || (puts "#{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Invalid reason.#{RESET}"; exit(1))
  end

  def report
    uri = URI.parse(API_URL)
    body = {
      'channel_id' => @channel_id,
      'message_id' => @message_id,
      'guild_id' => @guild_id,
      'reason' => @reason_code
    }

    headers = HEADERS.merge('Authorization' => @token)
    request = Net::HTTP::Post.new(uri, headers)
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_response(response)
  end

  def handle_response(response)
    status = response.code.to_i
    if status == 201
      @sent_reports += 1
      puts "           #{GREEN_TEXT}[#{RESET}+#{GREEN_TEXT}] #{RESET}Report sent successfully.#{RESET}"
    elsif status == 429 
      retry_after = rand(2..5) 
      puts "           #{YELLOW_TEXT}[#{RESET}!#{YELLOW_TEXT}] #{RESET}Rate limit hit. Pausing for #{retry_after} seconds...#{RESET}"
      sleep(retry_after)
    else
      @errors += 1 
      error_message = RESPONSE_MESSAGES[status] || "\n           #{RED_TEXT}[#{RESET}!#{RED_TEXT}] Error: #{response.body} (Status #{status})#{RESET}\n"
      puts error_message
    end
  rescue JSON::ParserError
    puts "           #{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Failed to parse server response.#{RESET}"
  end
  
  

  def update_status
    loop do
      break if @stop
      print "\r#{CYAN_TEXT}[#{RESET}+#{CYAN_TEXT}] - Sent: #{@sent_reports} | #{RED_TEXT} [#{RESET}-#{RED_TEXT}] #{RESET}Errors: #{@errors}#{RESET}"
      sleep(0.1)
    end
  end

  def multi_threading
    Thread.new { update_status }
    loop do
      break if @stop
      Thread.new { report }.join if Thread.list.size <= 300
    end
  rescue Interrupt
    @stop = true
    puts "\n#{RED_TEXT}[#{RESET}!#{RED_TEXT}] #{RESET}Stopping threads"
    puts "\n#{RED_TEXT}[#{RESET}+#{RED_TEXT}]#{RESET} Contact: https://github.com/lalaio1/rdp-report\n"
  end

  def run
    multi_threading
  end
end

if __FILE__ == $0
  system('clear') || system('cls')
  print_banner
  reporter = DiscordReporter.new
  reporter.run
end
