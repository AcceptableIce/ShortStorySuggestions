require 'rubygems'
require 'httparty'
require 'curb'

class String
  def integer?
   !!(self =~ /^[-+]?[0-9]+$/)
  end
end

def request_integer(length)
	input = -1
	while(!input.integer? || input.to_i < 1 || input.to_i > length)
		print "Enter selection: "
		input = gets.chomp
	end
	return input
end

genre_lists = { 
				'Fantasy' => ["magic", "spell", "mage", "arcane", "elf", "dwarf", "wizard", "sorcerer", "potion", "bow", "sword", "fantasy"], 
				'Science Fiction' => ["robot", "star", "warp", "space", "android", "machine", "tech", "lab", "science"],
				'Horror' => ["ghost", "skeleton", "shriek", "scream", "haunted", "spook", "spirit"]
			}

puts "- - Welcome to the r/writingprompt Recommendation System - -"
puts "Question 1: What genre of story would you like to read?"
genre_lists.each_with_index do |(k, v), i|
	puts "    #{i + 1}) #{k}"
end
input = request_integer(genre_lists.length)
selected_list = genre_lists[genre_lists.keys[input.to_i - 1]]

puts "Question 2: Would you prefer stories in first or third person?"
puts "    1) First"
puts "    2) Third"
input = request_integer(2)
first_person = input.to_i == 1

puts "Question 3: Do you prefer modern stories?"
puts "    1) Modern"
puts "    2) Historical"
input = request_integer(2)
modern = input.to_i == 1

puts "Question 4: Any specific requests? (Separate terms with commas, or leave blank)"
term_input = gets.chomp
term_list = term_input.split(",")
term_list.map { |n| n.strip! }
term_list = term_list.join(" ");

puts "Question 5: Would you like more popular stories, or the stories that went unappreciated?"
puts "    1) Popular"
puts "    2) Unpopular"
input = request_integer(2)
direct_scoring = input.to_i == 1

puts "Finding stories, please stand by..."

#Build the requests
query_list = selected_list.join(" ")
request = "{"

request += 	"\"query\": { \"function_score\": { \"query\": { \"bool\": { \"should\": [ { \"match\": { \"body\": \"#{query_list} #{term_list} \" } },"

first_person_list = ["I", "my", "mine", "me", "we", "us"]
third_person_list = ["he", "she", "him", "her", "they", "them", "his", "hers", "himself", "herself"]

first_person_list.each do |item|
	modifier = 
	request += "{\"term\": { \"body\": { \"term\": \"#{item}\", \"boost\": #{((first_person ? 1 : -1) * 10)} } } },"
end

third_person_list.each do |item|
	request += "{\"term\": { \"body\": { \"term\": \"#{item}\", \"boost\": #{((first_person ? -1 : 1) * 10)} } } },"
end

modern_list = ["computer", "car", "phone", "cell", "internet", "plane"]

modern_list.each do |item|
	request += "{\"term\": { \"body\": { \"term\": \"#{item}\", \"boost\": #{((modern ? 1 : -1) * 10)} } } },"
end

request = request[0...(request.length - 1)]
request += "]}}, \"functions\": [ { \"field_value_factor\": { \"field\": \"score\""
if(!direct_scoring)
	request += ",\"modifier\": \"reciprocal\""
end
request += "} } ], \"boost_mode\": \"multiply\" } } }"
puts request
response = `curl -sS -XGET 'http://localhost:9200/stories_index/_search' -d '#{request}'`
response_json = JSON.parse(response)

response_json["hits"]["hits"].each_with_index do |item, index|
	if(index > 2)
		break
	end
	puts "----------------------------------------"
	puts "#{index + 1}: #{item["_source"]["url"]} (Upvotes: #{item["_source"]["score"]})"
	synopsis = item["_source"]["body"][0..140].gsub("\\n", "\n").gsub("\\\"", "\"") + "..."
	puts synopsis
end
puts "----------------------------------------"
