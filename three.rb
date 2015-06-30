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
SCOPE = 'https://www.googleapis.com/auth/drive.metadata.readonly'

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

params = { maxResults: 50 }
fs = client.execute(
  api_method: drive_api.files.list,
  parameters: params
)

files = fs.data.items
puts files

fs = files.map do |i|
  {id: i.id, title: i.title, durl: i.download_url, expLink: i.export_links} # docs dont expose durl, use explink instead
end

fs.map do |f|
  if !(f[:durl].nil?)
    f[:contents] = client.execute( uri: f[:durl]  )

  else if !(f[:expLink].nil?)
    f[:contents] = client.execute( uri: f[:expLink]['text/plain']  )
  end
  f[:check] = "oaw"
  f
end

puts fs
#  root.write_to('/'+f[:title], data)
end



#FuseFS.main(ARGV) { | options | root }
