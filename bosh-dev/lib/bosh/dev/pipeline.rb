require 'fog'
require 'logger'

require 'bosh/dev/build'
require 'bosh/stemcell/infrastructure'
require 'bosh/dev/pipeline_storage'
require 'bosh/stemcell/archive_filename'

module Bosh::Dev
  class Pipeline
    attr_reader :storage

    def initialize(options = {})
      @storage = options.fetch(:storage) { default_storage }
      @build_id = options.fetch(:build_id) { Build.candidate.number.to_s }
      @logger = options.fetch(:logger) { Logger.new($stdout) }
      @bucket = 'bosh-ci-pipeline'
    end

    def upload_r(source_dir, dest_dir)
      Dir.chdir(source_dir) do
        Dir['**/*'].each do |file|
          unless File.directory?(file)
            create(
              key: File.join(dest_dir, file),
              body: File.open(file),
              public: true
            )
          end
        end
      end
    end

    def publish_stemcell(stemcell)
      latest_filename = stemcell_filename('latest', Bosh::Stemcell::Infrastructure.for(stemcell.infrastructure), stemcell.name, stemcell.light?)
      s3_latest_path = File.join(stemcell.name, stemcell.infrastructure, latest_filename)

      s3_path = File.join(stemcell.name, stemcell.infrastructure, File.basename(stemcell.path))

      create(key: s3_path, body: File.open(stemcell.path), public: false)
      create(key: s3_latest_path, body: File.open(stemcell.path), public: false)
    end

    def gems_dir_url
      "https://s3.amazonaws.com/#{bucket}/#{build_id}/gems/"
    end

    def cleanup_stemcells(download_dir)
      FileUtils.rm_f(Dir.glob(File.join(download_dir, '*bosh-stemcell-*.tgz')))
    end

    private

    attr_reader :logger, :bucket, :build_id

    def create(options)
      uploaded_file = storage.upload(
        bucket,
        File.join(build_id, options.fetch(:key)),
        options.fetch(:body),
        options.fetch(:public)
      )
      logger.info("uploaded to #{uploaded_file.public_url || "s3://#{bucket}/#{build_id}/#{options.fetch(:key)}"}")
    end

    def stemcell_filename(version, infrastructure, name, light)
      Bosh::Stemcell::ArchiveFilename.new(version, infrastructure, name, light).to_s
    end

    def default_storage
      Bosh::Dev::PipelineStorage.new
    end
  end
end
