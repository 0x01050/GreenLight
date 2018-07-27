# frozen_string_literal: true

module ApplicationHelper
  include MeetingsHelper

  # Gets all configured omniauth providers.
  def configured_providers
    Rails.configuration.providers.select do |provider|
      Rails.configuration.send("omniauth_#{provider}")
    end
  end

  # Determines which providers can show a login button in the login modal.
  def iconset_providers
    configured_providers & [:google, :twitter]
  end

  # Generates the login URL for a specific provider.
  def omniauth_login_url(provider)
    "#{Rails.configuration.relative_url_root}/auth/#{provider}"
  end

  # Determine if Greenlight is configured to allow user signups.
  def allow_user_signup?
    Rails.configuration.allow_user_signup
  end

  # Determines if the BigBlueButton endpoint is the default.
  def bigbluebutton_endpoint_default?
    Rails.configuration.bigbluebutton_endpoint_default == Rails.configuration.bigbluebutton_endpoint
  end

  # Parses markdown for rendering.
  def markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      autolink: true,
      tables: true,
      underline: true,
      highlight: true)

    markdown.render(text).html_safe
  end
end
