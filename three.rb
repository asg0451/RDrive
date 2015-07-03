#!/usr/bin/env ruby
require 'pry'
###### fuse imports and setup
require './api.rb'

require 'rfusefs'
require 'fusefs/metadir'
require 'fusefs/dirlink'
include FuseFS

root = MetaDir.new
root.stats.max_space = 1024*1024*1024
root.stats.max_nodes = 1024
root.stats.strict = true

api = Dapi.new
client = api.client
drive_api = api.drive_api

### TODO: algorithm.
## grab each file only when accessed, then write it to that file for duration of program

puts 'downloading...'

params = { maxResults: 1000 }
fs = client.execute(
  api_method: drive_api.files.list,
  parameters: params
)

files = fs.data.items

#binding.pry

fs = files.map do |i|
  types = i['exportLinks'].nil? ? nil : i['exportLinks'].to_hash.keys
  { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i.file_extension, type: types , size: i.file_size}
  # docs dont expose durl, use explink instead
end

###TODO use pdfs, put used type in hash to use later
### TODO use mimeType (field in hash)
fs.map do |f|
  if !(f[:durl].nil?)
    f[:contents] = client.execute( uri: f[:durl]  )
  elsif !(f[:expLink].nil?)
      f[:contents] = client.execute( uri: f[:expLink][ f[:type][0] ] )  # just pick first available type for now
  end
  f[:check] = 'oaw'
#  puts f

  fname = '/'
  #
  # cases: has ext, no ext but gdoc format, nothing
  #
  if !(f[:contents].nil? or f[:contents].body.nil? or f[:contents].body.empty?) # can't access for some reason
     #### case 1
    if f[:title] =~ /\.[a-z0-9A-Z]+$/ # has extension in name
      fname = f[:title]
    elsif !f[:ext].nil? # has extension specified
      fname = f[:title] + f[:ext]
    #### case 2
    elsif f[:type].include?('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
      fname = f[:title] + '.doc' # or .xls ... not sure
    elsif f[:type].include?('text/html') # downloading as text for now
      fname = f[:title] + '.html'
    #### case 3
    else
      fname = f[:title]
    end
    puts "#{f[:title]}, #{f[:size]}"
    root.write_to(fname, f[:contents].body)
    f
  end
end

puts 'mounting...'

#binding.pry



FuseFS.main(ARGV) { | options | root }
