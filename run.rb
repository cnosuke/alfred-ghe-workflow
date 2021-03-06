require 'json'
require 'octokit'
require 'dotenv'

CACHE_TTL = 30
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

    client.search_issues(query)[:items]
  end
end

def item_xml(options = {})
  <<-ITEM
  <item arg="#{options[:arg].encode(xml: :text)}" uid="#{options[:uid]}">
    <title>#{options[:title].encode(xml: :text)}</title>
    <subtitle>#{options[:subtitle].encode(xml: :text)}</subtitle>
    <icon>#{options[:icon]}</icon>
  </item>
  ITEM
end

def match?(word, query)
  word.match(/#{query}/i)
end

queries = ARGV.first.split(' ').map{|e| Regexp.escape(e.force_encoding('UTF-8')) }

t = nil
o = true
if %w(pr is).include?(queries.first)
  t = queries.shift
  t = (t == 'pr' ? t : 'issue')
end

if %w(open closed).include?(queries.first)
  o = queries.shift
  o = (t == 'open' ? true : false)
end

cache_prefix = "./cache/#{(Time.now.to_i/CACHE_TTL)}"
cache_filename = "#{[t, o].join}.json"
cache_path = cache_prefix + cache_filename
unless File.exist?(cache_path)
  File.unlink *Dir.glob("./cache/*.json").select{|e| e !~ /#{cache_prefix}/}
  open(cache_path, 'w'){|io|
    io.puts GHE.new.search_issues(type: t, open: o).map{|e|
      h = {}
      %w(
        title
        updated_at
        created_at
        number
        body
        pull_request
        html_url
      ).each{|ee| h[ee] = e[ee.to_sym] }
      h
    }.to_json
  }
end

matches = JSON.parse(open(cache_path, external_encoding: 'UTF-8').read)

queries.each do |query|
  matches = matches.select { |e| match?(e["title"], query) }
end

items = matches.sort_by{|e| e["updated_at"] }.map do |elem|
  sub = "[##{elem["number"]}] #{elem["body"]}"
  type = elem["pull_request"] ? 'PR' : 'Is'
  title = "[#{type}] #{elem["title"]}"

  item_xml({
    arg: "open '#{elem["html_url"]}'",
    uid: 0,
    icon: '168CA675-5F85-4A9E-A871-5B3871DD0EAC.png',
    title: title,
    subtitle: sub,
  })
end.join

output = "<?xml version='1.0'?>\n<items>\n#{items}</items>"

puts output
