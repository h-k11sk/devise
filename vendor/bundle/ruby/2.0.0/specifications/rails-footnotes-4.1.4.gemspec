# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "rails-footnotes"
  s.version = "4.1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Roman V. Babenko", "Jos\u{e9} Valim", "Keenan Brock", "Duane Johnson", "Adrien Siami"]
  s.date = "2014-11-07"
  s.description = "Every Rails page has footnotes that gives information about your application and links back to your editor."
  s.email = ["romanvbabenko@gmail.com"]
  s.homepage = "http://github.com/josevalim/rails-footnotes"
  s.require_paths = ["lib"]
  s.rubyforge_project = "rails-footnotes"
  s.rubygems_version = "2.0.0"
  s.summary = "Every Rails page has footnotes that gives information about your application and links back to your editor."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, [">= 3.2"])
      s.add_development_dependency(%q<rspec-rails>, ["~> 2.14.0"])
      s.add_development_dependency(%q<capybara>, [">= 0"])
    else
      s.add_dependency(%q<rails>, [">= 3.2"])
      s.add_dependency(%q<rspec-rails>, ["~> 2.14.0"])
      s.add_dependency(%q<capybara>, [">= 0"])
    end
  else
    s.add_dependency(%q<rails>, [">= 3.2"])
    s.add_dependency(%q<rspec-rails>, ["~> 2.14.0"])
    s.add_dependency(%q<capybara>, [">= 0"])
  end
end
