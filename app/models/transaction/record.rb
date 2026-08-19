class Transaction::Record < ApplicationRecord
  self.table_name = "transactions"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  belongs_to :category, class_name: "Category::Record", optional: true

  has_many :taggings, class_name: "Transaction::Tagging::Record", foreign_key: :transaction_id, dependent: :destroy, inverse_of: :financial_transaction
  has_many :recurrences, class_name: "Transaction::Recurrence::Record", foreign_key: :transaction_id, dependent: :destroy, inverse_of: :financial_transaction
  has_one :for_account, class_name: "Transaction::ForAccount::Record", foreign_key: :transaction_id, dependent: :destroy, inverse_of: :financial_transaction
  has_one :for_credit_card, class_name: "Transaction::ForCreditCard::Record", foreign_key: :transaction_id, dependent: :destroy, inverse_of: :financial_transaction
  has_one :for_transfer_between_accounts,
          class_name: "Transaction::ForTransferBetweenAccounts::Record",
          foreign_key: :transaction_id,
          dependent: :destroy,
          inverse_of: :financial_transaction

  enum :kind, {
    income: "income",
    expense: "expense",
    transfer_between_accounts: "transfer_between_accounts"
  }, validate: true

  enum :status, {
    pending: "pending",
    active: "active",
    completed: "completed",
    canceled: "canceled"
  }, validate: true, default: :pending

  enum :payment_method, {
    pix: "pix",
    debit: "debit",
    credit_card: "credit_card",
    ted: "ted",
    doc: "doc",
    deposit: "deposit",
    cash: "cash",
    boleto: "boleto"
  }, validate: { allow_nil: true }

  enum :recurrence_type, {
    one_time: "one_time",
    installment: "installment",
    recurring: "recurring"
  }, validate: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[id description kind status payment_method recurrence_type category_id installments_count ends_on created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
