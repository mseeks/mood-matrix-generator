require "csv"
require "date"
require "google/cloud/language"
require "json/ext"

language_client  = Google::Cloud::Language.new(project: ENV["GOOGLE_CLOUD_PROJECT_ID"])
nodes = []
date_groups = {}

CSV.foreach("external-data/responses.csv", headers: true) do |row|
  body = row["body"].downcase.strip
  date = unless row["date"] == nil
    Date.parse(row["date"]).strftime("%m/%d/%y")
  end

  nodes << body
  date_groups[date] = [] if date_groups[date] == nil
  date_groups[date] << body
end

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

mapped_nodes = nodes.map{|node|
  sentiment_score = language_client.document(node).sentiment.score
  rounded_score = if sentiment_score <= -0.25
    0
  elsif sentiment_score >= 0.25
    2
  else
    1
  end

  {
    name: node,
    group: rounded_score
  }
}

matrix = {
  nodes: mapped_nodes,
  links: mapped_links
}.to_json

File.open("data/co-occurrence-map.json","w") do |file|
  file.write(matrix)
end
