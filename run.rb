require 'octokit'
require 'dotenv'
require 'pry'

Dotenv.load

class GHE
  def configure!
    Octokit.configure do |c|
      c.api_endpoint = ENV['GHE_HOST']
    end
  end

  def client
    return @client if defined?(@client)

    configure!
    @client = Octokit::Client.new(access_token: ENV['GHE_TOKEN'])
  end

  def search_issues(type: nil, author: ENV['GHE_USERNAME'], open: true)
    opt = []
    opt.push ['type', type] if type
    opt.push ['author', author]
    opt.push ['is', (open ? 'open' : 'closed')]
    query = opt.map{|e| e.join(':') }.join(' ')
    p query
    client.search_issues(query)[:items]
  end
end



binding.pry
