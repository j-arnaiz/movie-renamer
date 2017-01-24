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
  movie_info = stringify_keys(movie_info)
  release_year = Date.parse(movie_info['release_date']).year
  rename_name = "#{movie_info['title']} (#{release_year})#{rename_3d}#{ext}"
  rename_name.tr!(':', '')

  create_target_folder

  FileUtils.mv(file, @config['target_folder'] + File::SEPARATOR + rename_name)
  if @config['remove_folder']
    dirname = File.dirname(file)
    puts dirname, @config['load_folder']
    FileUtils.rm_rf(File.dirname(file)) if dirname != @config['load_folder']
  end
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

  detect_mode3d(movie_name)
  new_name = movie_name.gsub(/\[.*\]/, '').gsub(/(.*)/, '')

  new_name = new_name.split.delete_if do |x|
    dwords.include?(x.downcase)
  end.join(' ')
  new_name
end

def search_for_movie(names)
  results = []
  names.each do |name|
    results += Tmdb::Movie.find(name) unless name.empty?
  end

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
  hash = {
    index: -1,
    file: file,
    results: []
  }

  results.each do |result|
    hash[:results].push(title: result['title'], release_date: result['release_date'])
  end

  @file_results.push hash
end

def write_results
  File.open(result_file, 'w') do |file|
    file.write @file_results.to_yaml
  end unless @file_results.empty?
end

def read_results
  return @read_results if @read_results

  @read_results = []

  return @read_results unless File.file?(result_file)

  @read_results = YAML.load(File.open(result_file))
end

def result_file
  @config['load_folder'] + File::SEPARATOR + 'results.yml'
end

def stringify_keys(hash)
  new_hash = {}
  hash.each do |k, v|
    new_hash[k.to_s] = v
  end

  new_hash
end

def match_readed_results(file)
  result = read_results.select { |x| x[:file] == file }[0]

  return nil unless result

  result = stringify_keys(result)
  has_index = result.key?('index') && result['index'] != -1

  return result['results'][result['index']] if has_index

  nil
end

def search_names(file, ext)
  names = []
  names.push(parse_string(File.basename(file, ext)))
  dirname = File.dirname(file).gsub(
    @config['load_folder'], ''
  ).gsub(%r{^\/}, '')
  dirname.split(File::SEPARATOR).each do |path|
    names.push(parse_string(path))
  end

  names
end

def object_to_hash(object)
  hash = {}
  object.instance_variables.each do |var|
    hash[var.to_s.delete('@')] = object.instance_variable_get(var)
  end

  hash
end

def array_object_to_hash(array)
  hashes = []
  array.each do |x|
    hashes.push(object_to_hash(x))
  end

  hashes.uniq { |x| x['title'] && x['release_date'] }
end

@config = YAML.load(File.open('./config.yml'))
@file_results = []

Tmdb::Api.key(@config['themoviedb_key'])
Tmdb::Api.language(@config['themoviedb_lang'])

Dir[@config['load_folder'] + '/**/*'].each do |file|
  ext = File.extname(file)
  next unless @config['extensions'].include?(ext)

  names = search_names(file, ext)

  matched = match_readed_results(file)
  if matched
    rename_file(matched, file, ext)
  else
    results = array_object_to_hash(search_for_movie(names))
    if results.count == 1
      rename_file(results[0], file, ext)
    else
      add_results(results, file)
    end
  end
end

write_results
