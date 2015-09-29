require 'json'
class PluginRoutes
  # draw "all" gems registered for the plugins or themes and camaleon gems
  def self.draw_gems
    res = []
    dirs = [] + Dir["#{apps_dir}/plugins/*"] + Dir["#{apps_dir}/themes/*"]

    dirs.each do |path|
      next if [".", ".."].include?(path)
      g = File.join(path, "config", "Gemfile")
      res << File.read(g) if File.exist?(g)
    end
    res.join("\n")
  end

  # return apps directory path
  def self.apps_dir
    dir =  "#{File.dirname(__FILE__)}".split("/")
    dir.pop
    dir.join("/")+ '/app/apps'
  end

  # check if a gem is available or not
  # Arguemnts:
  # name: name of the gem
  # return (Boolean) true/false
  def self.get_gem(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue
    Gem.available?(name)
  end
end
