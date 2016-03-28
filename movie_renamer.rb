require 'yaml'
require 'themoviedb'
require 'fileutils'

def create_target_folder
  tfolder = @config['target_folder']

  FileUtils.mkdir_p(tfolder) unless File.directory?(tfolder)
end

def rename_file(movie_info, file, ext)
  release_year = Date.parse(movie_info.release_date).year
  rename_name = "#{movie_info.title} (#{release_year})#{ext}"

  create_target_folder

  FileUtils.mv(file, @config['target_folder'] + File::SEPARATOR + rename_name)
end

def parse_string(movie_name)
  dwords = %w(3d tab hou sbs)
  new_name = movie_name.gsub(/\[.*\]/, '')
  new_name = new_name.split.delete_if do |x|
    dwords.include?(x.downcase)
  end.join(' ')
  new_name
end

def search_for_movie(filename)
  query = parse_string(filename)

  results = Tmdb::Movie.find(query)

  results
end

def analyse_folder(dirname)
  dirs = dirname.split(File::SEPARATOR)
  results = []
  dirs.each do |dir|
    results += search_for_movie(dir)
  end

  results
end

@config = YAML.load(File.open('./config.yml'))

Tmdb::Api.key(@config['themoviedb_key'])
Tmdb::Api.language(@config['themoviedb_lang'])

Dir[@config['load_folder'] + '/**/*'].each do |file|
  file = file
  ext = File.extname(file)
  dirname = File.dirname(file).gsub(@config['load_folder'] + '/', '')
  next unless @config['extensions'].include?(ext)

  filename = File.basename(file, ext)
  results = search_for_movie(filename)
  results += analyse_folder(dirname) if results.empty?

  rename_file(results[0], file, ext) if results.count == 1
end
