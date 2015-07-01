#!/usr/bin/env ruby
require 'pry'
require "net/http"
require "uri"
###### fuse imports and setup
require 'rfusefs'
require 'fusefs/metadir'
require 'fusefs/dirlink'
include FuseFS

root = MetaDir.new
root.stats.max_space = 1024*1024
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
                             "rdrive.json")
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

params = { maxResults: 20 }
fs = client.execute(
  api_method: drive_api.files.list,
  parameters: params
)

files = fs.data.items
puts files

fs = files.map do |i|
  if i['exportLinks'].nil?
    { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i.file_extension, type: nil }
  else
    { id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links, ext: i['fileExtension'], type: i['exportLinks'].to_hash.keys }
  end
  # docs dont expose durl, use explink instead
end

fs.map do |f|
  if !(f[:durl].nil?)
    f[:contents] = client.execute( uri: f[:durl]  )
  else
    if !(f[:expLink].nil?)
      f[:contents] = client.execute( uri: f[:expLink][ f[:type][0] ] )  # just pick first available type for now
    end
  end
  f[:check] = "oaw"
#  puts fs

  puts f
  if !(f[:contents].nil? or f[:contents].body.nil?)
    if !(f[:type].nil?)
      if f[:type][0] = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' # check for gdocs, temp solution
#        binding.pry
        if f[:ext].nil?
          root.write_to('/'+f[:title] + '.xls', f[:contents].body) # gdoc
        else
          root.write_to('/'+f[:title], f[:contents].body) # some other kind of doc?
        end
      elsif
        root.write_to('/'+f[:title], f[:contents].body) # some other type
      end
    else
      root.write_to('/'+ f[:title] + '.' + f[:ext], f[:contents].body)
    end
  end
  f
end




#binding.pry



FuseFS.main(ARGV) { | options | root }
