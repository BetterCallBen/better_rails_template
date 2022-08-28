run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "devise"
    gem "autoprefixer-rails"
    gem "font-awesome-sass", "~> 6.1"
    gem 'amazing_print', '~> 1.0.0'
    gem 'rspec-rails', '~> 5.0'
    gem 'factory_bot_rails', '~> 5.0'
    gem "faker"
    gem 'dotenv-rails'

  RUBY
end

gsub_file("Gemfile", '# gem "sassc-rails"', 'gem "sassc-rails"')

# Assets
########################################
run "rm -rf vendor"
run "mv app/assets/stylesheets/application.css app/assets/stylesheets/application.scss"
run "mkdir app/assets/stylesheets/config"
run "mkdir app/assets/stylesheets/components"
run "touch app/assets/stylesheets/config/colors.scss"
run "touch app/assets/stylesheets/components/btns.scss"

## Index scss
file 'app/assets/stylesheets/config/index.scss',
<<-CSS
  @import "colors";
  @import "fonts";
CSS

file 'app/assets/stylesheets/components/index.scss',
<<-CSS
  @import "notices";
  @import "btns";
  @import "containers";
CSS

## Config scss
file 'app/assets/stylesheets/config/fonts.scss',
<<-CSS
  .bold {
    font-weight: bold;
  }
CSS

## Components scss
file 'app/assets/stylesheets/components/notices.scss',
<<-CSS
  .alert {
    position: fixed;
    bottom: 16px;
    right: 16px;
    z-index: 1000;
    padding: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    &.success {
      background-color: #dff0d8;
      color: #3c763d;
    }
    &.error {
      background-color: #f2dede;
      color: #a94442;
    }
    // cross
    .fa-xmark {
      font-size: 1.1rem;
      cursor: pointer;
    }
  }
CSS


file 'app/assets/stylesheets/components/container.scss',
<<~CSS
  .container {
    width: 96vw;
    margin: 10 auto;
  }
CSS

inject_into_file "config/initializers/assets.rb", before: "# Precompile additional assets." do
  <<~RUBY
    Rails.application.config.assets.paths << Rails.root.join("node_modules")
  RUBY
end

# Layout
########################################
old_js_tag = <<~HTML
  "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>"
HTML

new_js_tag = <<~HTML
  "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload', defer: true %>"
HTML

gsub_file('app/views/layouts/application.html.erb', old_js_tag, new_js_tag)

style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)

# Flashes
########################################
file "app/views/shared/_flashes.html.erb",
<<~HTML
  <% if notice %>
    <div class="alert success" data-controller="notice">
      <%= notice.html_safe %>
      <i class="fa-solid fa-xmark" data-action="click->notice#close" ></i>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert error" data-controller="notice">
      <%= alert.html_safe %>
      <i class="fa-solid fa-xmark" data-action="click->notice#close" ></i>
    </div>
  <% end %>
HTML


inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do <<~HTML
    <%= render "shared/flashes" %>
  HTML
end

# Generators && i18n
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :rspec, fixture: false
  end

  config.i18n.available_locales = %i[fr en]
  config.i18n.default_locale = :en
  config.fallbacks = true
RUBY

environment generators

# README
########################################
read_me_content = <<~MARKDOWN
Rails app generated with BetterCallBen template.
MARKDOWN
file "README.md", read_me_content, force: true

## Copy controller
file "app/javascript/controllers/copy_controller.js",
<<~JS
  import { Controller } from "stimulus"

  export default class extends Controller {
    static targets = []
    static values = {}

    connect() {
      console.log("BetterCallBen from CopyController!")
    }
  }
JS

## Copy controller
file "app/javascript/controllers/notice_controller.js",
<<~JS
  import { Controller } from "stimulus"

  export default class extends Controller {
    static targets = []
    static values = {}

    close(event) {
      event.currentTarget.remove()
    }
  }
JS

## Toto (test file)
########################################
file "toto.rb", <<~RUBY
  puts "Toto!"
RUBY


########################################
# After bundle
########################################
after_bundle do
  # Generators: db + pages controller
  ########################################

  rails_command "db:drop db:create db:migrate"

  # Application controller
  ########################################
  run "rm app/controllers/application_controller.rb"
  file "app/controllers/application_controller.rb",
  <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb",
  <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Gitignore
  ########################################
  append_file ".gitignore",
  <<~TXT
    .env*
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate("devise:install")
  generate("devise", "User")
  rails_command "db:migrate"
  generate("devise:views")

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Stimulus
  ########################################
  run "rails webpacker:install:stimulus"
  run "rm app/javascript/controllers/hello_controller.js"

  inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
    <<~JS
      // Preventing Babel from transpiling NodeModules packages
      environment.loaders.delete('nodeModules');
    JS
  end

  append_file ".gitignore",
  <<~JS

    import "controllers"
  JS

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Dotenv
  ########################################
  run "touch '.env'"

  # Rubocop
  ########################################
  run "curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'First commit with BetterCallBen template with devise'"
  run "gh repo create --public --source=."
  git push: "origin master"
end
