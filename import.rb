require 'rubygems'
require 'httparty'
require 'curb'

def with_http_retries(&block)
  begin
    yield
  rescue Errno::ECONNREFUSED, SocketError, Net::ReadTimeout
    puts "Cannot reach [#{@service_url}]. Retrying in #{@retry_seconds} seconds."
    sleep 1
    retry
  end
end

THREAD_LIMIT = 1000
COMMENT_LIMIT = 3
START_POINT = 0 #Allows us to work in batches.

#Get all the threads

response = HTTParty.get("http://reddit.com/r/writingprompts/search.json?restrict_sr=on&t=all&limit=25")
json = JSON.parse(response.body)
newId = "";
threads = {}
while threads.length < THREAD_LIMIT and json["data"]["children"].length == 25 do
	json["data"]["children"].each_with_index do |item, index|
		if !threads[item["data"]["id"]].nil?
			puts "Collision."
		end
		threads[item["data"]["id"]] = item["data"]
		puts "#{threads.length}) t3_" + item["data"]["id"];

	end
	code = 0
	while code != 200 
		response = with_http_retries { HTTParty.get("http://reddit.com/r/writingprompts/search.json?restrict_sr=on&t=all&after=#{json["data"]["after"]}&limit=25") }
		puts "http://reddit.com/r/writingprompts/search.json?restrict_sr=on&t=all&after=#{json["data"]["after"]}&limit=25"
		code = response.code
		if(code != 200)
			puts "#{response.code}, retrying...";
		end
	end
	json = JSON.parse(response.body);
	puts "Pulled #{json["data"]["children"].length} results."
end

puts "! -- Found #{threads.length} threads."

stories = {}
writer = File.open("stories_bulk.txt", "w")

#For each thread, get the top comments.
threads.each do |(key, item)|
	base_url = item["url"][0..(item["url"].length - 2)]
	code = 0
	while code != 200 
		response = with_http_retries { HTTParty.get(base_url + ".json?limit=#{COMMENT_LIMIT}&depth=1") }
		code = response.code
		if(code != 200)
			puts "#{response.code}, retrying...";
		end
	end
	json = JSON.parse(response.body)
	json[1]["data"]["children"].each_with_index do |item, index|
		if(index == COMMENT_LIMIT) 
			break
		end
		item["data"]["url"] = base_url
		if !stories[item["data"]["id"]].nil?
			puts "Collision."
		end
		stories[item["data"]["id"]] = item["data"]
		puts "#{stories.length}) t1_" + item["data"]["id"]
	end
end
puts "! -- Found #{stories.length} comments."
outstr = ""
stories.each do |(key, item)| 
	name = item["name"][3..-1]
	lines = item["body"]
	if lines.nil? 
		next
	end
	lines = lines.gsub('"', '\\"');
	lines = lines.gsub("“", '\\"');
	lines = lines.gsub("\r", "");
	split = lines.split("\n")
	url = item["url"] + "/" + name

	body = split.join("\\\\n").strip! #this is actually so dumb

	strout = "{ \"create\": { \"_index\": \"stories_index\", \"_type\": \"doc\", \"_id\": \"#{name}\"}}\n{\"url\": \"#{url}\", \"score\" : \"#{item["score"]}\", \"body\" : \"#{body}\"}\n";
	writer.write(strout)
	outstr += strout
end
writer.write("\r\n")
outstr += "\r\n"


curl = Curl::Easy.new("localhost:9200/_bulk")
curl.post_body = outstr
curl.http_post
abort("Done")