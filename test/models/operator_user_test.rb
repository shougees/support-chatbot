require "test_helper"

class OperatorUserTest < ActiveSupport::TestCase
  def valid_attrs
    { email: "operator@example.com", password: "s3cur3pass!", password_confirmation: "s3cur3pass!" }
  end

  test "valid with email and password" do
    user = OperatorUser.new(valid_attrs)
    assert user.valid?
  end

  test "invalid without email" do
    user = OperatorUser.new(valid_attrs.merge(email: ""))
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with malformed email" do
    user = OperatorUser.new(valid_attrs.merge(email: "not-an-email"))
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "invalid with duplicate email (case-insensitive)" do
    OperatorUser.create!(valid_attrs)
    duplicate = OperatorUser.new(valid_attrs.merge(email: valid_attrs[:email].upcase))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "invalid without password" do
    user = OperatorUser.new(email: "operator@example.com")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "password is stored as digest, not plain text" do
    user = OperatorUser.create!(valid_attrs)
    assert_not_equal "s3cur3pass!", user.password_digest
    assert user.authenticate("s3cur3pass!")
    assert_not user.authenticate("wrongpassword")
  end

  test "email is downcased before save" do
    user = OperatorUser.create!(valid_attrs.merge(email: "OPERATOR@EXAMPLE.COM"))
    assert_equal "operator@example.com", user.email
  end

  test "fixture alice is loadable" do
    alice = operator_users(:alice)
    assert_equal "alice@example.com", alice.email
    assert alice.authenticate("password")
  end
end
