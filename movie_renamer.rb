require 'yaml'
require 'themoviedb'
require 'fileutils'
require 'digest'

def create_target_folder
  tfolder = @config['target_folder']

  FileUtils.mkdir_p(tfolder) unless File.directory?(tfolder)
end

def rename_3d
  return '' unless @mode3d

  trans_3d_mode = {
    'tab' => ' 3d TAB',
    'hou' => ' 3d TAB',
    'sbs' => ' 3d SBS'
  }

  trans_3d_mode[@mode3d]
end

def rename_file(movie_info, file, ext)
  release_year = Date.parse(movie_info.release_date).year
  rename_name = "#{movie_info.title} (#{release_year})#{rename_3d}#{ext}"

  create_target_folder

  FileUtils.mv(file, @config['target_folder'] + File::SEPARATOR + rename_name)
end

def detect_mode3d(name)
  mode3d = %w(tab hou sbs)

  @mode3d = nil
  name.split.each do |x|
    @mode3d = x.downcase if mode3d.include?(x.downcase)
  end
end

def parse_string(movie_name)
  dwords = %w(3d tab hou sbs)

  new_name = movie_name.gsub(/\[.*\]/, '')

  detect_mode3d(new_name)

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

def add_results(results, file)
  md5 = Digest::MD5.hexdigest File.read file

  hash = {
    md5: md5,
    index: -1,
    results: []
  }

  results.each do |result|
    hash[:results].push(title: result.title, release_date: result.release_date)
  end

  @file_results.push hash
end

def write_results
  File.open('results.yml', 'w') do |file|
    file.write @file_results.to_yaml
  end unless @file_results.empty?
end

@config = YAML.load(File.open('./config.yml'))
@file_results = []

Tmdb::Api.key(@config['themoviedb_key'])
Tmdb::Api.language(@config['themoviedb_lang'])

Dir[@config['load_folder'] + '/**/*'].each do |file|
  file = file
  ext = File.extname(file)
  dirname = File.dirname(file).gsub(@config['load_folder'] + '/', '')
  next unless @config['extensions'].include?(ext)

  filename = File.basename(file, ext)
  results = search_for_movie(filename)
  results += analyse_folder(dirname)

  if results.count == 1
    rename_file(results[0], file, ext)
  else
    add_results(results, file)
  end
end

write_results
