require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "valid with external_id" do
    customer = Customer.new(external_id: "cust_100")
    assert customer.valid?
  end

  test "invalid without external_id" do
    customer = Customer.new(external_id: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:external_id], "can't be blank"
  end

  test "external_id must be unique" do
    existing = customers(:one)
    duplicate = Customer.new(external_id: existing.external_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "valid with name and email" do
    customer = Customer.new(external_id: "cust_200", name: "Jane Doe", email: "jane@example.com")
    assert customer.valid?
  end

  test "invalid with malformed email" do
    customer = Customer.new(external_id: "cust_300", email: "not-an-email")
    assert_not customer.valid?
    assert_includes customer.errors[:email], "is invalid"
  end

  test "valid with blank email" do
    customer = Customer.new(external_id: "cust_400", email: "")
    assert customer.valid?
  end
end
