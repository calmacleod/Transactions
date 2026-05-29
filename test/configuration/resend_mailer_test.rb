require "test_helper"

class ResendMailerTest < ActiveSupport::TestCase
  test "resend initializer uses the API key environment variable" do
    initializer = Rails.root.join("config/initializers/mailer.rb").read

    assert_includes initializer, 'ENV["RESEND_API_KEY"]'
    assert_includes initializer, "Resend.api_key"
  end

  test "resend-enabled environments use the SDK delivery method" do
    %w[development production].each do |environment|
      config = Rails.root.join("config/environments/#{environment}.rb").read

      assert_includes config, 'ENV["RESEND_API_KEY"].present?'
      assert_includes config, "config.action_mailer.delivery_method = :resend"
      refute_includes config, "smtp.resend.com"
    end
  end

  test "deployment exposes resend settings to production" do
    deploy_config = Rails.root.join("config/deploy.yml").read
    secrets_config = Rails.root.join(".kamal/secrets").read

    assert_includes deploy_config, "- RESEND_API_KEY"
    assert_includes deploy_config, "- MAILER_FROM"
    assert_includes secrets_config, "RESEND_API_KEY=$(kamal secrets extract RESEND_API_KEY"
    assert_includes secrets_config, "MAILER_FROM=$(kamal secrets extract MAILER_FROM"
  end
end
