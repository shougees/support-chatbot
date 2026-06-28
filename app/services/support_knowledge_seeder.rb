class SupportKnowledgeSeeder
  DOCUMENTS = [
    {
      title: "Return Eligibility Policy",
      source_identifier: "seed/policy/returns",
      category: "returns",
      body: <<~TEXT.squish,
        Customers can ask to return most unopened or unused items within 30 days of delivery.
        Return eligibility depends on item type, delivery date, item condition, and order context.
        Ask for the order number or enough order details when eligibility cannot be verified.
        Do not state that a return has been created unless an application action completes it.
      TEXT
      tags: %w[return returns package item eligibility order]
    },
    {
      title: "Refund Review Policy",
      source_identifier: "seed/policy/refunds",
      category: "refunds",
      body: <<~TEXT.squish,
        Refunds may be considered when an order is confirmed missing, damaged, duplicate charged,
        or returned under policy. Refund decisions require order status, payment context, and policy
        eligibility. If payment details are unclear or the issue is payment-critical, request review
        instead of promising a refund.
      TEXT
      tags: %w[refund refunds payment missing damaged charged]
    },
    {
      title: "Damaged Item Evidence Policy",
      source_identifier: "seed/policy/damaged-items",
      category: "damaged_items",
      body: <<~TEXT.squish,
        For damaged, broken, leaking, or unusable items, ask the customer for a clear image when
        item condition needs confirmation. Useful evidence includes the item, packaging, label,
        and any visible damage. Do not ask for an image when the issue can be resolved from order
        or policy context alone.
      TEXT
      tags: %w[damaged broken leaking image photo packaging replacement]
    },
    {
      title: "Missing Or Late Delivery Guidance",
      source_identifier: "seed/policy/missing-late-delivery",
      category: "delivery",
      body: <<~TEXT.squish,
        For missing, late, or delayed delivery questions, first explain that we need the order or
        tracking context to check the latest status. If tracking shows delivered but the customer
        cannot find the package, suggest checking nearby delivery locations and then request review
        when order context is unavailable.
      TEXT
      tags: %w[missing late delayed delivery tracking package order]
    },
    {
      title: "Cancellation And Address Change Policy",
      source_identifier: "seed/policy/cancellations-address",
      category: "order_changes",
      body: <<~TEXT.squish,
        Cancellations and address changes depend on fulfillment status. If an order has not shipped,
        the system may be able to propose a cancellation or change for review. If an order has shipped,
        explain that options may be limited and avoid promising a cancellation or reroute.
      TEXT
      tags: %w[cancel cancellation address change shipped order]
    },
    {
      title: "Account And Privacy Review Policy",
      source_identifier: "seed/policy/account-privacy",
      category: "account",
      body: <<~TEXT.squish,
        Account access, identity, privacy, fraud, chargeback, and security issues are high-risk.
        Do not ask the customer to share sensitive personal information in chat. Keep the response
        concise, explain that we are checking the issue, and request review when identity or payment
        risk is present.
      TEXT
      tags: %w[account privacy fraud identity chargeback security password]
    }
  ].freeze

  def self.call
    new.call
  end

  def call
    DOCUMENTS.each { |attributes| upsert_document(attributes) }
  end

  private

  def upsert_document(attributes)
    document = KnowledgeDocument.find_or_initialize_by(
      source_type: "manual",
      source_identifier: attributes.fetch(:source_identifier)
    )
    document.assign_attributes(
      title: attributes.fetch(:title),
      category: attributes.fetch(:category),
      body: attributes.fetch(:body),
      extracted_text: nil,
      status: "active",
      metadata: { tags: attributes.fetch(:tags), seed: true }.to_json
    )
    document.save!
  end
end
