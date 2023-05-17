# frozen_string_literal: true

module FlipperExtensions
  module ActionPatch
    DSVA_SRCS = ['https://design.va.gov'].freeze

    # https://github.com/jnunemaker/flipper/blob/09d216f234c6e0349bc88f247135125d1d76de71/lib/flipper/ui/action.rb#L48-L58
    SCRIPT_SRCS = Flipper::UI::Action::SCRIPT_SRCS
    STYLE_SRCS = Flipper::UI::Action::STYLE_SRCS + DSVA_SRCS
    CONTENT_SECURITY_POLICY = <<-CSP.delete("\n")
      default-src 'none';
      img-src 'self';
      font-src 'self' #{DSVA_SRCS.join(' ')};
      script-src 'report-sample' 'self' #{SCRIPT_SRCS.join(' ')};
      style-src 'self' 'unsafe-inline' #{STYLE_SRCS.join(' ')};
      style-src-attr 'unsafe-inline' ;
      style-src-elem 'self' #{STYLE_SRCS.join(' ')};
    CSP

    def view(name)
      # Use custom views if enabled in configuration.
      path = custom_views_path.join("#{name}.erb") unless custom_views_path.nil?

      # Fall back to default views if custom views haven't been enabled
      # or if the custom view cannot be found.
      path = views_path.join("#{name}.erb") if path.nil? || !path.exist?

      raise "Template does not exist: #{path}" unless path.exist?

      # rubocop:disable Security/Eval
      eval(Erubi::Engine.new(path.read, escape: true).src)
      # rubocop:enable Security/Eval
    end

    # Flipper UI's CSP needs overriding
    # https://github.com/jnunemaker/flipper/blob/09d216f234c6e0349bc88f247135125d1d76de71/lib/flipper/ui/action.rb#L162-L166
    def view_response(name)
      header 'Content-Type', 'text/html'
      header 'Content-Security-Policy', CONTENT_SECURITY_POLICY
      body = view_with_layout { view_without_layout name }
      halt [@code, @headers, [body]]
    end

    def custom_views_path
      Flipper::UI.configuration.custom_views_path
    end

    # This is where we store the feature descriptions.
    # You can choose to store this where it makes sense for you.
    def yaml_features
      @yaml_features ||= FLIPPER_FEATURE_CONFIG['features']
    end
  end
end
