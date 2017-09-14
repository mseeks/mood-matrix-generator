require "date"
require "json"
require "open-uri"

nodes = []
date_groups = {}

JSON.parse(open(ENV["MOOD_RESPONSES_ENDPOINT"]).read).each do |response|
  body = response["body"].downcase.strip
  sentiment = response["sentiment"]
  rounded_score = if sentiment <= -0.25
    0
  elsif sentiment >= 0.25
    2
  else
    1
  end

  created_at = unless response["created_at"] == nil
    Date.parse(response["created_at"]).strftime("%m/%d/%y")
  end

  nodes << {
    name: body,
    group: rounded_score
  }
  date_groups[created_at] = [] if date_groups[created_at] == nil
  date_groups[created_at] << body
end

nodes.uniq!

combinations = date_groups.map{|key, value|
  value.product(value).map{|v|
    v.sort
  }.reject{|c|
    c.empty?
  }.uniq.map{|v|
    {
      source: nodes.index(v[0]),
      target: nodes.index(v[1])
    }
  }
}.flatten.sort_by{|v|
  v[:source]
}

mapped_links = combinations.map{|v|
  v[:frequency] = combinations.group_by{|x|
    "#{x[:source]}.#{x[:target]}"
  }["#{v[:source]}.#{v[:target]}"].length

  v
}.uniq.reject{|v|
  v[:source] == v[:target]
}

matrix = {
  nodes: mapped_nodes,
  links: mapped_links
}.to_json

File.open("data/co-occurrence-map.json","w") do |file|
  file.write(matrix)
end
