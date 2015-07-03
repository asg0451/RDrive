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

def match_format(f) # returns type
  [
    [nil                                                                         , nil   ],
    ['text/plain'                                                                , '.txt'],
    ['application/rtf'                                                           , '.rtf'],
    ['application/pdf'                                                           , '.pdf'],
    ['text/csv'                                                                  , '.csv'],
    ['image/jpeg'                                                                , '.jpg'],
    ['image/png'                                                                 , '.png'],
    ['image/svg+xml'                                                             , '.svg'],
    ['application/vnd.openxmlformats-officedocument.presentationml.presentation' , '.ppt'],
    ['text/plain'                                                                , '.txt'],
    ['application/vnd.oasis.opendocument.text'                                   , '.odt'], # or .doc?
    ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'         , '.xls'],
    ['application/x-vnd.oasis.opendocument.spreadsheet'                          , '.xls'],
    ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'   , '.doc'], # or docx?
  ].map do |t|
    if !f[:types].nil?
      if f[:types].include?(t[0])
        f[:type] = t[0]
        f[:ext]  = t[1]
      end
    end
  end
  f
end

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
  { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i.file_extension, types: types, type: nil }
end

### TODO use pdfs, put used type in hash to use later
### TODO use mimeType (field in hash)
fs.map do |f|
  # pick a type
  f = match_format(f)

  if !(f[:durl].nil?)
    f[:contents] = client.execute( uri: f[:durl]  )
  elsif !(f[:expLink].nil? or f[:types].nil?)
    if !f[:type].nil?
      f[:contents] = client.execute( uri: f[:expLink][ f[:type]] )  # just pick first available type for now
    end
  end
  f[:check] = 'oaw'
#  puts f

  fname = '/'
  if !(f[:contents].nil? or f[:contents].body.nil? or f[:contents].body.empty?) # can't access for some reason
    # if f[:title] =~ /\.[a-z0-9A-Z]+$/ # has extension in name
    #   fname = f[:title]
#    else
      fname = f[:title] + f[:ext]
#    end
    puts "#{f[:title]}"
    root.write_to(fname, f[:contents].body)
    f
  end
end

puts 'mounting...'

#binding.pry



FuseFS.main(ARGV) { | options | root }


## Document types
# Plaintext		text/plain
# Richtext		application/rtf
# OpenOffice doc	application/vnd.oasis.opendocument.text
# PDF                   application/pdf
# MSWord document	application/vnd.openxmlformats-officedocument.wordprocessingml.document
# MS Excel		application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
# OpenOffice sheet	application/x-vnd.oasis.opendocument.spreadsheet
# PDF			application/pdf
# CSV                   text/csv
# Drawings JPEG		image/jpeg
# PNG			image/png
# SVG			image/svg+xml
# PDF			application/pdf
# MS PowerPoint		application/vnd.openxmlformats-officedocument.presentationml.presentation
# PDF			application/pdf
# Plaintext		text/plain
