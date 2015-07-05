#!/usr/bin/env ruby
require 'pry'
require './api.rb'
require 'rfusefs'
require 'fusefs/metadir'
require 'fusefs/dirlink'
include FuseFS

### TODO: algorithm.
## grab each file only when accessed, then write it to that file for duration of program

class Rdrive_Writer

  def pick_format(f) # returns type
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

  def download_file(f)
    f = pick_format(f)
    if !(f[:durl].nil?)
      f[:contents] = @client.execute( uri: f[:durl]  )
    elsif !(f[:expLink].nil? or f[:types].nil?)
      if !f[:type].nil?
        f[:contents] = @client.execute( uri: f[:expLink][ f[:type]] )  # just pick first available type for now
      end
    end
    f
  end

  def download_files
    puts 'downloading...'
    params = { maxResults: 500 }
    fs = @client.execute(
      api_method: @drive_api.files.list,
      parameters: params
    )
    files = fs.data.items
    fs = files.map do |i|
      types = i['exportLinks'].nil? ? nil : i['exportLinks'].to_hash.keys
      { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i.file_extension, types: types, type: nil }
    end
    fs.map do |f|
      f = download_file(f)
      fname = '/'
      if !(f[:contents].nil? or f[:contents].body.nil? or f[:contents].body.empty?) # can't access for some reason
        fname = f[:title] + f[:ext]
        puts "#{f[:title]}"
        @root.write_to(fname, f[:contents].body)
        f
      end
    end
  end

  def init_dir
    @root = MetaDir.new
    @root.stats.max_space = 1000000000 # 1G in bytes
    @root.stats.max_nodes = 1024
    @root.stats.strict = true
  end

  def init_api
    api = Dapi.new
    @client = api.client
    @drive_api = api.drive_api
  end

  def mount_dir
    puts 'mounting...'
    FuseFS.main(ARGV) { | options | @root }
  end

  def initialize
    init_api
    init_dir
    download_files
    mount_dir
  end
end


w = Rdrive_Writer.new
