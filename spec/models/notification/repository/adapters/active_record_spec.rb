require "rails_helper"

RSpec.describe Notification::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:transaction_id) { UUID.generate }

  def exists_unread?(**overrides)
    repository.exists_unread?(
      user_id: user.id,
      kind: "transaction.validation.errors",
      notifiable_type: "Transaction::Record",
      notifiable_id: transaction_id,
      data: { "month" => 8, "year" => 2026 },
      **overrides
    )
  end

  describe "#exists_unread?" do
    it "matches a legacy unread notification without dedup_key via jsonb containment" do
      create(
        :notification,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 8, "year" => 2026, "occurred_on" => "2026-08-11" }
      )

      expect(exists_unread?).to be(true)
    end

    it "does not treat a different dedup_key as a duplicate just because data contains the query subset" do
      create(
        :notification,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 8, "year" => 2026, "type" => "unexpected", "error" => "boom" },
        dedup_key: { "month" => 8, "year" => 2026, "type" => "unexpected" }
      )

      expect(exists_unread?(data: { "month" => 8, "year" => 2026 })).to be(false)
    end

    it "returns false when the matching notification has been read" do
      create(
        :notification,
        :read,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 8, "year" => 2026 }
      )

      expect(exists_unread?).to be(false)
    end

    it "returns false when the jsonb data does not contain the given keys" do
      create(
        :notification,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 7, "year" => 2026 }
      )

      expect(exists_unread?).to be(false)
    end

    it "returns false for another notifiable" do
      create(
        :notification,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: UUID.generate,
        data: { "month" => 8, "year" => 2026 }
      )

      expect(exists_unread?).to be(false)
    end

    it "returns false for another user" do
      other_user = create(:user, :verified)
      create(
        :notification,
        user: other_user,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 8, "year" => 2026 }
      )

      expect(exists_unread?).to be(false)
    end

    it "matches symbol keys in the query payload via stringify_keys" do
      create(
        :notification,
        user:,
        kind: "settlement.errors",
        data: { "month" => 8, "year" => 2026 }
      )

      expect(
        repository.exists_unread?(
          user_id: user.id,
          kind: "settlement.errors",
          data: { month: 8, year: 2026 }
        )
      ).to be(true)
    end

    it "matches a stored dedup_key even when extra keys exist in data" do
      create(
        :notification,
        user:,
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data: { "month" => 8, "year" => 2026, "error" => "timeout" },
        dedup_key: { "month" => 8, "year" => 2026 }
      )

      expect(exists_unread?(data: { "month" => 8, "year" => 2026 })).to be(true)
    end

    it "does not filter by data when data is empty" do
      create(:notification, user:, kind: "monthly_status.errors", data: { "type" => "unexpected" })

      expect(
        repository.exists_unread?(user_id: user.id, kind: "monthly_status.errors", data: {})
      ).to be(true)
    end
  end

  describe "#create" do
    def create_notification(**overrides)
      repository.create(
        attributes: {
          user_id: user.id,
          kind: "settlement.errors",
          title: "Error",
          data: { "month" => 8, "year" => 2026, "type" => "unexpected", "error" => "boom" },
          dedup_key: { "month" => 8, "year" => 2026, "type" => "unexpected" },
          broadcast: false,
          **overrides
        }
      )
    end

    it "returns Success(:notification_skipped) when the unread dedup index already has the key" do
      first = create_notification
      second = nil

      expect { second = create_notification(title: "Race", data: { "month" => 8, "year" => 2026, "type" => "unexpected" }) }
        .not_to change(Notification::Record, :count)

      expect(first).to be_a(Solid::Success)
      expect(first.type).to eq(:notification_created)
      expect(second).to be_a(Solid::Success)
      expect(second.type).to eq(:notification_skipped)
    end

    it "treats null notifiable as the same unread key" do
      create_notification
      second = create_notification(title: "Same identity")

      expect(second.type).to eq(:notification_skipped)
      expect(Notification::Record.count).to eq(1)
    end

    it "allows a second unread notification when the dedup_key differs" do
      create_notification
      second = create_notification(dedup_key: { "month" => 9, "year" => 2026, "type" => "unexpected" })

      expect(second.type).to eq(:notification_created)
      expect(Notification::Record.count).to eq(2)
    end

    it "allows the same key again after the previous notification is read" do
      first = create_notification
      Notification::Record.find(first.value[:notification].id).update!(read: true, read_at: Time.current)

      second = create_notification(title: "After read")

      expect(second.type).to eq(:notification_created)
      expect(Notification::Record.count).to eq(2)
    end
  end
end
