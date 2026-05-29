require "test_helper"

class BulletTest < ActiveSupport::TestCase
  test "is enabled for rails tests" do
    assert defined?(Bullet)
    assert_predicate Bullet, :enable?
    refute_predicate Bullet, :unused_eager_loading_enable?
    assert_equal Bullet::Notification::UnoptimizedQueryError, UniformNotifier::Raise.active?
  end
end
