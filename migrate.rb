require 'pg'
require 'yaml'
require 'blobber_client'

module Migrate

  def self.time(msg, &block)
    start = Time.now
    yield
    STDERR.puts msg << ' (elapsed time: ' << ((Time.now - start) * 1000).to_s << ')'
  end

  def self.migrate(conn, blob_client, limit)


    x = conn.exec( 'BEGIN TRANSACTION;')

    time('create temp table') do
      x = conn.exec( 'CREATE TEMP TABLE loan_contracts_ids AS
                      SELECT id
                      FROM loan_contracts
                      WHERE contract_text_guuid IS NULL')
    end # time

    time("select") do
      x = conn.exec( "SELECT        LC.id, 
                                    LC.contract_text
                      FROM          loan_contracts LC
                      JOIN          loan_contracts_ids TMP ON LC.id = TMP.id
                      WHERE TMP.id IN (SELECT id FROM loan_contracts_ids ORDER BY id ASC LIMIT #{limit})
                      FOR UPDATE OF LC")
    end # time
    
    x.each do |row|
      id   = row['id']
      blob = row['contract_text']
      key = nil

      time("post row id #{id}") do
        key  = blob_client.post(blob)
      end # time

      q = "UPDATE loan_contracts
           SET    contract_text_guuid = '#{key}', 
                  contract_text = NULL
           WHERE  id = #{id}"
      time("update") do
        conn.exec(q)
      end # time

      time('fetch/compare') do
        fetched = blob_client.get(key)
        File.open("/tmp/blob-db",      "wb") { |f| f.write(blob)}
        File.open("/tmp/blob-blobber", "wb") { |f| f.write(fetched)}
        raise 'mismatch' unless system("cmp /tmp/blob-db /tmp/blob-blobber") 
      end # time
    end # x.each

  conn.exec( "COMMIT")
  end # migrate

  def self.main(cfg)
    cfg['iterations'].times do
      time("everything") do    
        Migrate::migrate(PG.connect({:host     => cfg['host'],
                                     :port     => cfg['port'],
                                     :dbname   => cfg['dbname'],
                                     :user     => cfg['user'],
                                     :password => cfg['password']
                                    }), 
                         BlobberClient.new( cfg['url']),
                         cfg['limit'])
      end # time everything

      sleep(cfg['pause'])

    end # iterations
  end # main

end # module Migrate

if ARGV[0]
  config = YAML.load_file(ARGV[0])
  ['host',
   'port',
   'dbname',
   'user',
   'password',
   'iterations',
   'limit',
   'pause',
    'url' ].each { |param| raise "Configuration file '#{ARGV[0]}' is missing parameter '#{param}'" unless config[param] }
  Migrate::main(config)
else
  abort("usage: ruby migrate.rb config.yml")
end
