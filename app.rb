%w(rubygems sinatra redis forkoff gruff enumerator).each{|x|require x}
set :r, Redis.new

def redis x, y=nil
  if y; options.r[x] = y
  else options.r[x] end
end

get "/" do
  @time = redis "contactstatsapp:graf.png:time"
  haml :index
end
get '/graf.png' do
    content_type 'image/png'
    last_modified redis "contactstatsapp:graf.png:time"
    body redis "contactstatsapp:graf.png"
end
get '/generate' do
  graph!
  "Graph generated"
end

def graph!
  @g = Gruff::Line.new 800
  @g.title = "Online contacts"
  @g.font = File.expand_path('fonts/Vera.ttf')
  output = `cat stats.txt | grep -v "^$"`.split("\n").grep /^.+/
  prviput = {}

  time = output.collect {|x|
    if x.to_s.start_with? '['
      r = DateTime.parse x.scan(/\[(.+)\]/)[0].to_s
      d = r.strftime('%a')
      if !prviput[d]
        prviput[d]=1; r.strftime '%a'
      else "X" end
    end
  }.compact
  all_count = output.collect {|x| x.scan(/Count: (\d+)/)[0].to_s.to_i if x.to_s.start_with? 'ALL ' }.compact
  fb_count  = output.collect {|x| x.scan(/Count: (\d+)/)[0].to_s.to_i if x.to_s.start_with? 'FB  ' }.compact

  if not (time.count == all_count.count && time.count == fb_count.count)
    puts "count of arrays nije jednak:"
    puts "time: #{time.count}"
    puts "all_count: #{all_count.count}"
    puts "fb_count: #{fb_count.count}"
  end

  @g.data "All count", all_count
  @g.data "Fb count", fb_count
  l = {}; time.enum_with_index.map {|x, i| l[i] = x if x != "X" }
  @g.labels = l
  @g.write('graph.png')
  return nil
end

def grapher
  puts "grapher forked"
  r = Redis.new
  pngrpath = "contactstatsapp:graf.png"
  while 1
    fork do
      list_all, list_fb = [
        `echo 'tell application "Adium" to get every contact whose status type is not offline' | osascript`,
        `echo 'tell application "Adium" to get every contact whose status type is not offline and name ends with "@chat.facebook.com"'|osascript`
      ]
      File.open('stats.txt', 'a'){ |f|
        f.puts "[#{Time.now}]"
        f.puts "ALL Count: #{list_all.split(', ').count}"
        f.puts "FB  Count: #{list_fb.split(', ').count}"
        f.puts
      }
      puts "[#{Time.now}] stats updated"
      graph!
      r[pngrpath] = File.read 'graph.png'
      r["#{pngrpath}:time"] = Time.now
      puts "[#{Time.now}] graph generated"
    end
    sleep 15*60
  end
end

fork { grapher }

__END__

@@index
%h1 Contact Stats
%img{:src=>'/graf.png'}
%p
  Timestamp grafa:
  = @time
%center
  %h2
    %a{:href=>"https://gist.github.com/6089a2913350d27a7db1"} Source (gist)
