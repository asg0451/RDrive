#!/usr/bin/env ruby
require 'pry'
require 'net/http'
require 'uri'
###### fuse imports and setup
require 'rfusefs'
require 'fusefs/metadir'
require 'fusefs/dirlink'
include FuseFS

root = MetaDir.new
root.stats.max_space = 1024*1024*1024
root.stats.max_nodes = 1024
root.stats.strict = true

###### drive api boilerplate
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'


APPLICATION_NAME = 'RDrive'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             'rdrive.json')
SCOPE = 'https://www.googleapis.com/auth/drive' # full permissions atm

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization request via InstalledAppFlow.
# If authorization is required, the user's default browser will be launched
# to approve the request.
#
# @return [Signet::OAuth2::Client] OAuth2 credentials
def authorize
  FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

  file_store = Google::APIClient::FileStore.new(CREDENTIALS_PATH)
  storage = Google::APIClient::Storage.new(file_store)
  auth = storage.authorize

  if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
    app_info = Google::APIClient::ClientSecrets.load(CLIENT_SECRETS_PATH)
    flow = Google::APIClient::InstalledAppFlow.new({
      :client_id => app_info.client_id,
      :client_secret => app_info.client_secret,
      :scope => SCOPE})
    auth = flow.authorize(storage)
    puts "Credentials saved to #{CREDENTIALS_PATH}" unless auth.nil?
  end
  auth
end

# Initialize the API
client = Google::APIClient.new(:application_name => APPLICATION_NAME)
client.authorization = authorize
drive_api = client.discovered_api('drive', 'v2')
#########################################################################

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
