#!/usr/bin/env ruby
require 'pry'
require './api.rb'
require 'rfusefs'
require 'fusefs/metadir'
require 'fusefs/dirlink'
include FuseFS

### TODO: algorithm.
## grab each file only when accessed, then write it to that file for duration of program

### TODO: fix shared files being downloaded like gdocs

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
      ['application/vnd.google-apps.document'                                      , '.doc'] # gdoc
    ].map do |t|
      if !f[:possible_types].nil?
        if f[:possible_types].include?(t[0])
          f[:type] = t[0]
          f[:ext]  = t[1]
        end
      end
    end
    f
  end

  def download_file(f)
    f = pick_format(f)
    if !f[:durl].nil?
      f[:contents] = @client.execute( uri: f[:durl]  )
    elsif !f[:expLink].nil?
      if !f[:type].nil? #and !f[:expLink][f[:type]].nil?
        f[:contents] = @client.execute( uri: f[:expLink][ f[:type]] )  # just pick first available type for now
      end
    else # for docs, give a link get it manually
      f[:contents] = { body: f[:alt_link]}
      f[:gdocp] = true
    end
    f
  end

  def download_files
    puts 'downloading...'
    params1 = {
      q: 'sharedWithMe = true'
    }
    fs1 = @client.execute(
      api_method: @drive_api.files.list,
      parameters: params1,
    )
    params2 = { }
    fs2 = @client.execute(
      api_method: @drive_api.files.list,
      parameters: params2,
    )

    files = fs1.data.items + fs2.data.items
    fs = files.map do |i|
      types = #[i.mime_type]
        i['exportLinks'].nil? ? nil : i['exportLinks'].to_hash.keys
      { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i.file_extension, possible_types: types, type: nil, alt_link: i.alternate_link }
    end
    fs.map do |f|
      f = download_file(f)

      #binding.pry

      fname = '/'
      if !f[:contents].nil?
        fname = f[:title] + (f[:ext].nil? ? "" : f[:ext])
        puts "#{f[:title]}"
        if defined?(f[:contents].body)
          @root.write_to(fname, f[:contents].body)
        else
          @root.write_to(fname, f[:contents][:body])
        end
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
    pid = Kernel.fork do
      FuseFS.start(@root, ARGV[0])
    end
    #FuseFS.main(ARGV) { | options | @root }
    puts 'done..'
    pid
  end

  def initialize
    trap('INT') { puts "exiting";  exit }
    init_api
    init_dir
    download_files
    pid = mount_dir
    Process.wait(pid)
  end
end


w = Rdrive_Writer.new
